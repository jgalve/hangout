import {FormEvent,useEffect,useRef,useState} from 'react'
import {supabase} from '../lib/supabase'

type Message={id:number;sender_id:string;body:string;created_at:string}
type Category='harassment'|'spam'|'impersonation'|'underage'|'unsafe'|'non_consensual'|'other'

const categories:{value:Category;label:string}[]=[
  {value:'harassment',label:'Harassment or threats'},
  {value:'spam',label:'Spam or scam'},
  {value:'impersonation',label:'Impersonation'},
  {value:'underage',label:'Suspected underage user'},
  {value:'unsafe',label:'Unsafe offline behavior'},
  {value:'non_consensual',label:'Non-consensual or inappropriate content'},
  {value:'other',label:'Other'},
]

export function ReportDialog({
  matchId,
  reportedUserId,
  reportedName,
  userId,
  onClose,
}:{
  matchId:string
  reportedUserId:string
  reportedName:string
  userId:string
  onClose:()=>void
}){
  const dialogRef=useRef<HTMLDialogElement>(null)
  const [messages,setMessages]=useState<Message[]>([])
  const [selected,setSelected]=useState<number[]>([])
  const [loading,setLoading]=useState(true)
  const [busy,setBusy]=useState(false)
  const [error,setError]=useState('')
  const [caseReference,setCaseReference]=useState('')

  useEffect(()=>{
    const dialog=dialogRef.current
    dialog?.showModal()
    let cancelled=false
    async function loadMessages(){
      const {data,error:loadError}=await supabase!.from('messages')
        .select('id,sender_id,body,created_at')
        .eq('match_id',matchId)
        .order('created_at',{ascending:false})
        .order('id',{ascending:false})
        .limit(20)
      if(cancelled)return
      if(loadError)setError(loadError.message)
      else setMessages((data||[]).reverse() as Message[])
      setLoading(false)
    }
    loadMessages()
    return ()=>{
      cancelled=true
      if(dialog?.open)dialog.close()
    }
  },[matchId])

  function toggleMessage(id:number){
    setSelected(current=>current.includes(id)
      ?current.filter(item=>item!==id)
      :current.length<20?[...current,id]:current)
  }

  async function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    const form=new FormData(event.currentTarget)
    const category=String(form.get('category')||'')
    const details=String(form.get('details')||'').trim()
    if(!categories.some(option=>option.value===category)){
      setError('Choose a report category.')
      return
    }
    setBusy(true)
    setError('')
    const {data,error:rpcError}=await supabase!.rpc('submit_report',{
      target_user_id:reportedUserId,
      match_uuid:matchId,
      reason:category,
      details,
      selected_message_ids:selected.length?selected:null,
    })
    setBusy(false)
    if(rpcError){
      setError(rpcError.message)
      return
    }
    setCaseReference(String(data).toUpperCase())
  }

  return <dialog className="report-dialog" ref={dialogRef} aria-labelledby="report-title"
    onCancel={event=>{event.preventDefault();onClose()}}>
    {caseReference?<div>
      <h2 id="report-title">Report submitted</h2>
      <p role="status">Thank you for letting us know. Our safety team will review your report.</p>
      <p>Case reference: <strong>{caseReference}</strong></p>
      <button type="button" className="primary" onClick={onClose}>Done</button>
    </div>:<form onSubmit={submit}>
      <h2 id="report-title">Report {reportedName}</h2>
      <p className="notice compact" role="note">If you or someone else is in immediate danger, contact local emergency services. This form is not an emergency response service.</p>
      <label htmlFor="report-category">What happened?
        <select id="report-category" name="category" required disabled={busy} autoFocus>
          <option value="">Select a category</option>
          {categories.map(option=><option key={option.value} value={option.value}>{option.label}</option>)}
        </select>
      </label>
      <fieldset className="report-messages">
        <legend>Include messages (optional)</legend>
        <p className="fine">Choose up to 20 messages from this conversation. If you select none, the most recent 20 messages will be attached.</p>
        {loading?<p role="status">Loading recent messages…</p>:messages.length===0?<p>No messages are available to attach.</p>:
          <ul>{messages.map(message=><li key={message.id}>
            <label className="check">
              <input type="checkbox" checked={selected.includes(message.id)} onChange={()=>toggleMessage(message.id)} disabled={busy||(!selected.includes(message.id)&&selected.length>=20)}/>
              <span><strong>{message.sender_id===userId?'You':reportedName}</strong> · {new Date(message.created_at).toLocaleString()}<br/>{message.body}</span>
            </label>
          </li>)}</ul>}
      </fieldset>
      <label htmlFor="report-details">Description (optional)
        <textarea id="report-details" name="details" maxLength={1000} rows={4} disabled={busy}/>
      </label>
      <p className="fine">Only include details needed to understand what happened. Do not share passwords or payment information.</p>
      {error&&<p className="status" role="alert">{error}</p>}
      <div className="report-actions">
        <button type="button" className="secondary" onClick={onClose} disabled={busy}>Cancel</button>
        <button type="submit" className="primary" disabled={busy}>{busy?'Submitting…':'Submit report'}</button>
      </div>
    </form>}
  </dialog>
}
