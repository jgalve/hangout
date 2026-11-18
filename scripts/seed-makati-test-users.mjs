import {randomBytes} from 'node:crypto'
import {readFile} from 'node:fs/promises'
import {createClient} from '@supabase/supabase-js'

function parseEnv(contents){
  return Object.fromEntries(contents.split(/\r?\n/).flatMap(line=>{
    const trimmed=line.trim()
    if(!trimmed||trimmed.startsWith('#'))return []
    const separator=trimmed.indexOf('=')
    if(separator<1)return []
    const key=trimmed.slice(0,separator).trim()
    let value=trimmed.slice(separator+1).trim()
    if((value.startsWith('"')&&value.endsWith('"'))||(value.startsWith("'")&&value.endsWith("'"))){
      value=value.slice(1,-1)
    }
    return [[key,value]]
  }))
}

function avatarDataUrl(name,color){
  const initial=name.slice(0,1).toUpperCase()
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400"><rect width="400" height="400" rx="48" fill="${color}"/><circle cx="200" cy="155" r="76" fill="#fbf7f1"/><path d="M66 400c10-102 59-153 134-153s124 51 134 153" fill="#fbf7f1"/><text x="200" y="185" text-anchor="middle" font-family="sans-serif" font-size="80" font-weight="700" fill="#292a24">${initial}</text></svg>`
  return `data:image/svg+xml,${encodeURIComponent(svg)}`
}

async function main(){
  const config=parseEnv(await readFile('.env.seed.local','utf8'))
  if(config.SEED_TARGET!=='development'){
    throw new Error('Set SEED_TARGET=development in .env.seed.local. This seeder refuses other targets.')
  }
  if(!config.SUPABASE_URL||!config.SUPABASE_SERVICE_ROLE_KEY){
    throw new Error('.env.seed.local must contain SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.')
  }

  const supabase=createClient(config.SUPABASE_URL,config.SUPABASE_SERVICE_ROLE_KEY,{
    auth:{autoRefreshToken:false,persistSession:false},
  })

  const {error:schemaError}=await supabase.from('profiles')
    .select('interests,hangout_personality,additional_photo_urls,photo_url').limit(0)
  if(schemaError)throw new Error(`Profile schema is not ready; apply migrations through 014 first. ${schemaError.message}`)

  const {data:bucket,error:bucketError}=await supabase.storage.getBucket('profile-photos')
  if(bucketError||!bucket)throw new Error('The profile-photos bucket is missing; apply migrations through 006 first.')

  const {data:place,error:placeError}=await supabase.from('places').upsert({
    osm_type:'way',
    osm_id:'777918857',
    name:'Ayala Triangle Gardens',
    display_name:'Ayala Triangle Gardens, Bel-Air, District I, Makati, Southern Manila District, Metro Manila, 1226, Philippines',
    lat:14.5556473,
    lon:121.0239225,
  },{onConflict:'osm_type,osm_id'}).select('id').single()
  if(placeError)throw new Error(`Could not create the Makati test place. ${placeError.message}`)

  const seeds=[
    {name:'Test Alex',email:'hangout-seed-01@example.com',bio:'Test profile: coffee walks and weekend markets.',interests:['Coffee','Markets'],hangout_personality:['Coffee and conversation','Walk and explore','Markets and pop-ups'],color:'#e8b95b',birth_date:'1996-04-12'},
    {name:'Test Bea',email:'hangout-seed-02@example.com',bio:'Test profile: live music and trying new food spots.',interests:['Live music','Food spots'],hangout_personality:['Live music','Food trip','Nightlife'],color:'#b8c3a8',birth_date:'1994-09-23'},
    {name:'Test Chris',email:'hangout-seed-03@example.com',bio:'Test profile: books, parks, and slow mornings.',interests:['Books','Outdoors'],hangout_personality:['Quiet parks','Museums and galleries','Beach or nature trips'],color:'#e6c6a8',birth_date:'1998-02-08'},
    {name:'Test Dani',email:'hangout-seed-04@example.com',bio:'Test profile: art, culture, and good coffee.',interests:['Art & culture','Coffee'],hangout_personality:['Museums and galleries','Coffee and conversation','Community events'],color:'#d9b8a5',birth_date:'1993-07-17'},
    {name:'Test Eli',email:'hangout-seed-05@example.com',bio:'Test profile: fitness, dogs, and exploring Makati.',interests:['Fitness','Dogs'],hangout_personality:['Sports and fitness','Walk and explore','Games and activities'],color:'#c6d0b8',birth_date:'1997-11-30'},
  ]

  const {data:userPage,error:listError}=await supabase.auth.admin.listUsers({page:1,perPage:1000})
  if(listError)throw new Error(`Could not check for existing seed accounts. ${listError.message}`)

  for(let index=0;index<seeds.length;index++){
    const seed=seeds[index]
    let user=userPage.users.find(candidate=>candidate.email===seed.email)
    if(!user){
      const {data,error}=await supabase.auth.admin.createUser({
        email:seed.email,
        password:randomBytes(32).toString('base64url'),
        email_confirm:true,
        user_metadata:{first_name:seed.name},
      })
      if(error)throw new Error(`Could not create ${seed.email}. ${error.message}`)
      user=data.user
    }

    const {error:profileError}=await supabase.from('profiles').upsert({
      id:user.id,
      first_name:seed.name,
      birth_date:seed.birth_date,
      bio:seed.bio,
      photo_url:avatarDataUrl(seed.name,seed.color),
      interests:seed.interests,
      hangout_personality:seed.hangout_personality,
      additional_photo_urls:[null,null],
    },{onConflict:'id'})
    if(profileError)throw new Error(`Could not seed profile for ${seed.email}. ${profileError.message}`)

    const {data:existingPin,error:pinReadError}=await supabase.from('profile_places')
      .select('place_id,position').eq('profile_id',user.id).maybeSingle()
    if(pinReadError)throw new Error(`Could not check places for ${seed.email}. ${pinReadError.message}`)
    if(!existingPin){
      const {error:pinError}=await supabase.from('profile_places').insert({
        profile_id:user.id,
        place_id:place.id,
        position:1,
      })
      if(pinError)throw new Error(`Could not pin Ayala Triangle Gardens for ${seed.email}. ${pinError.message}`)
    }else if(existingPin.place_id!==place.id){
      const {error:pinError}=await supabase.from('profile_places').update({place_id:place.id,position:1})
        .eq('profile_id',user.id).eq('place_id',existingPin.place_id)
      if(pinError)throw new Error(`Could not update the Makati pin for ${seed.email}. ${pinError.message}`)
    }

    console.log(`Seeded ${seed.name} (${seed.email})`)
  }

  console.log('Done. Five development test profiles share Ayala Triangle Gardens in Makati.')
  console.log('These accounts have random passwords that were not saved or printed; they are for discovery test data, not sign-in.')
}

main().catch(error=>{
  console.error(error instanceof Error?error.message:'Test data seeding failed.')
  process.exitCode=1
})
