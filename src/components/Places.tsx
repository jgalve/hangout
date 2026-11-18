import {FormEvent,useEffect,useState} from 'react'
import type {User} from '@supabase/supabase-js'
import {supabase} from '../lib/supabase'
import {pinProfilePlace} from '../lib/profilePlaces'

type SearchPlace={place_id:number;osm_type:string;osm_id:number|string;display_name:string;lat:string;lon:string;name?:string}
type Saved={id:string;name:string;display_name:string;position:number;place_story:string|null}

export function Places({user}:{user:User}){
  const [saved,setSaved]=useState<Saved[]>([])
  const [results,setResults]=useState<SearchPlace[]>([])
  const [msg,setMsg]=useState('')
  const [locationBusy,setLocationBusy]=useState(false)
  const [storyDrafts,setStoryDrafts]=useState<Record<string,string>>({})
  const [savingStoryId,setSavingStoryId]=useState<string|null>(null)

  async function load(){
    const {data,error}=await supabase!.from('profile_places')
      .select('place_id,position,place_story,places(id,name,display_name)')
      .eq('profile_id',user.id)
      .order('position')
    if(error){setMsg(error.message);return}
    const places=(data||[]).flatMap((row:any)=>row.places?[{...row.places,position:row.position,place_story:row.place_story}]:[])
    setSaved(places)
    setStoryDrafts(Object.fromEntries(places.map(place=>[place.id,place.place_story||''])))
  }

  useEffect(()=>{load()},[user.id])

  async function search(e:FormEvent<HTMLFormElement>){
    e.preventDefault()
    const query=String(new FormData(e.currentTarget).get('q')||'').trim()
    if(query.length<3){setMsg('Enter at least three characters.');return}
    setMsg('Searching…')
    try{
      const response=await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&limit=6&q=${encodeURIComponent(query)}`,{headers:{Accept:'application/json'}})
      if(!response.ok)throw new Error('Place search is unavailable. Try again later.')
      setResults(await response.json())
      setMsg('')
    }catch(error){
      setMsg(error instanceof Error?error.message:'Place search is unavailable. Try again later.')
    }
  }

  function useCurrentLocation(){
    if(!navigator.geolocation){setMsg('Location access is not available in this browser.');return}
    setLocationBusy(true)
    setMsg('Getting your location…')
    navigator.geolocation.getCurrentPosition(async position=>{
      try{
        const params=new URLSearchParams({
          format:'jsonv2',
          zoom:'17',
          addressdetails:'1',
          lat:String(position.coords.latitude),
          lon:String(position.coords.longitude),
        })
        const response=await fetch(`https://nominatim.openstreetmap.org/reverse?${params}`,{headers:{Accept:'application/json'}})
        if(!response.ok)throw new Error('Nearby place lookup is unavailable. Try searching by name instead.')
        const place=await response.json() as SearchPlace&{error?:string}
        if(place.error)throw new Error('No nearby named place was found. Try searching by name instead.')
        if(!place.osm_type||!place.osm_id||!place.display_name||!place.lat||!place.lon){
          throw new Error('No nearby named place was found. Try searching by name instead.')
        }
        setResults([place])
        setMsg('Nearby place found. Select it below to pin it to your profile.')
      }catch(error){
        setMsg(error instanceof Error?error.message:'Nearby place lookup failed. Try searching by name instead.')
      }finally{
        setLocationBusy(false)
      }
    },error=>{
      setLocationBusy(false)
      if(error.code===error.PERMISSION_DENIED)setMsg('Location permission was denied. Allow location access in your browser or search by name.')
      else if(error.code===error.POSITION_UNAVAILABLE)setMsg('Your current location is unavailable. Try searching by name instead.')
      else if(error.code===error.TIMEOUT)setMsg('Location lookup timed out. Try again or search by name.')
      else setMsg('Unable to get your current location. Try searching by name instead.')
    },{enableHighAccuracy:false,maximumAge:60000,timeout:10000})
  }

  async function add(place:SearchPlace){
    if(saved.length>=5){setMsg('You can save up to five places.');return}
    const name=place.name||place.display_name.split(',').slice(0,2).join(',')
    const {data,error}=await supabase!.from('places').upsert({
      osm_type:place.osm_type,
      osm_id:String(place.osm_id),
      name,
      display_name:place.display_name,
      lat:Number(place.lat),
      lon:Number(place.lon),
    },{onConflict:'osm_type,osm_id'}).select().single()
    if(error||!data){setMsg(error?.message||'Unable to save place.');return}
    const pinResult=await pinProfilePlace(user.id,data.id)
    if(pinResult.error){setMsg(pinResult.error);return}
    setResults([])
    setMsg(`${name} pinned.`)
    await load()
  }

  async function remove(id:string){
    const {error}=await supabase!.from('profile_places').delete().eq('profile_id',user.id).eq('place_id',id)
    if(error){setMsg(error.message);return}
    setMsg('Place removed.')
    await load()
  }

  async function saveStory(event:FormEvent<HTMLFormElement>,place:Saved){
    event.preventDefault()
    const story=(storyDrafts[place.id]||'').trim()
    setSavingStoryId(place.id)
    const {error}=await supabase!.from('profile_places')
      .update({place_story:story||null})
      .eq('profile_id',user.id)
      .eq('place_id',place.id)
    setSavingStoryId(null)
    if(error){setMsg(error.message);return}
    setSaved(current=>current.map(item=>item.id===place.id?{...item,place_story:story||null}:item))
    setMsg(story?'Place story saved.':'Place story cleared.')
  }

  return <section className="panel">
    <h2>Your hangout places <span className="count">{saved.length}/5</span></h2>
    <form className="search" onSubmit={search}>
      <label>Search OpenStreetMap<input name="q" type="search" placeholder="e.g. Bonifacio High Street"/></label>
      <button className="primary" type="submit">Search</button>
    </form>
    <button className="link location-link" type="button" onClick={useCurrentLocation} disabled={locationBusy}>
      {locationBusy?'Finding place…':'Use current location'}
    </button>
    <p className="fine">Your browser will ask for location permission. Coordinates are sent to OpenStreetMap to find a nearby place; only the place you choose is pinned.</p>
    {results.length>0&&<ul className="results">{results.map(place=><li key={`${place.osm_type}-${place.osm_id}`}>
      <button type="button" onClick={()=>add(place)}>
        <svg className="result-place-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>
        </svg>
        <span>{place.display_name}</span>
      </button>
    </li>)}</ul>}
    <ul className="saved">{saved.map(place=><li key={place.id}>
      <span><strong>{place.name}</strong><small>{place.display_name}</small></span>
      <button type="button" onClick={()=>remove(place.id)}>Remove</button>
      <form className="place-story-form" onSubmit={event=>saveStory(event,place)}>
        <label>Place story
          <textarea
            value={storyDrafts[place.id]||''}
            maxLength={280}
            rows={3}
            placeholder="Why you like it, what you do here, a favorite order or activity, the best time to visit, or a memory you’re comfortable sharing."
            onChange={event=>setStoryDrafts(current=>({...current,[place.id]:event.target.value}))}
          />
        </label>
        <p className="fine">Optional, up to 280 characters. Visible to people who share this place.</p>
        <button className="primary" type="submit" disabled={savingStoryId===place.id}>
          {savingStoryId===place.id?'Saving…':'Save story'}
        </button>
      </form>
    </li>)}</ul>
    <p className="status" aria-live="polite">{msg}</p>
    <p className="fine">Search data © OpenStreetMap contributors. Production should use a geocoding provider with suitable capacity and terms.</p>
  </section>
}
