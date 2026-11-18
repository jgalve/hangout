import {FormEvent,useCallback,useEffect,useRef,useState} from 'react'
import {supabase} from '../lib/supabase'
import {FeaturedHangoutCard,getOpenStreetMapUrl} from './FeaturedHangoutCard'
import type {FeaturedHangout} from './FeaturedHangoutCard'

type AdminRole='admin'|'moderator'
type DashboardTab='overview'|'users'|'reports'|'verification'|'featured'
type FeaturedPlace={id:string;name:string;display_name:string;osm_type:string;osm_id:string}
type Stats={
  total_users:number
  enabled_users:number
  new_users_30d:number
  matches_30d:number
  pending_reports:number
}
type AdminUser={
  id:string
  first_name:string
  email:string|null
  created_at:string
  account_active:boolean
  reports_received:number
}
type Report={
  id:string
  reporter_id:string
  reporter_name:string
  reported_id:string
  reported_name:string
  reason:string
  details:string
  status:'open'|'reviewing'|'resolved'|'dismissed'
  created_at:string
}
type Evidence={
  reported_profile_snapshot:Record<string,unknown>
  message_snapshot:{id:number;sender_id:string;body:string;created_at:string}[]
}
type Action={
  id:string
  action:string
  note:string
  moderator_id:string
  created_at:string
}
type AccountStatusEvent={
  account_active:boolean
  reason:string
  actor_id:string
  created_at:string
}
type VerificationRequest={
  request_id:string
  user_id:string
  first_name:string
  status:'uploading'|'pending'|'verified'|'rejected'|'withdrawn'
  submitted_at:string|null
  decided_at:string|null
  storage_path:string|null
}

const pageSize=25
const emptyFeaturedHangout:FeaturedHangout={
  place_id:'',
  osm_type:'',
  osm_id:'',
  venue_name:'',
  promo_title:'',
  promo_description:'',
  promo_terms:'',
  photo_url:null,
  promo_cta_label:null,
  promo_cta_url:null,
  demo_only:true,
  is_published:false,
  updated_at:'',
}
const statusLabels:Record<Report['status'],string>={
  open:'Open',
  reviewing:'Reviewing',
  resolved:'Resolved',
  dismissed:'Dismissed',
}

function formatDate(value:string){
  return new Date(value).toLocaleDateString(undefined,{year:'numeric',month:'short',day:'numeric'})
}

function getOptionalHttpsUrl(value:string|null){
  if(!value?.trim())return null
  try{
    const url=new URL(value.trim())
    return url.protocol==='https:'?url.toString():undefined
  }catch{
    return undefined
  }
}

function getErrorMessage(error:unknown,fallback:string){
  if(typeof error==='object'&&error!==null&&'message' in error&&typeof error.message==='string')return error.message
  return fallback
}

export function AdminDashboard({role}:{role:AdminRole}){
  const [activeTab,setActiveTab]=useState<DashboardTab>(role==='admin'?'overview':'reports')
  const [stats,setStats]=useState<Stats|null>(null)
  const [users,setUsers]=useState<AdminUser[]>([])
  const [usersLoading,setUsersLoading]=useState(false)
  const [searchText,setSearchText]=useState('')
  const [submittedSearch,setSubmittedSearch]=useState('')
  const [userOffset,setUserOffset]=useState(0)
  const [hasNextPage,setHasNextPage]=useState(false)
  const [selectedUser,setSelectedUser]=useState<AdminUser|null>(null)
  const [statusHistory,setStatusHistory]=useState<AccountStatusEvent[]>([])
  const [statusReason,setStatusReason]=useState('')
  const [statusBusy,setStatusBusy]=useState(false)
  const [reports,setReports]=useState<Report[]>([])
  const [reportFilter,setReportFilter]=useState('')
  const [selectedReport,setSelectedReport]=useState<Report|null>(null)
  const [evidence,setEvidence]=useState<Evidence|null>(null)
  const [actions,setActions]=useState<Action[]>([])
  const [reportNote,setReportNote]=useState('')
  const [reportBusy,setReportBusy]=useState(false)
  const [detailLoading,setDetailLoading]=useState(false)
  const [verificationRequests,setVerificationRequests]=useState<VerificationRequest[]>([])
  const [selectedVerification,setSelectedVerification]=useState<VerificationRequest|null>(null)
  const [verificationImageUrl,setVerificationImageUrl]=useState('')
  const [verificationImageReady,setVerificationImageReady]=useState(false)
  const [verificationImageLoading,setVerificationImageLoading]=useState(false)
  const [verificationBusy,setVerificationBusy]=useState(false)
  const verificationImageLoadId=useRef(0)
  const [featuredDraft,setFeaturedDraft]=useState<FeaturedHangout>(emptyFeaturedHangout)
  const [featuredPlaceSearch,setFeaturedPlaceSearch]=useState('')
  const [featuredPlaceResults,setFeaturedPlaceResults]=useState<FeaturedPlace[]>([])
  const [featuredPlaceLoading,setFeaturedPlaceLoading]=useState(false)
  const [featuredPlaceError,setFeaturedPlaceError]=useState('')
  const [selectedFeaturedPlace,setSelectedFeaturedPlace]=useState<FeaturedPlace|null>(null)
  const [featuredBusy,setFeaturedBusy]=useState(false)
  const [loading,setLoading]=useState(true)
  const [error,setError]=useState('')
  const [notice,setNotice]=useState('')

  const loadStats=useCallback(async()=>{
    const {data,error:rpcError}=await supabase!.rpc('admin_dashboard_stats')
    if(rpcError)throw rpcError
    setStats((data?.[0] as Stats|undefined)||null)
  },[])

  const loadUsers=useCallback(async(query:string,offset:number)=>{
    setUsersLoading(true)
    const {data,error:rpcError}=await supabase!.rpc('admin_search_users',{
      search_query:query,
      limit_count:pageSize+1,
      offset_count:offset,
    })
    setUsersLoading(false)
    if(rpcError)throw rpcError
    const rows=(data||[]) as AdminUser[]
    setHasNextPage(rows.length>pageSize)
    setUsers(rows.slice(0,pageSize))
  },[])

  const loadReports=useCallback(async(filter:string)=>{
    const {data,error:rpcError}=await supabase!.rpc('moderator_report_queue',{
      status_filter:filter||null,
      limit_count:100,
    })
    if(rpcError)throw rpcError
    setReports((data||[]) as Report[])
  },[])

  const loadVerifications=useCallback(async()=>{
    const {data,error:rpcError}=await supabase!.rpc('moderator_identity_verification_queue',{
      limit_count:100,
    })
    if(rpcError)throw rpcError
    setVerificationRequests((data||[]) as VerificationRequest[])
  },[])

  const loadFeaturedHangout=useCallback(async()=>{
    const {data,error:rpcError}=await supabase!.rpc('admin_get_featured_hangout')
    if(rpcError)throw new Error(rpcError.message)
    const rows=(data||[]) as FeaturedHangout[]
    const featured=rows[0]||emptyFeaturedHangout
    setFeaturedDraft(featured)
    setFeaturedPlaceResults([])
    setFeaturedPlaceError('')
    if(!featured.place_id){
      setSelectedFeaturedPlace(null)
      setFeaturedPlaceSearch('')
      return
    }
    const {data:place,error:placeError}=await supabase!.from('places')
      .select('id,name,display_name,osm_type,osm_id')
      .eq('id',featured.place_id)
      .maybeSingle()
    if(placeError)throw new Error(placeError.message)
    if(!place)throw new Error('The featured hangout place is missing from the place catalog.')
    const selectedPlace=place as FeaturedPlace
    setSelectedFeaturedPlace(selectedPlace)
    setFeaturedPlaceSearch(selectedPlace.name)
  },[])

  async function searchFeaturedPlaces(){
    const query=featuredPlaceSearch.trim()
    setFeaturedPlaceResults([])
    setFeaturedPlaceError('')
    if(query.length<2){
      setFeaturedPlaceError('Enter at least two characters to search places.')
      return
    }
    setFeaturedPlaceLoading(true)
    try{
      const {data,error:searchError}=await supabase!.from('places')
        .select('id,name,display_name,osm_type,osm_id')
        .ilike('name',`%${query}%`)
        .order('name')
        .limit(10)
      if(searchError)throw new Error(searchError.message)
      setFeaturedPlaceResults((data||[]) as FeaturedPlace[])
      if(!(data||[]).length)setFeaturedPlaceError('No places matched. Try another name.')
    }catch(searchError){
      setFeaturedPlaceError(getErrorMessage(searchError,'Unable to search the place catalog.'))
    }finally{
      setFeaturedPlaceLoading(false)
    }
  }

  function chooseFeaturedPlace(place:FeaturedPlace){
    setSelectedFeaturedPlace(place)
    setFeaturedPlaceSearch(place.name)
    setFeaturedPlaceResults([])
    setFeaturedPlaceError('')
    setFeaturedDraft(current=>({
      ...current,
      place_id:place.id,
      osm_type:place.osm_type,
      osm_id:place.osm_id,
      venue_name:place.name,
    }))
  }

  async function refreshVerificationQueue(){
    try{
      await loadVerifications()
    }catch(loadError){
      setError(loadError instanceof Error?loadError.message:'Unable to refresh ID reviews.')
    }
  }

  const refreshCurrentTab=useCallback(async()=>{
    setError('')
    setNotice('')
    setLoading(true)
    try{
      if(activeTab==='overview'&&role==='admin')await loadStats()
      if(activeTab==='users'&&role==='admin')await loadUsers(submittedSearch,userOffset)
      if(activeTab==='reports')await loadReports(reportFilter)
      if(activeTab==='verification')await loadVerifications()
      if(activeTab==='featured'&&role==='admin')await loadFeaturedHangout()
    }catch(loadError){
      setError(loadError instanceof Error?loadError.message:'Unable to load admin data.')
    }finally{
      setLoading(false)
    }
  },[activeTab,loadFeaturedHangout,loadReports,loadStats,loadUsers,loadVerifications,reportFilter,role,submittedSearch,userOffset])

  useEffect(()=>{void refreshCurrentTab()},[refreshCurrentTab])

  useEffect(()=>{
    if(!selectedUser)return
    let cancelled=false
    async function loadStatusHistory(){
      const {data,error:historyError}=await supabase!.from('account_status_events')
        .select('account_active,reason,actor_id,created_at')
        .eq('user_id',selectedUser!.id)
        .order('created_at',{ascending:false})
      if(cancelled)return
      if(historyError)setError(historyError.message)
      else setStatusHistory((data||[]) as AccountStatusEvent[])
    }
    void loadStatusHistory()
    return()=>{cancelled=true}
  },[selectedUser?.id,selectedUser?.account_active])

  async function openReport(report:Report){
    setSelectedReport(report)
    setEvidence(null)
    setActions([])
    setDetailLoading(true)
    setError('')
    const [evidenceResult,actionsResult]=await Promise.all([
      supabase!.from('report_evidence')
        .select('reported_profile_snapshot,message_snapshot')
        .eq('report_id',report.id)
        .maybeSingle(),
      supabase!.from('moderation_actions')
        .select('id,action,note,moderator_id,created_at')
        .eq('report_id',report.id)
        .order('created_at',{ascending:false}),
    ])
    setDetailLoading(false)
    if(evidenceResult.error||actionsResult.error){
      setError(evidenceResult.error?.message||actionsResult.error?.message||'Unable to load report details.')
      return
    }
    setEvidence(evidenceResult.data as Evidence|null)
    setActions((actionsResult.data||[]) as Action[])
  }

  async function searchUsers(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    setSubmittedSearch(searchText.trim())
    setUserOffset(0)
  }

  async function saveFeaturedHangout(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    setError('')
    setNotice('')
    const photoUrl=getOptionalHttpsUrl(featuredDraft.photo_url)
    const ctaUrl=getOptionalHttpsUrl(featuredDraft.promo_cta_url)
    const ctaLabel=featuredDraft.promo_cta_label?.trim()||null
    if(!featuredDraft.place_id){
      setError('Select a place from the place catalog before saving.')
      return
    }
    if(photoUrl===undefined){
      setError('Photo URL must use HTTPS.')
      return
    }
    if(ctaUrl===undefined){
      setError('Call-to-action URL must use HTTPS.')
      return
    }
    if(Boolean(ctaLabel)!==Boolean(ctaUrl)){
      setError('Provide both a call-to-action label and URL, or leave both blank.')
      return
    }

    setFeaturedBusy(true)
    try{
      const {error:saveError}=await supabase!.rpc('admin_save_featured_hangout',{
        p_place_id:featuredDraft.place_id,
        p_venue_name:featuredDraft.venue_name.trim(),
        p_promo_title:featuredDraft.promo_title.trim(),
        p_promo_description:featuredDraft.promo_description.trim(),
        p_promo_terms:featuredDraft.promo_terms.trim(),
        p_photo_url:photoUrl,
        p_promo_cta_label:ctaLabel,
        p_promo_cta_url:ctaUrl,
        p_demo_only:featuredDraft.demo_only,
        p_is_published:featuredDraft.is_published,
      })
      if(saveError)throw new Error(saveError.message)
      await loadFeaturedHangout()
      setNotice(featuredDraft.is_published?'Featured hangout saved and published.':'Featured hangout saved as a draft.')
    }catch(saveError){
      setError(getErrorMessage(saveError,'Unable to save the featured hangout.'))
    }finally{
      setFeaturedBusy(false)
    }
  }

  async function updateAccountStatus(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    if(!selectedUser)return
    setStatusBusy(true)
    setError('')
    const nextActive=!selectedUser.account_active
    const {error:rpcError}=await supabase!.rpc('admin_set_account_active',{
      target_user_id:selectedUser.id,
      next_active:nextActive,
      action_reason:statusReason.trim(),
    })
    setStatusBusy(false)
    if(rpcError){
      setError(rpcError.message)
      return
    }
    setUsers(current=>current.map(user=>user.id===selectedUser.id?{...user,account_active:nextActive}:user))
    setSelectedUser({...selectedUser,account_active:nextActive})
    setStatusReason('')
    setNotice(nextActive?'Account reactivated.':'Account deactivated. App access is now blocked.')
    if(stats){
      setStats({...stats,enabled_users:stats.enabled_users+(nextActive?1:-1)})
    }
  }

  async function updateReportStatus(nextStatus:Report['status']){
    if(!selectedReport)return
    setReportBusy(true)
    setError('')
    const {error:rpcError}=await supabase!.rpc('moderate_report',{
      target_report_id:selectedReport.id,
      next_status:nextStatus,
      action_note:reportNote.trim(),
    })
    setReportBusy(false)
    if(rpcError){
      setError(rpcError.message)
      return
    }
    setReportNote('')
    await refreshCurrentTab()
    const updatedReport={...selectedReport,status:nextStatus}
    setSelectedReport(updatedReport)
    await openReport(updatedReport)
    setNotice(`Report marked ${statusLabels[nextStatus].toLowerCase()}.`)
  }

  async function openVerification(request:VerificationRequest){
    const loadId=++verificationImageLoadId.current
    setSelectedVerification(request)
    setVerificationImageUrl('')
    setVerificationImageReady(false)
    setError('')
    if(request.status!=='pending'||!request.storage_path){
      setVerificationImageLoading(false)
      return
    }
    setVerificationImageLoading(true)
    try{
      const {data,error:signedUrlError}=await supabase!.storage
        .from('identity-documents')
        .createSignedUrl(request.storage_path,60)
      if(loadId!==verificationImageLoadId.current)return
      if(signedUrlError){
        setError(signedUrlError.message)
        return
      }
      setVerificationImageUrl(data.signedUrl)
    }catch(error){
      if(loadId!==verificationImageLoadId.current)return
      setError(error instanceof Error?error.message:'Unable to load the private ID image.')
    }finally{
      if(loadId===verificationImageLoadId.current)setVerificationImageLoading(false)
    }
  }

  async function decideVerification(nextStatus:'verified'|'rejected'){
    if(!selectedVerification||selectedVerification.status!=='pending')return
    const decisionLabel=nextStatus==='verified'?'verify this ID':'reject this ID'
    if(!window.confirm(`Are you sure you want to ${decisionLabel} and permanently delete the uploaded image?`))return
    setVerificationBusy(true)
    setError('')
    setNotice('')
    const {data:storagePath,error:decisionError}=await supabase!.rpc('moderate_identity_verification',{
      target_request_id:selectedVerification.request_id,
      next_status:nextStatus,
    })
    if(decisionError){
      setVerificationBusy(false)
      setError(decisionError.message)
      return
    }

    verificationImageLoadId.current++
    setVerificationImageUrl('')
    setVerificationImageReady(false)
    setVerificationImageLoading(false)
    setSelectedVerification({...selectedVerification,status:nextStatus})
    if(typeof storagePath!=='string'||!storagePath){
      setVerificationBusy(false)
      setError('Decision was recorded, but the ID file path was not returned. Refresh to retry cleanup.')
      await refreshVerificationQueue()
      return
    }

    const {error:deleteError}=await supabase!.storage.from('identity-documents').remove([storagePath])
    if(deleteError){
      setVerificationBusy(false)
      setError(`Decision recorded, but ID deletion failed. The verified badge stays hidden until cleanup succeeds. Retry cleanup: ${deleteError.message}`)
      await refreshVerificationQueue()
      return
    }
    const {error:cleanupError}=await supabase!.rpc('finalize_identity_verification_cleanup',{
      target_request_id:selectedVerification.request_id,
    })
    setVerificationBusy(false)
    if(cleanupError){
      setError(`ID image was deleted, but cleanup could not be finalized. Retry cleanup: ${cleanupError.message}`)
      await refreshVerificationQueue()
      return
    }

    setSelectedVerification(null)
    await refreshVerificationQueue()
    setNotice(nextStatus==='verified'
      ?'ID reviewed and deleted. The Verified badge is now active.'
      :'ID review declined and the image was deleted.')
  }

  async function retryVerificationCleanup(request:VerificationRequest){
    if(!request.storage_path)return
    setVerificationBusy(true)
    setError('')
    const {error:deleteError}=await supabase!.storage.from('identity-documents').remove([request.storage_path])
    if(deleteError){
      setVerificationBusy(false)
      setError(`Unable to delete the ID image. Retry cleanup: ${deleteError.message}`)
      return
    }
    const {error:cleanupError}=await supabase!.rpc('finalize_identity_verification_cleanup',{
      target_request_id:request.request_id,
    })
    setVerificationBusy(false)
    if(cleanupError){
      setError(`ID image was deleted, but cleanup could not be finalized: ${cleanupError.message}`)
      return
    }
    setSelectedVerification(null)
    await refreshVerificationQueue()
    setNotice('ID image deleted and cleanup finalized.')
  }

  function chooseTab(tab:DashboardTab){
    setActiveTab(tab)
    setError('')
    if(tab!=='verification'){
      verificationImageLoadId.current++
      setSelectedVerification(null)
      setVerificationImageUrl('')
      setVerificationImageReady(false)
      setVerificationImageLoading(false)
    }
  }

  const selectedFeaturedPlaceMapUrl=selectedFeaturedPlace
    ?getOpenStreetMapUrl(selectedFeaturedPlace.osm_type,selectedFeaturedPlace.osm_id)
    :null

  return <section className="admin-dashboard" aria-labelledby="admin-title">
    <div className="admin-heading">
      <div>
        <p className="admin-eyebrow">{role==='admin'?'Administrator':'Moderator'} workspace</p>
        <h1 id="admin-title">HangOut operations</h1>
      </div>
      <button type="button" className="secondary" onClick={()=>void refreshCurrentTab()} disabled={loading}>Refresh</button>
    </div>

    <nav className="admin-tabs" aria-label="Admin sections">
      {role==='admin'&&<>
        <button type="button" aria-pressed={activeTab==='overview'} onClick={()=>chooseTab('overview')}>Overview</button>
        <button type="button" aria-pressed={activeTab==='users'} onClick={()=>chooseTab('users')}>Users</button>
        <button type="button" aria-pressed={activeTab==='featured'} onClick={()=>chooseTab('featured')}>Featured hangout</button>
      </>}
      <button type="button" aria-pressed={activeTab==='reports'} onClick={()=>chooseTab('reports')}>Reports</button>
      <button type="button" aria-pressed={activeTab==='verification'} onClick={()=>chooseTab('verification')}>ID verification</button>
    </nav>

    {error&&<p className="status" role="alert">{error}</p>}
    {notice&&<p className="admin-success" role="status">{notice}</p>}
    {loading&&<p className="admin-loading" role="status">Loading dashboard…</p>}

    {!loading&&activeTab==='overview'&&role==='admin'&&<section aria-labelledby="stats-heading">
      <h2 id="stats-heading">Service overview</h2>
      {!stats?<p>No statistics are available.</p>:<div className="admin-stat-grid">
        <article className="admin-stat"><span>All users</span><strong>{stats.total_users.toLocaleString()}</strong></article>
        <article className="admin-stat"><span>Enabled accounts</span><strong>{stats.enabled_users.toLocaleString()}</strong></article>
        <article className="admin-stat"><span>New users · 30 days</span><strong>{stats.new_users_30d.toLocaleString()}</strong></article>
        <article className="admin-stat"><span>Matches · 30 days</span><strong>{stats.matches_30d.toLocaleString()}</strong></article>
        <article className="admin-stat"><span>Open reports</span><strong>{stats.pending_reports.toLocaleString()}</strong></article>
      </div>}
      <p className="fine">Metrics are aggregate counts. “Enabled” means the account has not been deactivated; it does not indicate recent activity.</p>
    </section>}

    {!loading&&activeTab==='featured'&&role==='admin'&&<section className="admin-featured" aria-labelledby="featured-admin-heading">
      <h2 id="featured-admin-heading">Featured hangout promo</h2>
      <p>Configure the single Discover feature shown between Popular and Trending hangouts. Only administrators can edit it.</p>
      <form className="admin-featured-form" onSubmit={event=>void saveFeaturedHangout(event)}>
        <div className="admin-featured-place-search">
          <label htmlFor="featured-place-search">Find the actual place
            <input
              id="featured-place-search"
              type="search"
              value={featuredPlaceSearch}
              onChange={event=>{
                const value=event.target.value
                setFeaturedPlaceSearch(value)
                setFeaturedPlaceResults([])
                setFeaturedPlaceError('')
                if(value!==selectedFeaturedPlace?.name){
                  setSelectedFeaturedPlace(null)
                  setFeaturedDraft(current=>({...current,place_id:'',osm_type:'',osm_id:''}))
                }
              }}
              onKeyDown={event=>{
                if(event.key==='Enter'){
                  event.preventDefault()
                  void searchFeaturedPlaces()
                }
              }}
              maxLength={100}
              aria-describedby="featured-place-help"
            />
          </label>
          <button type="button" className="secondary" disabled={featuredPlaceLoading} onClick={()=>void searchFeaturedPlaces()}>
            {featuredPlaceLoading?'Searching…':'Search places'}
          </button>
          <span className="fine" id="featured-place-help">Choose a catalog place to enable pinning and its OpenStreetMap link.</span>
          {featuredPlaceError&&<p className="hangout-ranking-error" role="alert">{featuredPlaceError}</p>}
          {featuredPlaceResults.length>0&&<ul className="admin-featured-place-results" aria-label="Place search results">
            {featuredPlaceResults.map(place=><li key={place.id}>
              <button type="button" onClick={()=>chooseFeaturedPlace(place)}>
                <strong>{place.name}</strong>
                <small>{place.display_name}</small>
              </button>
            </li>)}
          </ul>}
          {selectedFeaturedPlace&&<p className="admin-featured-place-selected" role="status">
            Selected: <strong>{selectedFeaturedPlace.name}</strong>
            {selectedFeaturedPlaceMapUrl&&<> · <a href={selectedFeaturedPlaceMapUrl} target="_blank" rel="noopener noreferrer">View map</a></>}
          </p>}
        </div>
        <label htmlFor="featured-venue">Hangout name
          <input
            id="featured-venue"
            value={featuredDraft.venue_name}
            onChange={event=>setFeaturedDraft(current=>({...current,venue_name:event.target.value}))}
            maxLength={120}
            required
          />
        </label>
        <label htmlFor="featured-promo-title">Promo package title
          <input
            id="featured-promo-title"
            value={featuredDraft.promo_title}
            onChange={event=>setFeaturedDraft(current=>({...current,promo_title:event.target.value}))}
            maxLength={120}
            required
          />
        </label>
        <label htmlFor="featured-promo-description">Description
          <textarea
            id="featured-promo-description"
            value={featuredDraft.promo_description}
            onChange={event=>setFeaturedDraft(current=>({...current,promo_description:event.target.value}))}
            maxLength={500}
            required
          />
        </label>
        <label htmlFor="featured-promo-terms">Terms and disclosure
          <textarea
            id="featured-promo-terms"
            value={featuredDraft.promo_terms}
            onChange={event=>setFeaturedDraft(current=>({...current,promo_terms:event.target.value}))}
            maxLength={1000}
            required
          />
        </label>
        <label htmlFor="featured-photo-url">Photo URL (optional HTTPS)
          <input
            id="featured-photo-url"
            type="url"
            inputMode="url"
            value={featuredDraft.photo_url||''}
            onChange={event=>setFeaturedDraft(current=>({...current,photo_url:event.target.value||null}))}
            maxLength={2048}
            placeholder="https://example.com/venue-photo.jpg"
          />
          <span className="fine">A photo placeholder appears until an image URL is added.</span>
        </label>
        <div className="admin-featured-cta-fields">
          <label htmlFor="featured-cta-label">Call-to-action label (optional)
            <input
              id="featured-cta-label"
              value={featuredDraft.promo_cta_label||''}
              onChange={event=>setFeaturedDraft(current=>({...current,promo_cta_label:event.target.value||null}))}
              maxLength={60}
            />
          </label>
          <label htmlFor="featured-cta-url">Call-to-action URL (optional HTTPS)
            <input
              id="featured-cta-url"
              type="url"
              inputMode="url"
              value={featuredDraft.promo_cta_url||''}
              onChange={event=>setFeaturedDraft(current=>({...current,promo_cta_url:event.target.value||null}))}
              maxLength={2048}
              placeholder="https://example.com/offer"
            />
          </label>
        </div>
        <label className="admin-featured-check">
          <input
            type="checkbox"
            checked={featuredDraft.demo_only}
            aria-describedby="featured-demo-help"
            onChange={event=>setFeaturedDraft(current=>({...current,demo_only:event.target.checked}))}
          />
          Mark as a sample only (not real or redeemable)
        </label>
        {featuredDraft.demo_only&&<p className="fine" id="featured-demo-help">The Discover card will show a prominent sample-only disclaimer while this is checked.</p>}
        <label className="admin-featured-check">
          <input
            type="checkbox"
            checked={featuredDraft.is_published}
            onChange={event=>setFeaturedDraft(current=>({...current,is_published:event.target.checked}))}
          />
          Publish on Discover
        </label>
        <div className="admin-actions">
          <button type="submit" className="primary" disabled={featuredBusy||!featuredDraft.place_id}>
            {featuredBusy?'Saving…':'Save featured hangout'}
          </button>
        </div>
      </form>
      {featuredDraft.venue_name.trim()&&featuredDraft.promo_title.trim()&&<section className="admin-featured-preview" aria-labelledby="featured-preview-heading">
        <h3 id="featured-preview-heading">Discover preview</h3>
        <FeaturedHangoutCard hangout={{
          ...featuredDraft,
          photo_url:getOptionalHttpsUrl(featuredDraft.photo_url)||null,
          promo_cta_url:getOptionalHttpsUrl(featuredDraft.promo_cta_url)||null,
        }} preview/>
      </section>}
    </section>}

    {!loading&&activeTab==='users'&&role==='admin'&&<section aria-labelledby="users-heading">
      <h2 id="users-heading">User management</h2>
      <form className="admin-search" onSubmit={searchUsers}>
        <label htmlFor="admin-user-search">Search by name or email
          <input id="admin-user-search" type="search" value={searchText} onChange={event=>setSearchText(event.target.value)} maxLength={100} placeholder="Name or email address"/>
        </label>
        <button type="submit" className="primary" disabled={usersLoading}>Search</button>
      </form>
      {usersLoading?<p role="status">Searching users…</p>:users.length===0?<p>No users match that search.</p>:
        <ul className="admin-user-list">{users.map(user=><li key={user.id} className="admin-user-card">
          <div className="admin-user-info">
            <h3>{user.first_name}</h3>
            <p>{user.email||'No email available'}</p>
            <p className="fine">Joined {formatDate(user.created_at)} · {user.reports_received} report{user.reports_received===1?'':'s'}</p>
          </div>
          <div className="admin-user-actions">
            <span className={user.account_active?'admin-state-active':'admin-state-inactive'}>{user.account_active?'Enabled':'Deactivated'}</span>
            <button type="button" className="secondary" onClick={()=>{setSelectedUser(user);setStatusReason('')}}>
              {user.account_active?'Deactivate':'Reactivate'}
            </button>
          </div>
        </li>)}</ul>}
      <div className="admin-pagination">
        <button type="button" className="secondary" disabled={userOffset===0||usersLoading} onClick={()=>setUserOffset(Math.max(0,userOffset-pageSize))}>Previous</button>
        <span>Showing {users.length?userOffset+1:0}–{userOffset+users.length}</span>
        <button type="button" className="secondary" disabled={!hasNextPage||usersLoading} onClick={()=>setUserOffset(userOffset+pageSize)}>Next</button>
      </div>
      {selectedUser&&<form className="admin-status-form" onSubmit={updateAccountStatus}>
        <h3>{selectedUser.account_active?'Deactivate':'Reactivate'} {selectedUser.first_name}?</h3>
        <p>{selectedUser.account_active
          ?'Deactivation blocks access to HangOut while retaining the account and safety records. This can be reversed later.'
          :'Reactivation restores access to HangOut.'}</p>
        <h4>Account status history</h4>
        {statusHistory.length===0?<p>No status changes recorded.</p>:<ol className="admin-action-history">{statusHistory.map((event,index)=><li key={`${event.created_at}-${index}`}>
          <strong>{event.account_active?'Reactivated':'Deactivated'}</strong><span>{formatDate(event.created_at)}</span>
          <p>{event.reason}</p>
        </li>)}</ol>}
        <label htmlFor="account-status-reason">Reason (required)
          <textarea id="account-status-reason" value={statusReason} onChange={event=>setStatusReason(event.target.value)} minLength={3} maxLength={500} required/>
        </label>
        <div className="admin-actions">
          <button type="button" className="secondary" disabled={statusBusy} onClick={()=>setSelectedUser(null)}>Cancel</button>
          <button type="submit" className={selectedUser.account_active?'danger-button':'primary'} disabled={statusBusy||statusReason.trim().length<3}>
            {statusBusy?'Saving…':selectedUser.account_active?'Confirm deactivation':'Confirm reactivation'}
          </button>
        </div>
      </form>}
    </section>}

    {!loading&&activeTab==='reports'&&<section className="admin-reports" aria-labelledby="reports-heading">
      <div className="admin-section-heading">
        <h2 id="reports-heading">Report queue</h2>
        <label htmlFor="report-status-filter">Status
          <select id="report-status-filter" value={reportFilter} onChange={event=>{setReportFilter(event.target.value);setSelectedReport(null)}}>
            <option value="">All statuses</option>
            {Object.entries(statusLabels).map(([value,label])=><option key={value} value={value}>{label}</option>)}
          </select>
        </label>
      </div>
      {reports.length===0?<p>No reports in this queue.</p>:<ul className="admin-report-list">
        {reports.map(report=><li key={report.id}>
          <button type="button" className={selectedReport?.id===report.id?'selected':''} onClick={()=>void openReport(report)}>
            <span><strong>{report.reason.replaceAll('_',' ')}</strong><small>{report.reported_name} · reported by {report.reporter_name}</small></span>
            <span className={`report-status report-status-${report.status}`}>{statusLabels[report.status]}</span>
            <time dateTime={report.created_at}>{formatDate(report.created_at)}</time>
          </button>
        </li>)}
      </ul>}

      {selectedReport&&<article className="admin-report-detail" aria-labelledby="report-detail-title">
        <h3 id="report-detail-title">Report details</h3>
        <p><strong>{selectedReport.reported_name}</strong> reported by {selectedReport.reporter_name} · {formatDate(selectedReport.created_at)}</p>
        <p><strong>Category:</strong> {selectedReport.reason.replaceAll('_',' ')}</p>
        <p className="admin-report-text">{selectedReport.details||'No additional details provided.'}</p>
        {detailLoading?<p role="status">Loading evidence and history…</p>:<>
          <h4>Profile snapshot</h4>
          <pre className="admin-evidence">{JSON.stringify(evidence?.reported_profile_snapshot||{},null,2)}</pre>
          <h4>Conversation evidence ({evidence?.message_snapshot.length||0} messages)</h4>
          {!evidence?.message_snapshot.length?<p>No message evidence attached.</p>:
            <ol className="admin-message-evidence">{evidence.message_snapshot.map(message=><li key={message.id}>
              <span>{formatDate(message.created_at)}</span><p>{message.body}</p>
            </li>)}</ol>}
          <h4>Action history</h4>
          {actions.length===0?<p>No actions recorded.</p>:<ol className="admin-action-history">{actions.map(action=><li key={action.id}>
            <strong>{action.action.replaceAll('_',' ')}</strong><span>{formatDate(action.created_at)}</span>
            {action.note&&<p>{action.note}</p>}
          </li>)}</ol>}
        </>}
        <label htmlFor="moderation-note">Internal note (optional)
          <textarea id="moderation-note" value={reportNote} onChange={event=>setReportNote(event.target.value)} maxLength={2000}/>
        </label>
        <div className="admin-actions">
          <button type="button" className="secondary" disabled={reportBusy} onClick={()=>void updateReportStatus('reviewing')}>Mark reviewing</button>
          <button type="button" className="secondary" disabled={reportBusy} onClick={()=>void updateReportStatus('resolved')}>Resolve</button>
          <button type="button" className="danger-button" disabled={reportBusy} onClick={()=>void updateReportStatus('dismissed')}>Dismiss</button>
        </div>
        {reportBusy&&<p role="status">Saving report action…</p>}
      </article>}
    </section>}

    {!loading&&activeTab==='verification'&&<section className="admin-verifications" aria-labelledby="verification-heading">
      <h2 id="verification-heading">ID verification queue</h2>
      <p className="fine">Government-issued photo IDs are sensitive. Review only for this request; do not download or share copies. A Verified badge means an ID was manually reviewed, not that a background or safety check was performed.</p>
      {verificationRequests.length===0?<p>No ID reviews or cleanup tasks are waiting.</p>:<ul className="verification-list">
        {verificationRequests.map(request=>{
          const cleanupNeeded=request.status!=='pending'&&Boolean(request.storage_path)
          return <li key={request.request_id}>
            <button
              type="button"
              className={selectedVerification?.request_id===request.request_id?'selected':''}
              onClick={()=>void openVerification(request)}
            >
              <span><strong>{request.first_name}</strong><small>Submitted {request.submitted_at?formatDate(request.submitted_at):'upload incomplete'}</small></span>
              <span className={`report-status ${cleanupNeeded?'report-status-open':'report-status-reviewing'}`}>
                {cleanupNeeded?'Delete ID image':'Pending review'}
              </span>
            </button>
          </li>
        })}
      </ul>}
      {selectedVerification&&<article className="verification-detail" aria-labelledby="verification-detail-title">
        <h3 id="verification-detail-title">ID review for {selectedVerification.first_name}</h3>
        <p>Review the government-issued photo ID only to decide this request. The public badge does not imply a background check.</p>
        {selectedVerification.status==='pending'&&<>
          {verificationImageLoading?<p role="status">Loading private ID image…</p>:
            verificationImageUrl
              ?<>
                <img
                  className="verification-image"
                  src={verificationImageUrl}
                  alt={`Private ID image submitted by ${selectedVerification.first_name}`}
                  onLoad={()=>setVerificationImageReady(true)}
                  onError={()=>{
                    setVerificationImageReady(false)
                    setVerificationImageUrl('')
                    setError('Unable to display the private ID image. Reload it to try again.')
                  }}
                />
                <button type="button" className="secondary" onClick={()=>void openVerification(selectedVerification)}>Reload private ID image</button>
              </>
              :<button type="button" className="secondary" onClick={()=>void openVerification(selectedVerification)}>Load ID image</button>}
          <div className="admin-actions">
            <button type="button" className="primary" disabled={verificationBusy||verificationImageLoading||!verificationImageReady} onClick={()=>void decideVerification('verified')}>Verify ID and delete image</button>
            <button type="button" className="danger-button" disabled={verificationBusy||verificationImageLoading||!verificationImageReady} onClick={()=>void decideVerification('rejected')}>Reject and delete image</button>
          </div>
        </>}
        {selectedVerification.storage_path&&selectedVerification.status!=='pending'&&<div className="admin-actions">
          <p role="status">The decision is saved, but the ID image still needs deletion. The Verified badge remains hidden until cleanup completes.</p>
          <button type="button" className="danger-button" disabled={verificationBusy} onClick={()=>void retryVerificationCleanup(selectedVerification)}>
            {verificationBusy?'Deleting…':'Retry ID deletion'}
          </button>
        </div>}
      </article>}
    </section>}
  </section>
}
