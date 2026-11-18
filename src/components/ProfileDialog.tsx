import {useEffect,useRef} from 'react'
import type {DatingIntention,GenderCategory,HangoutPersonality} from '../types'

type SharedPlace={id:string;name:string;story:string|null}
export type ViewableProfile={
  id:string
  first_name:string
  age:number|null
  zodiac_sign:string|null
  bio:string
  photo_url:string|null
  hangout_personality:HangoutPersonality[]
  custom_hangout_personality:string|null
  additional_photo_urls:(string|null)[]
  dating_intention:DatingIntention
  gender_identity:GenderCategory|null
  gender_identity_detail:string|null
  shared_places:SharedPlace[]
  is_verified:boolean
}

const genderLabels={woman:'Woman',man:'Man',non_binary:'Non-binary',self_described:'Self-described'}

export function getPersonalityLabels(person:ViewableProfile){
  const customLabels=person.custom_hangout_personality
    ?.split(',')
    .map(personality=>personality.trim())
    .filter(Boolean)||[]
  return [...person.hangout_personality,...customLabels]
}

export function ProfileDialog({person,onClose}:{person:ViewableProfile;onClose:()=>void}){
  const dialogRef=useRef<HTMLDialogElement>(null)

  useEffect(()=>{
    const dialog=dialogRef.current
    dialog?.showModal()
    return ()=>{
      if(dialog?.open)dialog.close()
    }
  },[person.id])

  const photos=[person.photo_url,...person.additional_photo_urls].filter((url):url is string=>Boolean(url))
  const personalityLabels=getPersonalityLabels(person)

  return <dialog className="profile-dialog" ref={dialogRef} aria-labelledby="candidate-profile-title"
    onCancel={event=>{event.preventDefault();onClose()}}>
    <div className="profile-dialog-header">
      <div>
        <h2 id="candidate-profile-title">{person.first_name}'s profile</h2>
        {person.age!==null&&person.zodiac_sign&&<p className="profile-summary">{person.age} years old · {person.zodiac_sign}</p>}
        {person.is_verified&&<p className="verification-summary">
          <span className="verification-badge" aria-label="Verified">Verified</span>
          <span className="fine">A HangOut admin or moderator reviewed a government-issued photo ID. This is not a background or safety check.</span>
        </p>}
      </div>
      <button type="button" className="secondary" onClick={onClose} autoFocus>Close</button>
    </div>
    <div className="profile-gallery" role="group" aria-label={`${person.first_name}'s photos`}>
      {photos.length>0?photos.map((url,index)=><img src={url} alt={index===0?`${person.first_name}'s profile photo`:`${person.first_name}'s additional photo ${index}`} key={url}/>):
        <div className="candidate-avatar" aria-hidden="true">{person.first_name.slice(0,1)}</div>}
    </div>
    <section className="profile-details">
      <h3>About</h3>
      <p>{person.bio||'No bio added yet.'}</p>
      <p><strong>Looking for:</strong> {person.dating_intention}</p>
      {person.gender_identity&&<p><strong>Gender:</strong> {person.gender_identity==='self_described'?person.gender_identity_detail:genderLabels[person.gender_identity]}</p>}
    </section>
    {personalityLabels.length>0&&<section className="profile-details">
      <h3>Hangout personality</h3>
      <ul className="interest-chips" aria-label={`${person.first_name}'s hangout personality`}>{personalityLabels.map(personality=><li key={personality}>{personality}</li>)}</ul>
    </section>}
    <section className="profile-details">
      <h3>Shared places</h3>
      <ul className="shared-places" aria-label={`Places shared with ${person.first_name}`}>
        {person.shared_places.map(place=><li className="candidate-place" key={place.id}>
          <div className="candidate-place-name">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>
            </svg>
            <strong>{place.name}</strong>
          </div>
          {place.story&&<blockquote className="place-story">
            <strong>{person.first_name}'s place story</strong>
            <p>{place.story}</p>
          </blockquote>}
        </li>)}
      </ul>
    </section>
  </dialog>
}
