import {useEffect,useState} from 'react'
import {supabase} from '../lib/supabase'
import {pinProfilePlace} from '../lib/profilePlaces'
import {getPersonalityLabels,ProfileDialog} from './ProfileDialog'
import type {ViewableProfile} from './ProfileDialog'
type RankedHangout={category:'popular'|'trending';ranking_position:number;place_id:string;place_name:string;user_count:number}
type PinnedPlace={place_id:string;position:number}
type Candidate=ViewableProfile

export function Discovery({onMatch,userId}:{onMatch:()=>void;userId:string}){
  const [items,setItems]=useState<Candidate[]>([])
  const [msg,setMsg]=useState('')
  const [selected,setSelected]=useState<Candidate|null>(null)
  const [selectedPlace,setSelectedPlace]=useState('')
  const [rankings,setRankings]=useState<RankedHangout[]>([])
  const [rankingsLoading,setRankingsLoading]=useState(true)
  const [rankingsError,setRankingsError]=useState('')
  const [pinnedPlaces,setPinnedPlaces]=useState<PinnedPlace[]>([])
  const [pinnedPlacesLoading,setPinnedPlacesLoading]=useState(true)
  const [pinnedPlacesError,setPinnedPlacesError]=useState('')
  const [pinningPlaceId,setPinningPlaceId]=useState<string|null>(null)
  const [pinFeedback,setPinFeedback]=useState<{message:string;isError:boolean}|null>(null)
  const sharedPlaces=Array.from(new Map(items.flatMap(person=>person.shared_places).map(place=>[place.id,place])).values())
  const visibleItems=selectedPlace
    ?items.filter(person=>person.shared_places.some(place=>place.id===selectedPlace))
    :items

  async function load(){
    const {data,error}=await supabase!.rpc('discover_candidates',{limit_count:20})
    setItems(data||[])
    setMsg(error?.message||(!(data||[]).length?'No new people yet. Pin popular places or check back later.':''))
  }

  async function loadRankings(){
    setRankingsLoading(true)
    setRankingsError('')
    const {data,error}=await supabase!.rpc('discover_hangout_rankings')
    if(error){
      setRankings([])
      setRankingsError(error.message)
      setRankingsLoading(false)
      return
    }
    setRankings((data||[]) as RankedHangout[])
    setRankingsLoading(false)
  }

  async function loadPinnedPlaces(){
    setPinnedPlacesLoading(true)
    setPinnedPlacesError('')
    const {data,error}=await supabase!.from('profile_places')
      .select('place_id,position')
      .eq('profile_id',userId)
      .order('position')
    if(error){
      setPinnedPlaces([])
      setPinnedPlacesError(error.message)
      setPinnedPlacesLoading(false)
      return
    }
    setPinnedPlaces((data||[]) as PinnedPlace[])
    setPinnedPlacesLoading(false)
  }

  async function pinRankedPlace(place:RankedHangout){
    setPinningPlaceId(place.place_id)
    setPinFeedback(null)
    const result=await pinProfilePlace(userId,place.place_id)
    setPinningPlaceId(null)
    if(result.error!==null){
      setPinFeedback({message:result.error,isError:true})
      await loadPinnedPlaces()
      return
    }
    setPinnedPlaces(current=>[...current,{place_id:place.place_id,position:result.position}])
    setPinFeedback({message:`${place.place_name} pinned to your hangout places.`,isError:false})
  }

  function renderRanking(category:'popular'|'trending',title:string,description:string,emptyMessage:string){
    const places=rankings.filter(place=>place.category===category).sort((a,b)=>a.ranking_position-b.ranking_position)
    return <section className="hangout-ranking" aria-labelledby={`hangout-ranking-${category}`}>
      <div className="hangout-ranking-heading">
        <div>
          <h3 id={`hangout-ranking-${category}`}>{title}</h3>
          <p>{description}</p>
        </div>
      </div>
      {rankingsLoading?<p className="fine" role="status">Loading hangouts…</p>
        :rankingsError?<p className="hangout-ranking-error" role="alert">Unable to load hangout rankings: {rankingsError}</p>
        :places.length>0?<ol className="hangout-ranking-list" aria-label={`Top 5 ${title.toLowerCase()}`}>
          {places.map(place=>{
            const alreadyPinned=pinnedPlaces.some(pinned=>pinned.place_id===place.place_id)
            const pinDisabled=pinnedPlacesLoading||Boolean(pinnedPlacesError)||pinningPlaceId!==null||pinnedPlaces.length>=5
            const pinLabel=pinningPlaceId===place.place_id?'Pinning…'
              :pinnedPlacesLoading?'Checking…'
                :pinnedPlacesError?'Unavailable'
                  :pinnedPlaces.length>=5?'Limit reached':'Pin hangout'
            return <li key={place.place_id}>
            <div className="hangout-ranking-row">
              <span className="hangout-ranking-position">{place.ranking_position}</span>
              <strong className="hangout-ranking-place-name">{place.place_name}</strong>
              <span className="hangout-ranking-count">{place.user_count} {place.user_count===1?'user':'users'}</span>
              {alreadyPinned?<span className="hangout-ranking-pinned">Pinned</span>
                :<button className="secondary hangout-ranking-pin" type="button" disabled={pinDisabled}
                  aria-label={`Pin ${place.place_name} to your hangout places`}
                  onClick={()=>{void pinRankedPlace(place)}}>{pinLabel}</button>}
            </div>
          </li>})}
        </ol>:<p className="fine">{emptyMessage}</p>}
    </section>
  }

  useEffect(()=>{void load();void loadRankings();void loadPinnedPlaces()},[userId])

  async function swipe(person:Candidate,choice:'like'|'pass'){
    setItems(v=>v.filter(candidate=>candidate.id!==person.id))
    const {data,error}=await supabase!.rpc('record_swipe',{target:person.id,choice})
    if(error)setMsg(error.message)
    else if(data){
      setMsg(`It is a match with ${person.first_name}!`)
      onMatch()
    }
  }

  return <section className="panel">
    <div className="discover-header">
      <div className="discover-heading">
        <h2>Discover</h2>
        <p>People near shared places and interests</p>
      </div>
      {items.length>0&&<div className="discover-filter">
        <label className="sr-only" htmlFor="discover-place-filter">Filter by shared place</label>
        <div className="discover-filter-control">
          <svg className="discover-filter-pin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>
          </svg>
          <select id="discover-place-filter" value={selectedPlace} onChange={event=>setSelectedPlace(event.target.value)}>
            <option value="">All places</option>
            {sharedPlaces.map(place=><option key={place.id} value={place.id}>{place.name}</option>)}
          </select>
          <svg className="discover-filter-chevron" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="m4 6 4 4 4-4"/>
          </svg>
        </div>
      </div>}
    </div>
    <section className="hangout-rankings" aria-label="Popular and trending hangouts">
      {renderRanking('popular','Popular hangouts','Most pinned by active users.','No pinned hangouts yet.')}
      {renderRanking('trending','Trending hangouts','Most pinned in the last 7 days.','No new pins in the last 7 days yet.')}
    </section>
    {pinnedPlacesError&&<p className="hangout-ranking-error" role="alert">Unable to check your pinned hangouts: {pinnedPlacesError}</p>}
    {pinFeedback&&<p className={pinFeedback.isError?'hangout-ranking-error':'fine'} role={pinFeedback.isError?'alert':'status'}>{pinFeedback.message}</p>}
    {items.length>0?visibleItems.length>0?<div className="candidate-grid">
      {visibleItems.map(person=><article className="candidate" key={person.id}>
        <button className="candidate-open" type="button" onClick={()=>setSelected(person)} aria-label={`View ${person.first_name}'s full profile`}>
          <span className="sr-only">View {person.first_name}'s full profile</span>
        </button>
        <div className="candidate-media">
          {person.photo_url
            ?<img src={person.photo_url} alt={`${person.first_name}'s profile`}/>
            :<div className="candidate-avatar" aria-hidden="true">{person.first_name.slice(0,1)}</div>}
          <h3>{person.first_name}</h3>
        </div>
        {person.additional_photo_urls?.filter((url):url is string=>Boolean(url)).length>0&&
          <div className="candidate-gallery" aria-label={`${person.first_name}'s additional photos`}>
            {person.additional_photo_urls.filter((url):url is string=>Boolean(url)).map((url,index)=><img src={url} alt={`${person.first_name}'s additional photo ${index+1}`} key={url}/>)}
          </div>}
        <span className="candidate-profile-hint">View full profile</span>
        {person.is_verified&&<span className="verification-badge" aria-label="Verified: a HangOut admin or moderator reviewed a government-issued photo ID">Verified</span>}
        {getPersonalityLabels(person).length>0&&<ul className="interest-chips" aria-label={`${person.first_name}'s hangout personality`}>{getPersonalityLabels(person).map(personality=><li key={personality}>{personality}</li>)}</ul>}
        <ul className="shared-places" aria-label={`Places shared with ${person.first_name}`}>
          {person.shared_places.map(place=><li className="candidate-place" key={place.id}>
            <div className="candidate-place-name">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>
              </svg>
              <strong>{place.name}</strong>
            </div>
          </li>)}
        </ul>
        <div className="actions"><button className="secondary" onClick={()=>swipe(person,'pass')}>Not now</button><button className="primary" onClick={()=>swipe(person,'like')}>Interested</button></div>
      </article>)}
    </div>:<p>No discoverable people in this list share this place. Choose another place or select “All places.”</p>:<p>{msg||'Loading candidates…'}</p>}
    <button className="link" onClick={()=>{void load();void loadRankings();void loadPinnedPlaces()}}>Refresh candidates</button>
    <p className="status">{msg}</p>
    {selected&&<ProfileDialog person={selected} onClose={()=>setSelected(null)}/>}
  </section>
}
