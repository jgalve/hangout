import {FormEvent,useEffect,useState} from 'react'
import type {User} from '@supabase/supabase-js'
import {LogIn} from 'lucide-react'
import {supabase} from '../lib/supabase'

type AuthMode='signup'|'login'
type SocialProvider='google'|'facebook'

function getCallbackErrorMessage(){
  const query=new URLSearchParams(location.search)
  const hash=new URLSearchParams(location.hash.slice(1))
  const errorCode=query.get('error_code')||hash.get('error_code')
  const description=query.get('error_description')||hash.get('error_description')||''
  if(!query.has('error')&&!query.has('error_description')&&!hash.has('error')&&!hash.has('error_description'))return ''
  if(errorCode==='otp_expired'||description.toLowerCase().includes('email link is invalid')||description.toLowerCase().includes('expired')){
    return 'This password reset link is invalid or has expired. Request a new one.'
  }
  return 'Sign-in was canceled or could not be completed. Try again or use email and password.'
}

function getProviderFirstName(user:User){
  const metadata=user.user_metadata
  for(const key of ['first_name','given_name']){
    const value=metadata[key]
    if(typeof value==='string'&&value.trim())return value.trim().slice(0,50)
  }
  const fullName=metadata.full_name||metadata.name
  if(typeof fullName==='string'&&fullName.trim())return fullName.trim().split(/\s+/)[0].slice(0,50)
  return ''
}

export function Auth({initialMode='signup'}:{initialMode?:AuthMode}){
  const [mode,setMode]=useState<AuthMode>(initialMode)
  const [resetView,setResetView]=useState<'none'|'request'|'sent'>('none')
  const [busy,setBusy]=useState(false)
  const [busyProvider,setBusyProvider]=useState<SocialProvider|null>(null)
  const [msg,setMsg]=useState('')
  const [email,setEmail]=useState('')

  useEffect(()=>setMode(initialMode),[initialMode])

  useEffect(()=>{
    setMsg(getCallbackErrorMessage())
  },[])

  async function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    if(!supabase){
      setMsg('Authentication is not configured.')
      return
    }
    const form=new FormData(event.currentTarget)
    const email=String(form.get('email')||'').trim()
    const password=String(form.get('password')||'')
    const firstName=String(form.get('first')||'').trim()
    const adultConfirmed=form.get('adult')==='on'
    if(mode==='signup'&&(!adultConfirmed||!firstName)){
      setMsg('Enter your first name and confirm you are at least 18.')
      return
    }

    setBusy(true)
    setMsg('')
    try{
      const result=mode==='signup'
        ?await supabase.auth.signUp({email,password,options:{data:{
          first_name:firstName,
          adult_confirmed_at:new Date().toISOString(),
        }}})
        :await supabase.auth.signInWithPassword({email,password})
      setMsg(result.error
        ?result.error.message
        :mode==='signup'?'Check your email to verify your account.':'Signed in.')
    }catch(error){
      setMsg(error instanceof Error?error.message:'Unable to authenticate. Try again.')
    }finally{
      setBusy(false)
    }
  }

  async function requestPasswordReset(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    if(!supabase){
      setMsg('Authentication is not configured.')
      return
    }

    const form=new FormData(event.currentTarget)
    const requestedEmail=String(form.get('email')||'').trim()
    setBusy(true)
    setMsg('')
    try{
      const {error}=await supabase.auth.resetPasswordForEmail(requestedEmail,{
        redirectTo:`${window.location.origin}/?authMode=login`,
      })
      if(error)throw error
      setEmail(requestedEmail)
      setResetView('sent')
    }catch{
      setMsg('We could not send reset instructions. Check the email address and try again later.')
    }finally{
      setBusy(false)
    }
  }

  async function signInWithProvider(provider:SocialProvider){
    if(!supabase){
      setMsg('Authentication is not configured.')
      return
    }
    setBusy(true)
    setBusyProvider(provider)
    setMsg('')
    const redirectUrl=new URL(window.location.href)
    redirectUrl.search=''
    redirectUrl.hash=''
    redirectUrl.searchParams.set('authMode',mode)
    try{
      const {error}=await supabase.auth.signInWithOAuth({
        provider,
        options:{redirectTo:redirectUrl.toString()},
      })
      if(error)throw error
    }catch(error){
      setMsg(error instanceof Error?error.message:'Unable to start social sign-in. Try again.')
      setBusy(false)
      setBusyProvider(null)
    }
  }

  function changeMode(nextMode:AuthMode){
    setMode(nextMode)
    setResetView('none')
    setMsg('')
    location.hash=`#${nextMode}`
  }

  return <main className="shell auth">
    <section>
      <a className="brand" href="#home" aria-label="HangOut home"><img src="/hangout-logo.png" alt=""/></a>
      <h1>Meet through the places you already love.</h1>
      <p className="lede">Choose your favorite places and discover people who share them.</p>
      <button className="secondary" onClick={()=>{location.hash='#home'}}>Back to home</button>
    </section>
    <section className="panel">
      {resetView==='none'&&<>
        <div className="tabs">
          <button type="button" className={mode==='signup'?'active':''} onClick={()=>changeMode('signup')} disabled={busy}>Sign up</button>
          <button type="button" className={mode==='login'?'active':''} onClick={()=>changeMode('login')} disabled={busy}>Log in</button>
        </div>
        <form onSubmit={submit}>
          {mode==='signup'&&<label>First name<input name="first" autoComplete="given-name" maxLength={50} required/></label>}
          <label>Email<input name="email" type="email" autoComplete="email" value={email} onChange={event=>setEmail(event.target.value)} required/></label>
          <label>Password<input name="password" type="password" minLength={8} autoComplete={mode==='signup'?'new-password':'current-password'} required/></label>
          {mode==='login'&&<button type="button" className="auth-link" onClick={()=>{setResetView('request');setMsg('')}} disabled={busy}>Forgot your password?</button>}
          {mode==='signup'&&<label className="check"><input name="adult" type="checkbox"/> <span>I confirm I am at least 18 and accept the Terms, <a href="/privacy-policy.html" target="_blank" rel="noreferrer">Privacy Policy</a> and Community Guidelines.</span></label>}
          <button className="primary" disabled={busy}>{busy&&!busyProvider?'Please wait…':mode==='signup'?'Create account':'Log in'}</button>
          <p className="status" role="status">{msg}</p>
        </form>
        <div className="auth-divider"><span>or continue with</span></div>
        <div className="oauth-buttons">
          <button type="button" className="secondary" onClick={()=>void signInWithProvider('google')} disabled={busy}>
            <span className="oauth-icon oauth-icon-google" aria-hidden="true">G</span>
            <LogIn className="social-action-icon" size={18} aria-hidden="true"/>
            <span>{busyProvider==='google'?'Connecting to Google…':'Continue with Google'}</span>
          </button>
          <button type="button" className="secondary" onClick={()=>void signInWithProvider('facebook')} disabled={busy}>
            <span className="oauth-icon oauth-icon-facebook" aria-hidden="true">f</span>
            <LogIn className="social-action-icon" size={18} aria-hidden="true"/>
            <span>{busyProvider==='facebook'?'Connecting to Facebook…':'Continue with Facebook'}</span>
          </button>
        </div>
        <p className="fine oauth-note">New social accounts must complete the 18+ confirmation before using HangOut.</p>
      </>}
      {resetView==='request'&&<>
        <h2>Reset your password</h2>
        <p>Enter the email address for your account and we will send a reset link if it is registered.</p>
        <form onSubmit={requestPasswordReset}>
          <label>Email<input name="email" type="email" autoComplete="email" value={email} onChange={event=>setEmail(event.target.value)} required/></label>
          <button className="primary" disabled={busy}>{busy?'Sending…':'Send reset link'}</button>
          <button type="button" className="auth-link" onClick={()=>changeMode('login')} disabled={busy}>Back to log in</button>
          <p className="status" role="status">{msg}</p>
        </form>
      </>}
      {resetView==='sent'&&<>
        <h2>Check your email</h2>
        <p className="status status-success" role="status">If an account exists for {email}, reset instructions will arrive shortly.</p>
        <button type="button" className="primary" onClick={()=>setResetView('request')}>Send another reset link</button>
        <button type="button" className="auth-link" onClick={()=>changeMode('login')}>Back to log in</button>
      </>}
    </section>
  </main>
}

export function PasswordRecovery({onContinue}:{onContinue:()=>void}){
  const [password,setPassword]=useState('')
  const [confirmation,setConfirmation]=useState('')
  const [busy,setBusy]=useState(false)
  const [updated,setUpdated]=useState(false)
  const [msg,setMsg]=useState('')

  async function updatePassword(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    if(password.length<8){
      setMsg('Your password must be at least 8 characters.')
      return
    }
    if(password!==confirmation){
      setMsg('The passwords do not match.')
      return
    }
    if(!supabase){
      setMsg('Authentication is not configured.')
      return
    }

    setBusy(true)
    setMsg('')
    try{
      const {error}=await supabase.auth.updateUser({password})
      if(error)throw error
      setUpdated(true)
    }catch(error){
      setMsg(error instanceof Error?error.message:'Unable to update your password. Request a new reset link and try again.')
    }finally{
      setBusy(false)
    }
  }

  return <main className="shell auth">
    <section>
      <a className="brand" href="#home" aria-label="HangOut home"><img src="/hangout-logo.png" alt=""/></a>
      <h1>Meet through the places you already love.</h1>
      <p className="lede">Choose a new password to get back to HangOut.</p>
    </section>
    <section className="panel auth-completion">
      {updated?<>
        <h2>Password updated</h2>
        <p className="status status-success" role="status">Your password has been changed.</p>
        <button type="button" className="primary" onClick={onContinue}>Continue to HangOut</button>
      </>:<>
        <h2>Choose a new password</h2>
        <form onSubmit={updatePassword}>
          <label>New password<input type="password" autoComplete="new-password" minLength={8} value={password} onChange={event=>setPassword(event.target.value)} required/></label>
          <label>Confirm new password<input type="password" autoComplete="new-password" minLength={8} value={confirmation} onChange={event=>setConfirmation(event.target.value)} required/></label>
          <button className="primary" disabled={busy}>{busy?'Saving…':'Update password'}</button>
          <p className="status" role="status">{msg}</p>
        </form>
      </>}
    </section>
  </main>
}

export function CompleteSocialSignup({user,onComplete}:{user:User;onComplete:()=>void}){
  const [firstName,setFirstName]=useState(()=>getProviderFirstName(user))
  const [adultConfirmed,setAdultConfirmed]=useState(false)
  const [busy,setBusy]=useState(false)
  const [msg,setMsg]=useState('')

  async function complete(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    const normalizedName=firstName.trim()
    if(!normalizedName||!adultConfirmed){
      setMsg('Enter your first name and confirm you are at least 18.')
      return
    }
    if(!supabase){
      setMsg('Authentication is not configured.')
      return
    }

    setBusy(true)
    setMsg('')
    try{
      const {data:profile,error:profileError}=await supabase.from('profiles')
        .update({first_name:normalizedName})
        .eq('id',user.id)
        .select('id')
        .maybeSingle()
      if(profileError)throw profileError
      if(!profile)throw new Error('Your profile is not ready yet. Try again in a moment.')

      const {error:userError}=await supabase.auth.updateUser({
        data:{
          first_name:normalizedName,
          adult_confirmed_at:new Date().toISOString(),
        },
      })
      if(userError)throw userError
      onComplete()
    }catch(error){
      setMsg(error instanceof Error?error.message:'Unable to finish account setup. Try again.')
    }finally{
      setBusy(false)
    }
  }

  async function signOut(){
    if(!supabase)return
    setBusy(true)
    setMsg('')
    const {error}=await supabase.auth.signOut()
    setBusy(false)
    if(error)setMsg(error.message)
  }

  return <main className="shell auth">
    <section>
      <a className="brand" href="#home" aria-label="HangOut home"><img src="/hangout-logo.png" alt=""/></a>
      <h1>Meet through the places you already love.</h1>
      <p className="lede">A quick account setup before you get started.</p>
    </section>
    <section className="panel auth-completion">
      <h2>Finish setting up your account</h2>
      <p>Tell us what to call you and confirm you meet HangOut’s age requirement.</p>
      <form onSubmit={complete}>
        <label>First name<input value={firstName} onChange={event=>setFirstName(event.target.value)} autoComplete="given-name" maxLength={50} required/></label>
        <label className="check">
          <input type="checkbox" checked={adultConfirmed} onChange={event=>setAdultConfirmed(event.target.checked)} required/>
          <span>I confirm I am at least 18 and accept the Terms, Privacy Policy and Community Guidelines.</span>
        </label>
        <button className="primary" disabled={busy}>{busy?'Saving…':'Continue to HangOut'}</button>
      </form>
      <button type="button" className="secondary" onClick={()=>void signOut()} disabled={busy}>Log out</button>
      <p className="status" role="status">{msg}</p>
    </section>
  </main>
}
