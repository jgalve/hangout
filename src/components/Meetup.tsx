import {FormEvent,useEffect,useState} from 'react'
import type {User} from '@supabase/supabase-js'
import {supabase} from '../lib/supabase'

type Match={id:string;other_first_name:string;shared_place_id:string|null;shared_place_name:string|null}
type Proposal={id:string;match_id:string;proposer_id:string;proposed_for:string;note:string;status:string;places:{name:string}|null}

export function Meetup({user,refreshKey}:{user:User;refreshKey:number}){
  const [matches,setMatches]=useState<Match[]>([])
  const [items,setItems]=useState<Proposal[]>([])
  const [msg,setMsg]=useState('')
  const [busy,setBusy]=useState(false)

  async function load(){
    const {data,error}=await supabase!.rpc('list_matches')
    if(error){
      setMsg(error.message)
      return
    }
    const nextMatches=(data||[]) as Match[]
    setMatches(nextMatches)
    const ids=nextMatches.map(match=>match.id)
    if(!ids.length){
      setItems([])
      return
    }
    const result=await supabase!.from('meetup_proposals')
      .select('*,places(name)')
      .in('match_id',ids)
      .order('created_at',{ascending:false})
    if(result.error)setMsg(result.error.message)
    else setItems((result.data||[]) as Proposal[])
  }

  useEffect(()=>{load()},[refreshKey])

  async function create(e:FormEvent<HTMLFormElement>){
    e.preventDefault()
    const form=e.currentTarget
    const fd=new FormData(form)
    const match=matches.find(item=>item.id===fd.get('match'))
    if(!match?.shared_place_id)return setMsg('This match has no shared place.')
    const date=String(fd.get('when')||'')
    if(!date||new Date(date)<=new Date())return setMsg('Choose a future date and time.')
    setBusy(true)
    const result=await supabase!.from('meetup_proposals').insert({
      match_id:match.id,
      proposer_id:user.id,
      place_id:match.shared_place_id,
      proposed_for:new Date(date).toISOString(),
      note:String(fd.get('note')||'').trim(),
    })
    setBusy(false)
    setMsg(result.error?.message||'Meetup proposed. Keep first meetings public and arrange your own transport.')
    if(!result.error){
      form.reset()
      await load()
    }
  }

  async function respond(id:string,action:'accepted'|'declined'){
    setBusy(true)
    const {error}=await supabase!.rpc('respond_to_meetup',{proposal_id:id,action})
    setBusy(false)
    if(error)setMsg(error.message)
    else{
      setMsg(`Meetup ${action}.`)
      await load()
    }
  }

  async function cancel(id:string){
    setBusy(true)
    const {error}=await supabase!.rpc('cancel_meetup',{proposal_id:id})
    setBusy(false)
    if(error)setMsg(error.message)
    else{
      setMsg('Meetup cancelled.')
      await load()
    }
  }

  async function change(e:FormEvent<HTMLFormElement>,proposalId:string){
    e.preventDefault()
    const fd=new FormData(e.currentTarget)
    const date=String(fd.get('when')||'')
    if(!date||new Date(date)<=new Date())return setMsg('Choose a future date and time.')
    setBusy(true)
    const {error}=await supabase!.rpc('change_meetup',{
      proposal_id:proposalId,
      new_proposed_for:new Date(date).toISOString(),
      new_note:String(fd.get('note')||'').trim(),
    })
    setBusy(false)
    if(error)setMsg(error.message)
    else{
      setMsg('Change proposed. The other person needs to accept it.')
      await load()
    }
  }

  return <section className="panel">
    <h2>Meetup proposals</h2>
    <div className="notice compact"><strong>Meet safely.</strong> Use a public place, tell someone you trust, and leave whenever you want.</div>
    <form onSubmit={create}>
      <label>Match<select name="match" required disabled={busy}>
        <option value="">Select a match</option>
        {matches.filter(match=>match.shared_place_id).map(match=><option key={match.id} value={match.id}>{match.other_first_name} at {match.shared_place_name}</option>)}
      </select></label>
      <label>Date and time<input name="when" type="datetime-local" required disabled={busy}/></label>
      <label>Note<input name="note" maxLength={280} disabled={busy}/></label>
      <button className="primary" disabled={busy}>Suggest meeting here</button>
    </form>
    <ul className="proposals">
      {items.map(proposal=><li key={proposal.id}>
        <strong>{proposal.places?.name}</strong>
        <span>{new Date(proposal.proposed_for).toLocaleString()} · {proposal.status}</span>
        <p>{proposal.note}</p>
        {proposal.status==='pending'&&proposal.proposer_id!==user.id&&
          <div className="proposal-actions">
            <button type="button" onClick={()=>respond(proposal.id,'accepted')} disabled={busy}>Accept</button>
            <button type="button" onClick={()=>respond(proposal.id,'declined')} disabled={busy}>Decline</button>
          </div>}
        {(proposal.status==='pending'&&proposal.proposer_id===user.id||proposal.status==='accepted')&&
          <div className="proposal-management">
            {proposal.status==='accepted'&&<form onSubmit={e=>change(e,proposal.id)}>
              <label>Suggest a new time<input name="when" type="datetime-local" required disabled={busy}/></label>
              <label>Note<input name="note" maxLength={280} defaultValue={proposal.note} disabled={busy}/></label>
              <button type="submit" disabled={busy}>Suggest change</button>
            </form>}
            <button type="button" onClick={()=>cancel(proposal.id)} disabled={busy}>Cancel meetup</button>
          </div>}
      </li>)}
    </ul>
    <p className="status" aria-live="polite">{msg}</p>
  </section>
}
