import {useEffect,useState} from 'react'

export type FeaturedHangout={
  place_id:string
  osm_type:string
  osm_id:string
  venue_name:string
  promo_title:string
  promo_description:string
  promo_terms:string
  photo_url:string|null
  promo_cta_label:string|null
  promo_cta_url:string|null
  demo_only:boolean
  is_published:boolean
  updated_at:string
}

export type FeaturedPinState='checking'|'unavailable'|'limit'|'pinning'|'busy'|'pinned'|'available'

export function getOpenStreetMapUrl(osmType:string,osmId:string){
  if(!['node','way','relation'].includes(osmType)||!/^\d+$/.test(osmId))return null
  return `https://www.openstreetmap.org/${osmType}/${osmId}`
}

export function FeaturedHangoutCard({
  hangout,
  preview=false,
  pinState,
  onPin,
}:{
  hangout:FeaturedHangout
  preview?:boolean
  pinState?:FeaturedPinState
  onPin?:()=>void
}){
  const [imageFailed,setImageFailed]=useState(false)

  useEffect(()=>{setImageFailed(false)},[hangout.photo_url])

  const mapUrl=getOpenStreetMapUrl(hangout.osm_type,hangout.osm_id)
  const pinLabel=pinState==='checking'?'Checking…'
    :pinState==='unavailable'?'Unavailable'
      :pinState==='limit'?'Limit reached'
        :pinState==='pinning'?'Pinning…'
          :pinState==='busy'?'Pin in progress…':'Pin hangout'

  return <article className={`featured-hangout${preview?' featured-hangout-preview':''}`}>
    <div className="featured-hangout-photo">
      {hangout.photo_url&&!imageFailed
        ?<img
          src={hangout.photo_url}
          alt={`${hangout.venue_name} promotional`}
          loading="lazy"
          referrerPolicy="no-referrer"
          onError={()=>setImageFailed(true)}
        />
        :<div className="featured-hangout-placeholder" role="img" aria-label={`Photo placeholder for ${hangout.venue_name}`}>
          <svg viewBox="0 0 48 48" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <rect x="5" y="8" width="38" height="32" rx="5"/>
            <circle cx="17" cy="19" r="3"/>
            <path d="m8 35 11-11 7 7 5-5 9 9"/>
          </svg>
          <span>Photo placeholder</span>
        </div>}
    </div>
    <div className="featured-hangout-content">
      <p className="featured-hangout-eyebrow">Featured hangout</p>
      <h3>{hangout.venue_name}</h3>
      <span className="featured-hangout-audience">For matching pairs</span>
      <h4>{hangout.promo_title}</h4>
      <p>{hangout.promo_description}</p>
      {hangout.demo_only&&<p className="featured-hangout-demo">SAMPLE ONLY - NOT A REAL OR REDEEMABLE OFFER</p>}
      {hangout.promo_terms&&<p className="featured-hangout-terms">{hangout.promo_terms}</p>}
      <div className="featured-hangout-actions">
        {mapUrl&&<div className="featured-hangout-map-links">
          <a
            className="secondary featured-hangout-map"
            href={mapUrl}
            target="_blank"
            rel="noopener noreferrer"
          >View map</a>
          <small className="featured-hangout-map-attribution">Map data © <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap contributors</a></small>
        </div>}
        {hangout.promo_cta_label&&hangout.promo_cta_url&&<a
          className="secondary featured-hangout-cta"
          href={hangout.promo_cta_url}
          target="_blank"
          rel="noopener noreferrer"
        >{hangout.promo_cta_label}</a>}
        {pinState&&<>{pinState==='pinned'
          ?<span className="featured-hangout-pinned">Pinned to your profile</span>
          :<button
            className="secondary featured-hangout-pin"
            type="button"
            disabled={!onPin||pinState!=='available'}
            aria-label={`Pin ${hangout.venue_name} to your hangout places`}
            onClick={onPin}
          >{pinLabel}</button>}</>}
      </div>
    </div>
  </article>
}
