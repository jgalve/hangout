import {FormEvent, useEffect, useState} from 'react'
import type {User} from '@supabase/supabase-js'
import {supabase} from '../lib/supabase'
import type {GenderCategory,HangoutPersonality,Profile} from '../types'

const datingIntentions:NonNullable<Profile['dating_intention']>[]=[
  'Long-term relationship',
  'Serious, open to seeing where it goes',
  'Casual dating',
  'New friends',
  'Activity partner',
  'Still figuring it out',
]
function isDatingIntention(value:string):value is Profile['dating_intention']{
  return datingIntentions.some(intention=>intention===value)
}
function getBirthDateDetails(value:string){
  const [year,month,day]=value.split('-').map(Number)
  if(!year||!month||!day)return null
  const birth=new Date(year,month-1,day)
  if(birth.getFullYear()!==year||birth.getMonth()!==month-1||birth.getDate()!==day)return null

  const today=new Date()
  let age=today.getFullYear()-year
  if(today.getMonth()<month-1||(today.getMonth()===month-1&&today.getDate()<day))age--
  if(age<0)return null

  const zodiacSigns=[
    'Capricorn','Aquarius','Pisces','Aries','Taurus','Gemini',
    'Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn',
  ]
  const zodiacStartDays=[20,19,21,21,21,21,23,23,23,23,22,22]
  const zodiac=zodiacSigns[month-1+(day>=zodiacStartDays[month-1]?1:0)]
  return {age,zodiac}
}
const hangoutPersonalityOptions:HangoutPersonality[] = [
  'Coffee',
  'Explore',
  'Foodie',
  'Music',
  'Culture',
  'Markets',
  'Parks',
  'Fitness',
  'Games',
  'Nightlife',
  'Nature',
  'Community',
]
const genderOptions:{value:GenderCategory;label:string}[]=[
  {value:'woman',label:'Woman'},
  {value:'man',label:'Man'},
  {value:'non_binary',label:'Non-binary'},
  {value:'self_described',label:'Self-described'},
]
function isGenderCategory(value:string):value is GenderCategory{
  return genderOptions.some(option=>option.value===value)
}
const maxPhotoSize = 8 * 1024 * 1024
const maxIdentityImageSize = 15 * 1024 * 1024
type VerificationStatus={
  request_id:string
  status:'uploading'|'pending'|'verified'|'rejected'|'cleanup_pending'|'withdrawn_cleanup_pending'
  submitted_at:string|null
  decided_at:string|null
  upload_path:string|null
}
type VerificationUploadReservation={request_id:string;upload_path:string}

function errorMessage(error:unknown,fallback:string){
  if(error instanceof Error)return error.message
  if(typeof error==='object'&&error!==null&&'message' in error)return String(error.message)
  return fallback
}

function normalizeSocialProfileUrl(value:string,platform:'Facebook'|'Instagram'|'TikTok',allowedHosts:string[]){
  const input=value.trim()
  if(!input)return null
  let url:URL
  try{
    url=new URL(input)
  }catch{
    throw new Error(`Enter a valid ${platform} profile URL.`)
  }
  if(url.protocol!=='https:'||!allowedHosts.includes(url.hostname.toLowerCase())||url.username||url.password||url.port||url.pathname==='/'){
    throw new Error(`Enter an HTTPS ${platform} profile URL.`)
  }
  return url.toString()
}

function getProfilePhotoStoragePath(url:string,userId:string){
  const photoUrl=new URL(url)
  const bucketMarker='/profile-photos/'
  const bucketPathIndex=photoUrl.pathname.lastIndexOf(bucketMarker)
  if(bucketPathIndex<0)throw new Error('Unable to verify the profile photo storage path.')
  const path=decodeURIComponent(photoUrl.pathname.slice(bucketPathIndex+bucketMarker.length))
  if(!path.startsWith(`${userId}/`))throw new Error('Unable to verify the profile photo storage path.')
  return path
}

async function preparePhoto(file:File){
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)){
    throw new Error('Choose a JPEG, PNG, or WebP image.')
  }
  if(file.size>maxPhotoSize)throw new Error('Choose an image smaller than 8 MB.')

  const bitmap=await createImageBitmap(file)
  try{
    const scale=Math.min(1,1600/Math.max(bitmap.width,bitmap.height))
    const canvas=document.createElement('canvas')
    canvas.width=Math.max(1,Math.round(bitmap.width*scale))
    canvas.height=Math.max(1,Math.round(bitmap.height*scale))
    const context=canvas.getContext('2d')
    if(!context)throw new Error('Unable to prepare this image. Try another file.')
    context.fillStyle='#fff'
    context.fillRect(0,0,canvas.width,canvas.height)
    context.drawImage(bitmap,0,0,canvas.width,canvas.height)
    const blob=await new Promise<Blob>((resolve,reject)=>{
      canvas.toBlob(result=>{
        if(result)resolve(result)
        else reject(new Error('Unable to prepare this image. Try another file.'))
      },'image/jpeg',.86)
    })
    if(blob.size>maxPhotoSize)throw new Error('The prepared image is larger than 8 MB.')
    return blob
  }finally{
    bitmap.close()
  }
}

async function prepareIdentityDocument(file:File){
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)){
    throw new Error('Choose a JPEG, PNG, or WebP photo of your ID.')
  }
  if(file.size>maxIdentityImageSize)throw new Error('Choose an ID image smaller than 15 MB.')

  const bitmap=await createImageBitmap(file)
  try{
    if(bitmap.width*bitmap.height>40_000_000)throw new Error('This image is too large to process safely.')
    const scale=Math.min(1,3000/Math.max(bitmap.width,bitmap.height))
    const canvas=document.createElement('canvas')
    canvas.width=Math.max(1,Math.round(bitmap.width*scale))
    canvas.height=Math.max(1,Math.round(bitmap.height*scale))
    const context=canvas.getContext('2d')
    if(!context)throw new Error('Unable to prepare this ID image. Try another photo.')
    context.fillStyle='#fff'
    context.fillRect(0,0,canvas.width,canvas.height)
    context.drawImage(bitmap,0,0,canvas.width,canvas.height)
    const blob=await new Promise<Blob>((resolve,reject)=>{
      canvas.toBlob(result=>{
        if(result)resolve(result)
        else reject(new Error('Unable to prepare this ID image. Try another photo.'))
      },'image/jpeg',.92)
    })
    if(blob.size>8*1024*1024)throw new Error('The prepared ID image is larger than 8 MB. Try a smaller or clearer photo.')
    return blob
  }finally{
    bitmap.close()
  }
}

export function ProfileEditor({user}:{user:User}){
  const [p,setP]=useState<Profile|null>(null)
  const [firstName,setFirstName]=useState('')
  const [birthDate,setBirthDate]=useState('')
  const [bio,setBio]=useState('')
  const [facebookUrl,setFacebookUrl]=useState('')
  const [instagramUrl,setInstagramUrl]=useState('')
  const [tiktokUrl,setTiktokUrl]=useState('')
  const [datingIntention,setDatingIntention]=useState<Profile['dating_intention']>('Still figuring it out')
  const [hangoutPersonality,setHangoutPersonality]=useState<HangoutPersonality[]>([])
  const [customHangoutPersonality,setCustomHangoutPersonality]=useState('')
  const [genderIdentity,setGenderIdentity]=useState<GenderCategory|null>(null)
  const [genderIdentityDetail,setGenderIdentityDetail]=useState('')
  const [interestedInGenders,setInterestedInGenders]=useState<GenderCategory[]>([])
  const [openToAllGenders,setOpenToAllGenders]=useState(true)
  const [loading,setLoading]=useState(true)
  const [busy,setBusy]=useState(false)
  const [msg,setMsg]=useState('')
  const [verification,setVerification]=useState<VerificationStatus|null>(null)
  const [verificationLoading,setVerificationLoading]=useState(true)
  const [verificationFile,setVerificationFile]=useState<File|null>(null)
  const [verificationConsent,setVerificationConsent]=useState(false)
  const [verificationBusy,setVerificationBusy]=useState(false)
  const [verificationError,setVerificationError]=useState('')
  const [verificationMessage,setVerificationMessage]=useState('')

  async function fetchVerificationStatus(){
    const {data,error}=await supabase!.rpc('my_identity_verification_status')
    if(error)throw error
    return ((data||[])[0] as VerificationStatus|undefined)||null
  }

  async function retryVerificationStatus(){
    setVerificationLoading(true)
    setVerificationError('')
    try{
      setVerification(await fetchVerificationStatus())
    }catch(error){
      setVerificationError(errorMessage(error,'Unable to load ID review status.'))
    }finally{
      setVerificationLoading(false)
    }
  }

  useEffect(()=>{
    let cancelled=false
    async function load(){
      setLoading(true)
      const {data,error}=await supabase!.from('profiles').select('*').eq('id',user.id).single()
      if(cancelled)return
      if(error){
        setMsg(error.message)
      }else{
        setP(data)
        setFirstName(data.first_name||user.user_metadata.first_name||'')
        setBirthDate(data.birth_date||'')
        setBio(data.bio||'')
        setFacebookUrl(data.facebook_url||'')
        setInstagramUrl(data.instagram_url||'')
        setTiktokUrl(data.tiktok_url||'')
        setDatingIntention(data.dating_intention||'Still figuring it out')
        setHangoutPersonality(data.hangout_personality||[])
        setCustomHangoutPersonality(data.custom_hangout_personality||'')
        setGenderIdentity(data.gender_identity||null)
        setGenderIdentityDetail(data.gender_identity_detail||'')
        setInterestedInGenders(data.interested_in_genders||[])
        setOpenToAllGenders(data.open_to_all_genders??true)
      }
      setLoading(false)
    }
    load()
    return()=>{cancelled=true}
  },[user.id,user.user_metadata.first_name])

  useEffect(()=>{
    let cancelled=false
    async function loadVerification(){
      setVerificationLoading(true)
      setVerificationError('')
      try{
        const status=await fetchVerificationStatus()
        if(!cancelled)setVerification(status)
      }catch(error){
        if(!cancelled)setVerificationError(errorMessage(error,'Unable to load ID review status.'))
      }finally{
        if(!cancelled)setVerificationLoading(false)
      }
    }
    void loadVerification()
    return()=>{cancelled=true}
  },[user.id])

  async function save(e:FormEvent<HTMLFormElement>){
    e.preventDefault()
    if(!p?.photo_url){
      setMsg('Upload a profile photo before saving your profile.')
      return
    }
    if(!datingIntentions.includes(datingIntention)){
      setMsg('Choose a primary dating intention before saving your profile.')
      return
    }
    let socialProfileUrls:{facebook_url:string|null;instagram_url:string|null;tiktok_url:string|null}
    try{
      socialProfileUrls={
        facebook_url:normalizeSocialProfileUrl(facebookUrl,'Facebook',['facebook.com','www.facebook.com','m.facebook.com']),
        instagram_url:normalizeSocialProfileUrl(instagramUrl,'Instagram',['instagram.com','www.instagram.com']),
        tiktok_url:normalizeSocialProfileUrl(tiktokUrl,'TikTok',['tiktok.com','www.tiktok.com','m.tiktok.com']),
      }
    }catch(error){
      setMsg(errorMessage(error,'Check the social profile URLs and try again.'))
      return
    }
    if(hangoutPersonality.length<3||hangoutPersonality.length>5){
      setMsg('Choose 3 to 5 hangout personalities before saving your profile.')
      return
    }
    const customPersonalityInput=customHangoutPersonality.trim()
    const customPersonalityItems=customPersonalityInput
      ?customPersonalityInput.split(',').map(personality=>personality.trim())
      :[]
    const customPersonality=customPersonalityItems.join(', ')
    if(customPersonalityInput&&(
      customPersonalityInput.length>94
      ||customPersonalityItems.length>3
      ||customPersonalityItems.some(personality=>!personality||personality.length>30||/\s/.test(personality)||hangoutPersonalityOptions.some(option=>option.toLowerCase()===personality.toLowerCase()))
      ||new Set(customPersonalityItems.map(personality=>personality.toLowerCase())).size!==customPersonalityItems.length
    )){
      setMsg('Enter up to 3 unique one-word personalities, each up to 30 characters, separated by commas and different from the listed choices.')
      return
    }
    if(genderIdentity==='self_described'&&!genderIdentityDetail.trim()){
      setMsg('Add your self-described gender or choose another option.')
      return
    }
    if(!openToAllGenders&&!interestedInGenders.length){
      setMsg('Choose at least one gender or select open to everyone.')
      return
    }
    const birth=birthDate
    if(birth&&new Date(birth)>new Date(new Date().setFullYear(new Date().getFullYear()-18))){
      setMsg('You must be at least 18.')
      return
    }
    setBusy(true)
    try{
      const payload={
        id:user.id,
        first_name:firstName.trim(),
        birth_date:birth||null,
        bio:bio.trim(),
        dating_intention:datingIntention,
        hangout_personality:hangoutPersonality,
        custom_hangout_personality:customPersonality||null,
        ...socialProfileUrls,
        gender_identity:genderIdentity,
        gender_identity_detail:genderIdentity==='self_described'?genderIdentityDetail.trim():null,
        interested_in_genders:openToAllGenders?[]:interestedInGenders,
        open_to_all_genders:openToAllGenders,
        photo_url:p.photo_url,
      }
      const {data,error}=await supabase!.from('profiles').upsert(payload).select().single()
      if(error)throw error
      setP(data)
      setMsg('Profile saved.')
    }catch(error){
      setMsg(errorMessage(error,'Unable to save profile.'))
    }finally{
      setBusy(false)
    }
  }

  async function uploadPhoto(file:File){
    setBusy(true)
    setMsg('Preparing photo…')
    try{
      const previousPath=p?.photo_url?getProfilePhotoStoragePath(p.photo_url,user.id):null
      const additionalPaths=(p?.additional_photo_urls||[]).filter((url):url is string=>Boolean(url))
        .map(url=>getProfilePhotoStoragePath(url,user.id))
      const photo=await preparePhoto(file)
      const path=`${user.id}/profile-${crypto.randomUUID()}.jpg`
      const {error:uploadError}=await supabase!.storage.from('profile-photos').upload(path,photo,{
        cacheControl:'3600',
        contentType:'image/jpeg',
        upsert:true,
      })
      if(uploadError)throw uploadError
      const url=`${supabase!.storage.from('profile-photos').getPublicUrl(path).data.publicUrl}?v=${Date.now()}`
      const {data,error}=await supabase!.from('profiles').update({photo_url:url}).eq('id',user.id).select().single()
      if(error)throw error
      setP(data)
      let cleanupMessage=''
      if(previousPath&&!additionalPaths.includes(previousPath)){
        try{
          const {error:removeError}=await supabase!.storage.from('profile-photos').remove([previousPath])
          if(removeError)cleanupMessage=` The previous photo could not be removed from storage: ${removeError.message}`
        }catch(error){
          cleanupMessage=` The previous photo could not be removed from storage: ${errorMessage(error,'Unknown storage error.')}`
        }
      }
      setMsg(`Profile photo updated. This photo is publicly accessible by URL.${cleanupMessage}`)
    }catch(error){
      setMsg(errorMessage(error,'Unable to upload photo.'))
    }finally{
      setBusy(false)
    }
  }

  async function uploadAdditionalPhoto(slot:number,file:File){
    if(!p?.photo_url){
      setMsg('Upload your required profile photo first.')
      return
    }
    setBusy(true)
    setMsg('Preparing photo…')
    try{
      const existingPaths=[
        ...(p.photo_url?[getProfilePhotoStoragePath(p.photo_url,user.id)]:[]),
        ...(p.additional_photo_urls||[])
          .filter((url,index):url is string=>index!==slot&&Boolean(url))
          .map(url=>getProfilePhotoStoragePath(url,user.id)),
      ]
      const previousUrl=p.additional_photo_urls?.[slot]
      const previousPath=previousUrl?getProfilePhotoStoragePath(previousUrl,user.id):null
      const photo=await preparePhoto(file)
      const path=`${user.id}/additional-${crypto.randomUUID()}.jpg`
      const {error:uploadError}=await supabase!.storage.from('profile-photos').upload(path,photo,{
        cacheControl:'3600',
        contentType:'image/jpeg',
        upsert:true,
      })
      if(uploadError)throw uploadError
      const urls:(string|null)[]=[...(p.additional_photo_urls||[null,null])]
      urls[slot]=`${supabase!.storage.from('profile-photos').getPublicUrl(path).data.publicUrl}?v=${Date.now()}`
      const {data,error}=await supabase!.from('profiles').update({additional_photo_urls:urls}).eq('id',user.id).select().single()
      if(error)throw error
      setP(data)
      let cleanupMessage=''
      if(previousPath&&!existingPaths.includes(previousPath)){
        try{
          const {error:removeError}=await supabase!.storage.from('profile-photos').remove([previousPath])
          if(removeError)cleanupMessage=` The previous photo could not be removed from storage: ${removeError.message}`
        }catch(error){
          cleanupMessage=` The previous photo could not be removed from storage: ${errorMessage(error,'Unknown storage error.')}`
        }
      }
      setMsg(`Additional profile photo updated.${cleanupMessage}`)
    }catch(error){
      setMsg(errorMessage(error,'Unable to upload additional photo.'))
    }finally{
      setBusy(false)
    }
  }

  async function removeAdditionalPhoto(slot:number){
    const photoUrl=p?.additional_photo_urls?.[slot]
    if(!photoUrl)return
    setBusy(true)
    setMsg('')
    try{
      const photoPath=getProfilePhotoStoragePath(photoUrl,user.id)
      const urls:(string|null)[]=[...(p.additional_photo_urls||[null,null])]
      urls[slot]=null
      const usedPaths=[
        ...(p.photo_url?[getProfilePhotoStoragePath(p.photo_url,user.id)]:[]),
        ...urls.filter((url):url is string=>Boolean(url)).map(url=>getProfilePhotoStoragePath(url,user.id)),
      ]
      const {data,error}=await supabase!.from('profiles').update({additional_photo_urls:urls}).eq('id',user.id).select().single()
      if(error)throw error
      setP(data)
      let cleanupMessage=''
      if(!usedPaths.includes(photoPath)){
        try{
          const {error:removeError}=await supabase!.storage.from('profile-photos').remove([photoPath])
          if(removeError)cleanupMessage=` Photo storage cleanup failed: ${removeError.message}`
        }catch(error){
          cleanupMessage=` Photo storage cleanup failed: ${errorMessage(error,'Unknown storage error.')}`
        }
      }
      setMsg(`Additional photo removed.${cleanupMessage}`)
    }catch(error){
      setMsg(errorMessage(error,'Unable to remove additional photo.'))
    }finally{
      setBusy(false)
    }
  }

  async function makeDefaultPhoto(slot:number){
    if(!p?.photo_url||!p.additional_photo_urls?.[slot])return
    setBusy(true)
    setMsg('')
    try{
      const urls:(string|null)[]=[
        p.additional_photo_urls[0]||null,
        p.additional_photo_urls[1]||null,
      ]
      urls[slot]=p.photo_url
      const {data,error}=await supabase!.from('profiles').update({
        photo_url:p.additional_photo_urls[slot],
        additional_photo_urls:urls,
      }).eq('id',user.id).select().single()
      if(error)throw error
      setP(data)
      setMsg('Profile photo updated. Your previous profile photo is now an extra photo.')
    }catch(error){
      setMsg(errorMessage(error,'Unable to change profile photo.'))
    }finally{
      setBusy(false)
    }
  }

  async function submitIdentityDocument(){
    if(!verificationFile||!verificationConsent)return
    setVerificationBusy(true)
    setVerificationError('')
    setVerificationMessage('')
    let reservation:VerificationUploadReservation|null=null
    try{
      const prepared=await prepareIdentityDocument(verificationFile)
      const {data,error:reserveError}=await supabase!.rpc('begin_identity_verification_upload',{
        consent_confirmed:true,
      })
      if(reserveError)throw reserveError
      const reservationResult=(data||[])[0] as VerificationUploadReservation|undefined
      if(!reservationResult)throw new Error('Unable to start an ID review. Try again.')
      reservation=reservationResult

      const {error:uploadError}=await supabase!.storage.from('identity-documents').upload(
        reservation.upload_path,
        prepared,
        {cacheControl:'0',contentType:'image/jpeg',upsert:true},
      )
      if(uploadError)throw uploadError

      const {error:submitError}=await supabase!.rpc('complete_identity_verification_upload',{
        target_request_id:reservation.request_id,
      })
      if(submitError)throw submitError

      setVerification(await fetchVerificationStatus())
      setVerificationFile(null)
      setVerificationConsent(false)
      setVerificationMessage('Your ID was submitted for review. It is private and will be deleted after a decision.')
    }catch(error){
      if(reservation){
        setVerification({
          request_id:reservation.request_id,
          status:'uploading',
          submitted_at:null,
          decided_at:null,
          upload_path:reservation.upload_path,
        })
      }
      setVerificationError(errorMessage(error,'Unable to submit your ID for review.'))
    }finally{
      setVerificationBusy(false)
    }
  }

  async function withdrawIdentityVerification(){
    if(!verification)return
    setVerificationBusy(true)
    setVerificationError('')
    setVerificationMessage('')
    try{
      const {data:uploadPath,error:withdrawError}=await supabase!.rpc('withdraw_identity_verification',{
        target_request_id:verification.request_id,
      })
      if(withdrawError)throw withdrawError
      if(typeof uploadPath==='string'&&uploadPath){
        const {error:deleteError}=await supabase!.storage.from('identity-documents').remove([uploadPath])
        if(deleteError){
          setVerification(await fetchVerificationStatus())
          throw new Error(`Request withdrawn, but ID deletion failed. Retry cleanup: ${deleteError.message}`)
        }
        const {error:cleanupError}=await supabase!.rpc('finalize_identity_verification_cleanup',{
          target_request_id:verification.request_id,
        })
        if(cleanupError){
          setVerification(await fetchVerificationStatus())
          throw new Error(`Request withdrawn, but ID cleanup could not be finalized. Retry cleanup: ${cleanupError.message}`)
        }
      }
      setVerification(await fetchVerificationStatus())
      setVerificationMessage('Your request was withdrawn and the uploaded ID was deleted.')
    }catch(error){
      setVerificationError(errorMessage(error,'Unable to withdraw the ID review.'))
    }finally{
      setVerificationBusy(false)
    }
  }

  function toggleHangoutPersonality(value:HangoutPersonality){
    if(hangoutPersonality.includes(value)){
      setHangoutPersonality(hangoutPersonality.filter(item=>item!==value))
      setMsg('')
    }else if(hangoutPersonality.length>=5){
      setMsg('Choose up to five hangout personalities.')
    }else{
      setHangoutPersonality([...hangoutPersonality,value])
      setMsg('')
    }
  }

  function toggleGenderPreference(value:GenderCategory){
    setInterestedInGenders(current=>current.includes(value)
      ?current.filter(item=>item!==value)
      :[...current,value])
    setMsg('')
  }

  const birthDateDetails=getBirthDateDetails(birthDate)
  const additionalPhotos=p?.additional_photo_urls||[null,null]

  return <section className="panel">
    <h2>Your profile</h2>
    <section className="profile-photo" aria-labelledby="profile-photos-title">
      <h3 id="profile-photos-title">Profile photos <span className="fine">Required · up to 3 photos</span></h3>
      <div className="profile-photo-grid">
        <label className={`photo-upload-tile${p?.photo_url?' has-photo':''}`} title={p?.photo_url?'Replace profile photo':'Upload profile photo'}>
          {p?.photo_url
            ?<img className="profile-photo-preview" src={p.photo_url} alt="Your profile photo"/>
            :<span className="photo-tile-add"><span className="photo-tile-add-mark" aria-hidden="true">+</span><span>Profile photo</span></span>}
          {p?.photo_url&&<span className="photo-tile-badge">Profile</span>}
          <input className="photo-file-input" type="file" accept="image/jpeg,image/png,image/webp" aria-label={p?.photo_url?'Replace profile photo':'Upload profile photo'} disabled={busy||loading} onChange={e=>{
            const file=e.currentTarget.files?.[0]
            if(file)uploadPhoto(file)
            e.currentTarget.value=''
          }}/>
        </label>
        {[0,1].map(slot=>{
          const photo=additionalPhotos[slot]
          return <div className="photo-upload-card" key={slot}>
            <label className={`photo-upload-tile${photo?' has-photo':''}${p?.photo_url?'':' is-disabled'}`} title={photo?'Replace extra photo':'Add photo'}>
              {photo
                ?<img className="additional-photo-preview" src={photo} alt={`Additional profile photo ${slot+1}`}/>
                :<span className="photo-tile-add"><span className="photo-tile-add-mark" aria-hidden="true">+</span><span>Add photo</span></span>}
              <input className="photo-file-input" type="file" accept="image/jpeg,image/png,image/webp" aria-label={photo?`Replace additional photo ${slot+1}`:`Add additional photo ${slot+1}`} disabled={busy||loading||!p?.photo_url} onChange={e=>{
                const file=e.currentTarget.files?.[0]
                if(file)uploadAdditionalPhoto(slot,file)
                e.currentTarget.value=''
              }}/>
            </label>
            {photo&&<>
              <span className="photo-tile-badge">Extra</span>
              <button className="photo-tile-default" type="button" onClick={()=>makeDefaultPhoto(slot)} disabled={busy||loading}>Make default</button>
              <button className="photo-tile-remove" type="button" aria-label={`Remove additional photo ${slot+1}`} title="Remove photo" onClick={()=>removeAdditionalPhoto(slot)} disabled={busy||loading}>×</button>
            </>}
          </div>
        })}
      </div>
      <p className="fine photo-upload-note">JPEG, PNG, or WebP · up to 8 MB. Photos are re-encoded and may appear in discovery.</p>
    </section>
    {loading?<p aria-live="polite">Loading profile…</p>:<form className="profile-form" onSubmit={save}>
      <label>First name<input name="first_name" value={firstName} onChange={e=>setFirstName(e.target.value)} required maxLength={50}/></label>
      <label>Birth date<input name="birth_date" type="date" value={birthDate} onChange={e=>setBirthDate(e.target.value)} required/></label>
      {birthDate&&<p className="profile-derived" aria-live="polite">
        {birthDateDetails
          ?<>Age: <strong>{birthDateDetails.age}</strong> · Zodiac sign: <strong>{birthDateDetails.zodiac}</strong></>
          :'Enter a valid birth date to see your age and zodiac sign.'}
      </p>}
      <label>Short bio<textarea name="bio" value={bio} onChange={e=>setBio(e.target.value)} maxLength={280} placeholder="Coffee walks, live music, weekend markets…"/></label>
      <label>Primary dating intention
        <select name="dating_intention" value={datingIntention} onChange={e=>{
          if(isDatingIntention(e.target.value))setDatingIntention(e.target.value)
        }} required disabled={busy}>
          <option value="">Choose your intention</option>
          {datingIntentions.map(intention=><option key={intention} value={intention}>{intention}</option>)}
        </select>
      </label>
      <fieldset className="interest-options gender-options">
        <legend>Gender identity <span className="fine">Optional · shown in your profile dialog</span></legend>
        <label>How do you describe yourself?
          <select
            value={genderIdentity||''}
            onChange={event=>setGenderIdentity(isGenderCategory(event.target.value)?event.target.value:null)}
            disabled={busy}
          >
            <option value="">Prefer not to say</option>
            {genderOptions.map(option=><option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        {genderIdentity==='self_described'&&<label>Describe your gender
          <input
            value={genderIdentityDetail}
            onChange={event=>setGenderIdentityDetail(event.target.value)}
            maxLength={50}
            required
            disabled={busy}
            placeholder="Your description"
          />
        </label>}
      </fieldset>
      <fieldset className="interest-options gender-options">
        <legend>Interested in</legend>
        <label className="check">
          <input
            type="checkbox"
            checked={openToAllGenders}
            onChange={event=>{
              setOpenToAllGenders(event.target.checked)
              setInterestedInGenders([])
            }}
            disabled={busy}
          />
          Open to everyone
        </label>
        {!openToAllGenders&&<div className="interest-list">
          {genderOptions.map(option=><label className="check" key={option.value}>
            <input
              type="checkbox"
              checked={interestedInGenders.includes(option.value)}
              onChange={()=>toggleGenderPreference(option.value)}
              disabled={busy}
            />
            {option.label}
          </label>)}
        </div>}
        <p className="fine">Discover uses this preference mutually when people share a gender category. Profiles that don’t disclose gender may still appear.</p>
      </fieldset>
      <fieldset className="interest-options">
        <legend>Hangout personality <span className="fine">Choose 3–5 predefined · {hangoutPersonality.length}/5</span></legend>
        <p className="fine">Pick the kinds of hangouts you enjoy most. These help people see what spending time with you could be like.</p>
        <div className="interest-list">
          {hangoutPersonalityOptions.map(personality=><label className="check" key={personality}>
            <input type="checkbox" checked={hangoutPersonality.includes(personality)} onChange={()=>toggleHangoutPersonality(personality)} disabled={busy||(!hangoutPersonality.includes(personality)&&hangoutPersonality.length>=5)}/>
            {personality}
          </label>)}
        </div>
        <label>Custom personalities (up to 3, optional)
          <input
            name="custom_hangout_personality"
            value={customHangoutPersonality}
            onChange={event=>setCustomHangoutPersonality(event.target.value)}
            maxLength={94}
            disabled={busy}
            placeholder="Cycling, Cooking, Photography"
          />
        </label>
        <p className="fine">Enter up to 3 unique one-word options, separated by commas. Each can be up to 30 characters and adds to your 3–5 choices.</p>
      </fieldset>
      <fieldset className="interest-options social-profile-fields">
        <legend>Social profiles <span className="fine">Optional · visible only to your matches</span></legend>
        <label>Facebook
          <input type="url" name="facebook_url" value={facebookUrl} onChange={event=>setFacebookUrl(event.target.value)} maxLength={2048} placeholder="https://www.facebook.com/your-profile" disabled={busy}/>
        </label>
        <label>Instagram
          <input type="url" name="instagram_url" value={instagramUrl} onChange={event=>setInstagramUrl(event.target.value)} maxLength={2048} placeholder="https://www.instagram.com/your-profile" disabled={busy}/>
        </label>
        <label>TikTok
          <input type="url" name="tiktok_url" value={tiktokUrl} onChange={event=>setTiktokUrl(event.target.value)} maxLength={2048} placeholder="https://www.tiktok.com/@your-profile" disabled={busy}/>
        </label>
      </fieldset>
      <button className="primary" disabled={busy||!p?.photo_url}>Save profile</button>
      <p className="status" aria-live="polite">{msg}</p>
    </form>}
    <section className="identity-verification profile-photo" aria-labelledby="identity-verification-title">
      <h3 id="identity-verification-title">Account verification</h3>
      <p className="fine">Upload a clear photo of a government-issued photo ID. HangOut admins and moderators can review it while your request is open. The image is stored privately and deleted after a decision. Approval adds a public Verified badge to your discovery profile; it only means your ID was reviewed, not that a background or safety check was performed.</p>
      {verificationLoading?<p role="status">Loading ID review status…</p>:<>
        {verification?.status==='verified'&&<>
          <span className="verification-badge">Verified</span>
          <p className="fine">A HangOut admin or moderator reviewed your ID. This is not a background or safety check.</p>
        </>}
        {verification?.status==='pending'&&<>
          <p role="status">Your ID review is pending. The image will be deleted after a decision.</p>
          <button type="button" className="secondary" onClick={()=>void withdrawIdentityVerification()} disabled={verificationBusy}>
            {verificationBusy?'Withdrawing…':'Withdraw request and delete ID'}
          </button>
        </>}
        {verification?.status==='uploading'&&<p role="status">Your upload is incomplete. Choose the ID image again to resume it.</p>}
        {verification?.status==='rejected'&&<p role="status">Your ID could not be verified. You can submit a clearer photo to try again.</p>}
        {verification?.status==='cleanup_pending'&&<p role="status">A decision was recorded. HangOut staff are completing ID deletion before the result is finalized.</p>}
        {verification?.status==='withdrawn_cleanup_pending'&&<>
          <p role="status">Your request was withdrawn. The private ID image still needs cleanup.</p>
          <button type="button" className="secondary" onClick={()=>void withdrawIdentityVerification()} disabled={verificationBusy}>
            {verificationBusy?'Deleting…':'Retry ID deletion'}
          </button>
        </>}
        {!verificationError&&(verification===null||verification.status==='rejected'||verification.status==='uploading')&&<>
          <label>Government-issued photo ID (JPEG, PNG, or WebP; up to 15 MB)
            <input
              type="file"
              accept="image/jpeg,image/png,image/webp"
              disabled={verificationBusy}
              onChange={event=>setVerificationFile(event.currentTarget.files?.[0]||null)}
            />
          </label>
          <label className="check">
            <input
              type="checkbox"
              checked={verificationConsent}
              onChange={event=>setVerificationConsent(event.target.checked)}
              disabled={verificationBusy}
            />
            I understand that HangOut admins and moderators will review this ID, the image will be deleted after a decision, and approval adds a public Verified badge.
          </label>
          <button
            type="button"
            className="primary"
            onClick={()=>void submitIdentityDocument()}
            disabled={verificationBusy||!verificationFile||!verificationConsent}
          >
            {verificationBusy?'Submitting ID…':verification?.status==='uploading'?'Resume ID submission':'Submit ID for review'}
          </button>
        </>}
      </>}
      {verificationError&&<p className="status" role="alert">{verificationError}</p>}
      {verificationError&&<button type="button" className="secondary" onClick={()=>void retryVerificationStatus()} disabled={verificationLoading||verificationBusy}>Retry status check</button>}
      {verificationMessage&&<p className="admin-success" role="status">{verificationMessage}</p>}
    </section>
  </section>
}
