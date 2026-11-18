import {supabase} from './supabase'

type PinProfilePlaceResult=
  |{error:string;position:null}
  |{error:null;position:number}

export async function pinProfilePlace(userId:string,placeId:string):Promise<PinProfilePlaceResult>{
  const {data:links,error:linksError}=await supabase!.from('profile_places')
    .select('place_id,position')
    .eq('profile_id',userId)
  if(linksError)return {error:linksError.message,position:null}
  if(links.some(link=>link.place_id===placeId))return {error:'This place is already pinned.',position:null}
  if(links.length>=5)return {error:'You can save up to five places.',position:null}
  const position=[1,2,3,4,5].find(slot=>!links.some(link=>link.position===slot))
  if(!position)return {error:'No available place slot. Remove a place and try again.',position:null}
  const {error}=await supabase!.from('profile_places').insert({profile_id:userId,place_id:placeId,position})
  if(error)return {error:error.message,position:null}
  return {error:null,position}
}
