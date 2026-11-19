import {useState} from 'react'
import {AtSign,Copy,Mail,MessageCircle,Share,Share2} from 'lucide-react'

const shareTitle='Join HangOut'
const shareText='Discover people who enjoy the same places you do on HangOut.'

export function DiscoveryShare(){
  const [feedback,setFeedback]=useState<{message:string;isError:boolean}|null>(null)
  const inviteUrl=new URL('/',window.location.origin).toString()
  const shareUrl=encodeURIComponent(inviteUrl)
  const messageUrl=encodeURIComponent(`${shareText}\n${inviteUrl}`)
  const supportsNativeShare=typeof navigator.share==='function'

  async function shareInvite(){
    setFeedback(null)
    try{
      await navigator.share({title:shareTitle,text:shareText,url:inviteUrl})
    }catch(error){
      if(error instanceof DOMException&&error.name==='AbortError')return
      setFeedback({message:'Unable to open the share sheet. Try another option.',isError:true})
    }
  }

  async function copyInvite(){
    setFeedback(null)
    try{
      await navigator.clipboard.writeText(inviteUrl)
      setFeedback({message:'Invite link copied.',isError:false})
    }catch{
      setFeedback({message:'Unable to copy the invite link in this browser.',isError:true})
    }
  }

  return <section className="discover-share" aria-labelledby="discover-share-heading">
    <div className="discover-share-intro">
      <h3 id="discover-share-heading">Invite friends to HangOut</h3>
      <p>Share the public marketing homepage. Your profile and Discover activity are not included.</p>
      {supportsNativeShare&&<p className="fine">Messenger may be available in your device’s share options.</p>}
    </div>
    <div className="discover-share-actions">
      {supportsNativeShare&&<button className="primary" type="button" onClick={()=>void shareInvite()}><Share2 className="share-icon" size={18} aria-hidden="true"/>Share invite</button>}
      <button className="secondary" type="button" onClick={()=>void copyInvite()}><Copy className="share-icon" size={18} aria-hidden="true"/>Copy link</button>
      <a className="secondary" href={`https://wa.me/?text=${messageUrl}`} target="_blank" rel="noopener noreferrer"><MessageCircle className="share-icon" size={18} aria-hidden="true"/>WhatsApp</a>
      <a className="secondary" href={`https://www.facebook.com/sharer/sharer.php?u=${shareUrl}`} target="_blank" rel="noopener noreferrer"><Share className="share-icon" size={18} aria-hidden="true"/>Facebook</a>
      <a className="secondary" href={`https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${shareUrl}`} target="_blank" rel="noopener noreferrer"><AtSign className="share-icon" size={18} aria-hidden="true"/>X</a>
      <a className="secondary" href={`mailto:?subject=${encodeURIComponent(shareTitle)}&body=${messageUrl}`}><Mail className="share-icon" size={18} aria-hidden="true"/>Email</a>
    </div>
    {feedback&&<p className={feedback.isError?'hangout-ranking-error':'fine'} role={feedback.isError?'alert':'status'}>{feedback.message}</p>}
  </section>
}
