import {useEffect,useState} from 'react'
import type {Session} from '@supabase/supabase-js'
import {configured,supabase} from './lib/supabase'
import {Auth,CompleteSocialSignup,PasswordRecovery} from './components/Auth'
import {MarketingHome} from './components/MarketingHome'
import {ProfileEditor} from './components/ProfileEditor'
import {Places} from './components/Places'
import {Discovery} from './components/Discovery'
import {MatchesChat} from './components/MatchesChat'
import {Meetup} from './components/Meetup'
import {AdminDashboard} from './components/AdminDashboard'
type AdminRole='admin'|'moderator'
type AccountAccess='loading'|'active'|'inactive'|'error'
function getAuthModeFromLocation(): 'signup'|'login'|null {
  const hashMode=location.hash==='#login'?'login':location.hash==='#signup'?'signup':null
  if(hashMode)return hashMode
  const queryMode=new URLSearchParams(location.search).get('authMode')
  return queryMode==='login'||queryMode==='signup'?queryMode:null
}
function Setup({onBack}:{onBack:()=>void}){return <main className="shell"><section className="panel setup"><button className="secondary" onClick={onBack}>Back to HangOut</button><h1>Connect HangOut to Supabase</h1><ol><li>Create a Supabase project.</li><li>Run both SQL files in <code>supabase/migrations</code>, in numeric order.</li><li>Copy <code>.env.example</code> to <code>.env.local</code> and add the project URL and publishable key.</li><li>Restart <code>npm run dev</code>.</li></ol></section></main>}
const appTabs=[
  {id:'discover',label:'Discover',path:<><circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2.2 4.8-4.8 2.2 2.2-4.8 4.8-2.2Z"/></>},
  {id:'matches',label:'Matches',path:<><path d="M20 11.5a7.5 7.5 0 0 1-7.5 7.5H7l-4 2v-5.5A7.5 7.5 0 1 1 20 11.5Z"/><path d="M8 8h.01M12 8h.01M16 8h.01"/></>},
  {id:'meetups',label:'Meetups',path:<><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01"/></>},
  {id:'profile',label:'Profile',path:<><circle cx="12" cy="8" r="4"/><path d="M5 21v-1a7 7 0 0 1 14 0v1Z"/></>},
] as const
export default function App(){
  const [session,setSession]=useState<Session|null>(null)
  const [ready,setReady]=useState(false)
  const [passwordRecovery,setPasswordRecovery]=useState(false)
  const [authMode,setAuthMode]=useState<'signup'|'login'|null>(getAuthModeFromLocation)
  const [tab,setTab]=useState<'discover'|'matches'|'meetups'|'profile'>('discover')
  const [refresh,setRefresh]=useState(0)
  const [profileComplete,setProfileComplete]=useState(false)
  const [profileCheckLoading,setProfileCheckLoading]=useState(false)
  const [profileCheckError,setProfileCheckError]=useState('')
  const [profileCheckAttempt,setProfileCheckAttempt]=useState(0)
  const [accountAccess,setAccountAccess]=useState<AccountAccess>('loading')
  const [accountAccessError,setAccountAccessError]=useState('')
  const [accountAccessAttempt,setAccountAccessAttempt]=useState(0)
  const [adminRole,setAdminRole]=useState<AdminRole|null>(null)
  const [adminRoleError,setAdminRoleError]=useState('')
  const [adminOpen,setAdminOpen]=useState(false)
  const [headerProfile,setHeaderProfile]=useState<{userId:string;firstName:string;photoUrl:string|null}|null>(null)
  const metadataFirstName=typeof session?.user.user_metadata.first_name==='string'
    ?session.user.user_metadata.first_name.trim()
    :''
  const displayedHeaderProfile=headerProfile?.userId===session?.user.id?headerProfile:null
  const displayName=displayedHeaderProfile?.firstName||metadataFirstName||'there'

  useEffect(()=>{
    const onHashChange=()=>setAuthMode(getAuthModeFromLocation())
    window.addEventListener('hashchange',onHashChange)
    return()=>window.removeEventListener('hashchange',onHashChange)
  },[])

  useEffect(()=>{
    if(!supabase){setReady(true);return}
    supabase.auth.getSession().then(({data})=>{setSession(data.session);setReady(true)})
    const {data}=supabase.auth.onAuthStateChange((event,s)=>{
      setSession(s)
      if(event==='PASSWORD_RECOVERY')setPasswordRecovery(true)
    })
    return()=>data.subscription.unsubscribe()
  },[])

  useEffect(()=>{
    if(!session||passwordRecovery){
      setAccountAccess('active')
      setAdminRole(null)
      setAdminRoleError('')
      setAdminOpen(false)
      return
    }
    let cancelled=false
    setAccountAccess('loading')
    setAccountAccessError('')
    setAdminRole(null)
    setAdminRoleError('')
    async function checkAccountAccess(){
      const {data:profile,error:profileError}=await supabase!.from('profiles')
        .select('account_active')
        .eq('id',session!.user.id)
        .maybeSingle()
      if(cancelled)return
      if((profileError?.code==='42703'||profileError?.code==='PGRST204')&&profileError.message.includes('account_active')){
        setAccountAccess('active')
        setAdminRoleError('Admin and account-status controls are unavailable until migrations 008 and 015 are applied. The regular app remains available.')
        return
      }
      if(profileError||!profile){
        setAccountAccess('error')
        setAccountAccessError(profileError?.message||'Your account status could not be verified.')
        return
      }
      if(!profile.account_active){
        setAccountAccess('inactive')
        return
      }
      setAccountAccess('active')
      const {data:roleData,error:roleError}=await supabase!.from('moderator_roles')
        .select('role')
        .eq('user_id',session!.user.id)
        .maybeSingle()
      if(cancelled)return
      if(roleError){
        setAdminRoleError(roleError.message)
      }else if(roleData?.role==='admin'||roleData?.role==='moderator'){
        setAdminRole(roleData.role)
      }
    }
    void checkAccountAccess()
    return()=>{cancelled=true}
  },[session?.user.id,accountAccessAttempt,passwordRecovery])

  useEffect(()=>{
    if(!session||passwordRecovery||tab!=='discover')return
    let cancelled=false
    const metadataName=typeof session.user.user_metadata.first_name==='string'
      ?session.user.user_metadata.first_name.trim()
      :''
    setHeaderProfile({userId:session.user.id,firstName:metadataName,photoUrl:null})
    setProfileCheckLoading(true)
    setProfileCheckError('')
    supabase!.from('profiles').select('first_name,birth_date,photo_url,hangout_personality').eq('id',session.user.id).maybeSingle().then(({data,error})=>{
      if(cancelled)return
      if(error){
        setProfileCheckError(error.message)
      }else{
        setHeaderProfile({
          userId:session.user.id,
          firstName:data?.first_name?.trim()||metadataName,
          photoUrl:data?.photo_url||null,
        })
        setProfileComplete(Boolean(data?.first_name?.trim()&&data.birth_date&&data.photo_url&&data.hangout_personality?.length>=3&&data.hangout_personality?.length<=5))
      }
      setProfileCheckLoading(false)
    })
    return()=>{cancelled=true}
  },[session?.user.id,tab,profileCheckAttempt,passwordRecovery])

  if(!ready)return <div className="loading">Loading HangOut…</div>
  if(passwordRecovery)return <PasswordRecovery onContinue={()=>{
    const callbackUrl=new URL(window.location.href)
    callbackUrl.search=''
    callbackUrl.hash=''
    window.history.replaceState(window.history.state,'',callbackUrl)
    setPasswordRecovery(false)
  }}/>
  if(!session){
    if(!authMode)return <MarketingHome/>
    if(!configured)return <Setup onBack={()=>{location.hash='#home'}}/>
    return <Auth initialMode={authMode}/>
  }
  if(accountAccess==='loading')return <div className="loading" role="status">Checking account access…</div>
  if(accountAccess==='error')return <main className="shell"><section className="panel" role="alert">
    <h1>Unable to verify your account</h1><p>{accountAccessError}</p>
    <button className="secondary" onClick={()=>setAccountAccessAttempt(value=>value+1)}>Try again</button>
    <button className="secondary" onClick={()=>supabase!.auth.signOut()}>Log out</button>
  </section></main>
  if(accountAccess==='inactive')return <main className="shell"><section className="panel" role="status">
    <h1>Account deactivated</h1><p>This account is temporarily unable to use HangOut. Contact the HangOut team if you believe this is a mistake.</p>
    <button className="secondary" onClick={()=>setAccountAccessAttempt(value=>value+1)}>Check again</button>
    <button className="secondary" onClick={()=>supabase!.auth.signOut()}>Log out</button>
  </section></main>
  const firstName=typeof session.user.user_metadata.first_name==='string'?session.user.user_metadata.first_name.trim():''
  const adultConfirmed=typeof session.user.user_metadata.adult_confirmed_at==='string'
    &&session.user.user_metadata.adult_confirmed_at.trim().length>0
  if(!firstName||!adultConfirmed)return <CompleteSocialSignup
    user={session.user}
    onComplete={()=>setProfileCheckAttempt(value=>value+1)}
  />

  return <>
    <header>
      <div className="bar">
        <span className="brand"><img src="/hangout-logo.png" alt="HangOut"/></span>
        <nav className="app-nav" aria-label="Main navigation">
          {appTabs.map(item=><button key={item.id} type="button" className={tab===item.id?'active':''} aria-label={item.label} aria-current={tab===item.id?'page':undefined} onClick={()=>{setAdminOpen(false);setTab(item.id)}}>
            <svg className="app-nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{item.path}</svg>
            <span className="app-nav-label">{item.label}</span>
          </button>)}
        </nav>
        <div className="header-actions">
          {adminRole&&<button className="secondary admin-toggle" type="button" aria-pressed={adminOpen} onClick={()=>setAdminOpen(value=>!value)}>Admin</button>}
          <div className="account-controls">
            {displayedHeaderProfile?.photoUrl
              ?<img className="account-avatar" src={displayedHeaderProfile.photoUrl} alt=""/>
              :<span className="account-avatar-fallback" aria-hidden="true">{displayName.charAt(0).toUpperCase()}</span>}
            <span className="account-name">Hi, {displayName}</span>
            <button className="logout-button" type="button" onClick={()=>supabase!.auth.signOut()}>Log out</button>
          </div>
        </div>
      </div>
    </header>
    <main className="shell">
      <div className="notice"><strong>Closed beta.</strong> Share only what you are comfortable sharing. Distances and exact live locations are not exposed.</div>
      {adminRoleError&&<section className="panel" role="alert"><h2>Admin access check failed</h2><p>{adminRoleError}</p></section>}
      {adminOpen&&adminRole&&<AdminDashboard role={adminRole}/>}
      {!adminOpen&&<>
      {tab==='discover'&&profileCheckLoading&&<section className="panel" aria-live="polite"><p>Checking your profile…</p></section>}
      {tab==='discover'&&profileCheckError&&<section className="panel" role="alert"><h2>Unable to check your profile</h2><p>{profileCheckError}</p><button className="secondary" onClick={()=>setProfileCheckAttempt(x=>x+1)}>Try again</button></section>}
      {tab==='discover'&&!profileCheckLoading&&!profileCheckError&&!profileComplete&&<section className="panel" aria-labelledby="profile-setup-title">
        <h2 id="profile-setup-title">Complete your profile to get started</h2>
        <p>Add your first name, birth date, profile photo, primary dating intention, and choose 3 to 5 hangout personalities before discovering people. You can also write a short bio and pin places to improve your matches.</p>
        <button className="primary" onClick={()=>setTab('profile')}>Set up your profile</button>
      </section>}
      {tab==='discover'&&!profileCheckLoading&&!profileCheckError&&profileComplete&&<Discovery userId={session.user.id} onMatch={()=>{setRefresh(x=>x+1);setTab('matches')}}/>}
      {tab==='matches'&&<MatchesChat user={session.user} refreshKey={refresh}/>}
      {tab==='meetups'&&<Meetup user={session.user} refreshKey={refresh}/>}
      {tab==='profile'&&<div className="dashboard"><ProfileEditor user={session.user}/><Places user={session.user}/></div>}
      </>}
    </main>
  </>
}
