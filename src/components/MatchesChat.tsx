import {FormEvent,useEffect,useRef,useState} from 'react'
import type {User} from '@supabase/supabase-js'
import {supabase} from '../lib/supabase'
import {ProfileDialog} from './ProfileDialog'
import {ReportDialog} from './ReportDialog'
import type {ViewableProfile} from './ProfileDialog'

type Match={id:string;other_user_id:string;other_first_name:string;other_photo_url:string|null;shared_place_id:string|null;shared_place_name:string|null;unread_count:number}
type MatchSocialLinks={facebook_url:string|null;instagram_url:string|null;tiktok_url:string|null}
type Message={id:number;match_id:string;sender_id:string;body:string;created_at:string}

function MatchAvatar({url,name,size}:{url:string|null;name:string;size:'list'|'header'}){
  const [imageError,setImageError]=useState(false)
  useEffect(()=>setImageError(false),[url])
  return <span className={`match-avatar match-avatar-${size}`} aria-hidden="true">
    {url&&!imageError?<img src={url} alt="" onError={()=>setImageError(true)}/>:name.trim().charAt(0).toUpperCase()}
  </span>
}

const openingLineOptions=[
  'What do you like doing when you have a free afternoon?',
  'What is your ideal low-key hangout?',
  'What is something you have been excited about lately?',
  'Coffee, a walk, or trying somewhere new—which sounds best?',
  'What song have you had on repeat lately?',
  'What is a place around town you would recommend to a friend?',
  'What would your perfect weekend afternoon look like?',
  'What kind of food do you never get tired of?',
  'What hobby would you like to spend more time on?',
  'How do you like discovering new places?',
  'Are you more into cozy cafes, outdoor walks, or lively spots?',
  'What is something fun you would like to try for the first time?',
  'What little thing can instantly make your day better?',
  'How do you like to unwind after a busy week?',
  'What is a memorable day out you have had recently?',
]

function chooseOpeningLines(){
  const shuffled=[...openingLineOptions]
  for(let index=shuffled.length-1;index>0;index--){
    const swapIndex=Math.floor(Math.random()*(index+1))
    const current=shuffled[index]
    shuffled[index]=shuffled[swapIndex]
    shuffled[swapIndex]=current
  }
  return shuffled.slice(0,3)
}

export function MatchesChat({user,refreshKey}:{user:User;refreshKey:number}){
  const [matches,setMatches]=useState<Match[]>([])
  const [active,setActive]=useState<Match|null>(null)
  const [messages,setMessages]=useState<Message[]>([])
  const [messagesLoading,setMessagesLoading]=useState(false)
  const [messagesLoadedFor,setMessagesLoadedFor]=useState<string|null>(null)
  const [socialLinks,setSocialLinks]=useState<MatchSocialLinks|null>(null)
  const [socialLinksLoading,setSocialLinksLoading]=useState(false)
  const [socialLinksError,setSocialLinksError]=useState('')
  const [matchProfile,setMatchProfile]=useState<ViewableProfile|null>(null)
  const [matchProfileLoading,setMatchProfileLoading]=useState(false)
  const [matchProfileError,setMatchProfileError]=useState('')
  const [openingLines,setOpeningLines]=useState<string[]>([])
  const [msg,setMsg]=useState('')
  const [busy,setBusy]=useState(false)
  const [reporting,setReporting]=useState(false)
  const composerRef=useRef<HTMLInputElement>(null)
  const profileRequest=useRef(0)

  async function loadMatches(){
    const {data,error}=await supabase!.rpc('list_matches')
    if(error){
      setMsg(error.message)
      return
    }
    const nextMatches=(data||[]) as Match[]
    setMatches(nextMatches)
    if(active&&!nextMatches.some(match=>match.id===active.id)){
      profileRequest.current+=1
      setActive(null)
      setMessages([])
      setMessagesLoadedFor(null)
      setOpeningLines([])
      setMatchProfile(null)
      setMatchProfileLoading(false)
      setMatchProfileError('')
    }
  }

  useEffect(()=>{loadMatches()},[refreshKey])

  useEffect(()=>{
    if(!active){
      setMessagesLoading(false)
      return
    }
    let cancelled=false
    async function loadMessages(){
      setMessagesLoading(true)
      setMessagesLoadedFor(null)
      const {data,error}=await supabase!.from('messages')
        .select('*')
        .eq('match_id',active!.id)
        .order('created_at')
      if(cancelled)return
      if(error){
        setMsg(error.message)
        setMessages([])
        setMessagesLoading(false)
        return
      }
      setMessages((data||[]) as Message[])
      setMessagesLoadedFor(active!.id)
      setMessagesLoading(false)
      const readResult=await supabase!.from('messages')
        .update({read_at:new Date().toISOString()})
        .eq('match_id',active!.id)
        .neq('sender_id',user.id)
        .is('read_at',null)
      if(cancelled)return
      if(readResult.error)setMsg(readResult.error.message)
      else await loadMatches()
    }
    loadMessages()
    const channel=supabase!.channel(`match:${active.id}`)
      .on('postgres_changes',{event:'INSERT',schema:'public',table:'messages',filter:`match_id=eq.${active.id}`},payload=>{
        setMessages(current=>current.some(message=>message.id===(payload.new as Message).id)
          ?current
          :[...current,payload.new as Message])
      })
      .subscribe()
    return ()=>{
      cancelled=true
      supabase!.removeChannel(channel)
    }
  },[active?.id,user.id])

  useEffect(()=>{
    if(!active){
      setSocialLinks(null)
      setSocialLinksLoading(false)
      setSocialLinksError('')
      return
    }
    let cancelled=false
    async function loadSocialLinks(){
      setSocialLinksLoading(true)
      setSocialLinksError('')
      try{
        const {data,error}=await supabase!.rpc('get_match_social_links',{match_uuid:active!.id})
        if(cancelled)return
        if(error){
          setSocialLinks(null)
          setSocialLinksError(error.message)
          return
        }
        const links=(data||[])[0] as MatchSocialLinks|undefined
        if(!links){
          setSocialLinks(null)
          setSocialLinksError('Social profiles are not available for this match.')
          return
        }
        setSocialLinks(links)
      }catch(error){
        if(cancelled)return
        setSocialLinks(null)
        setSocialLinksError(error instanceof Error?error.message:'Unable to load social profiles.')
      }finally{
        if(!cancelled)setSocialLinksLoading(false)
      }
    }
    void loadSocialLinks()
    return ()=>{cancelled=true}
  },[active?.id])

  function selectMatch(match:Match){
    if(active?.id===match.id)return
    profileRequest.current+=1
    setActive(match)
    setMatchProfile(null)
    setMatchProfileLoading(false)
    setMatchProfileError('')
    setSocialLinks(null)
    setSocialLinksLoading(true)
    setSocialLinksError('')
    setMessages([])
    setMessagesLoading(true)
    setMessagesLoadedFor(null)
    setOpeningLines(chooseOpeningLines())
    setMsg('')
  }

  async function viewProfile(){
    if(!active)return
    const matchId=active.id
    const requestId=++profileRequest.current
    setMatchProfile(null)
    setMatchProfileLoading(true)
    setMatchProfileError('')
    try{
      const {data,error}=await supabase!.rpc('get_match_profile',{match_uuid:matchId})
      if(requestId!==profileRequest.current)return
      if(error){
        setMatchProfileError(error.message)
        return
      }
      const profile=(data||[])[0] as ViewableProfile|undefined
      if(!profile){
        setMatchProfileError('This profile is no longer available for the match.')
        return
      }
      setMatchProfile(profile)
    }catch(error){
      if(requestId!==profileRequest.current)return
      setMatchProfileError(error instanceof Error?error.message:'Unable to load this profile.')
    }finally{
      if(requestId===profileRequest.current)setMatchProfileLoading(false)
    }
  }

  function useOpeningLine(line:string){
    const input=composerRef.current
    if(!input)return
    input.value=line
    input.focus()
  }

  async function send(e:FormEvent<HTMLFormElement>){
    e.preventDefault()
    if(!active)return
    const form=e.currentTarget
    const body=String(new FormData(form).get('body')||'').trim()
    if(!body)return
    setBusy(true)
    const {error}=await supabase!.from('messages').insert({match_id:active.id,sender_id:user.id,body})
    setBusy(false)
    if(error)setMsg(error.message)
    else form.reset()
  }

  async function block(){
    if(!active||!confirm(`Block ${active.other_first_name}? You will no longer see or message each other.`))return
    setBusy(true)
    const {error}=await supabase!.from('blocks').insert({blocker_id:user.id,blocked_id:active.other_user_id})
    setBusy(false)
    if(error){
      setMsg(error.message)
      return
    }
    setMsg(`${active.other_first_name} has been blocked.`)
    profileRequest.current+=1
    setActive(null)
    setMessages([])
    setMessagesLoadedFor(null)
    setOpeningLines([])
    setMatchProfile(null)
    setMatchProfileLoading(false)
    setMatchProfileError('')
    await loadMatches()
  }

  return <section className="panel matches">
    <h2>Matches & chat</h2>
    <div className="match-layout">
      <nav aria-label="Matches"><ul>
        {matches.map(match=><li key={match.id}>
          <button className={active?.id===match.id?'selected':''} onClick={()=>selectMatch(match)}>
            <MatchAvatar url={match.other_photo_url} name={match.other_first_name} size="list"/>
            <span className="match-list-name">{match.other_first_name}</span>
            {Number(match.unread_count)>0&&<b>{match.unread_count}</b>}
            <small>{match.shared_place_name||'Shared place'}</small>
          </button>
        </li>)}
      </ul></nav>
      <div className="chat">{active?<><div className="chat-head">
        <div>
          <div className="chat-head-person">
            <MatchAvatar url={active.other_photo_url} name={active.other_first_name} size="header"/>
            <div>
              <h3>{active.other_first_name}</h3>
              <small>{active.shared_place_name}</small>
            </div>
          </div>
          {socialLinksLoading&&<small className="match-social-status" role="status">Loading social profiles…</small>}
          {socialLinksError&&<small className="match-social-error" role="alert">{socialLinksError}</small>}
          {socialLinks&&!socialLinksLoading&&!socialLinksError&&(()=>{
            const links=[
              {label:'Facebook',url:socialLinks.facebook_url},
              {label:'Instagram',url:socialLinks.instagram_url},
              {label:'TikTok',url:socialLinks.tiktok_url},
            ].filter((link):link is {label:string;url:string}=>Boolean(link.url))
            return links.length
              ?<nav className="match-social-links" aria-label={`${active.other_first_name}'s social profiles`}>
                {links.map(link=><a href={link.url} key={link.label} target="_blank" rel="noopener noreferrer">{link.label}</a>)}
              </nav>
              :<small className="match-social-status">No social profiles shared.</small>
          })()}
          {matchProfileError&&<small className="match-profile-error" role="alert">{matchProfileError}</small>}
        </div>
        <div className="chat-head-actions">
          <button type="button" onClick={()=>{void viewProfile()}} disabled={matchProfileLoading}>
            {matchProfileLoading?'Loading profile…':'View profile'}
          </button>
          <button type="button" onClick={()=>setReporting(true)} disabled={busy}>Report</button>
          <button type="button" onClick={block} disabled={busy}>Block</button>
        </div>
      </div>
      <div className="log" role="log" aria-live="polite">
        {messagesLoading?<p role="status">Loading messages…</p>:
          messages.map(message=><p key={message.id} className={message.sender_id===user.id?'mine':''}><span>{message.body}</span></p>)}
      </div>
      {!messagesLoading&&messagesLoadedFor===active.id&&messages.length===0&&openingLines.length>0&&<div className="opening-lines" role="group" aria-label="Conversation starters">
        <p>Not sure how to start? Try one of these:</p>
        <div>
          {openingLines.map(line=><button type="button" key={line} onClick={()=>useOpeningLine(line)} disabled={busy}>{line}</button>)}
        </div>
      </div>}
      <form className="composer" onSubmit={send}>
        <label className="sr-only" htmlFor="body">Message</label>
        <input ref={composerRef} id="body" name="body" maxLength={1000} placeholder="Write a respectful message…" autoComplete="off" disabled={busy}/>
        <button className="primary" disabled={busy}>Send</button>
      </form></>:<p>Select a match to start chatting.</p>}</div>
    </div>
    <p className="status" aria-live="polite">{msg}</p>
    {active&&reporting&&<ReportDialog
      matchId={active.id}
      reportedUserId={active.other_user_id}
      reportedName={active.other_first_name}
      userId={user.id}
      onClose={()=>setReporting(false)}
    />}
    {matchProfile&&<ProfileDialog person={matchProfile} onClose={()=>setMatchProfile(null)}/>}
  </section>
}
