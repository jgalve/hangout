alter table public.profiles
  drop constraint profiles_hangout_personality_allowed;

update public.profiles p
set hangout_personality = array(
  select case choice
    when 'Coffee and conversation' then 'Coffee'
    when 'Walk and explore' then 'Explore'
    when 'Food trip' then 'Foodie'
    when 'Live music' then 'Music'
    when 'Museums and galleries' then 'Culture'
    when 'Markets and pop-ups' then 'Markets'
    when 'Quiet parks' then 'Parks'
    when 'Sports and fitness' then 'Fitness'
    when 'Games and activities' then 'Games'
    when 'Beach or nature trips' then 'Nature'
    when 'Community events' then 'Community'
    else choice
  end
  from unnest(p.hangout_personality) with ordinality as choices(choice, ordinal)
  order by ordinal
)
where p.hangout_personality && array[
  'Coffee and conversation',
  'Walk and explore',
  'Food trip',
  'Live music',
  'Museums and galleries',
  'Markets and pop-ups',
  'Quiet parks',
  'Sports and fitness',
  'Games and activities',
  'Beach or nature trips',
  'Community events'
]::text[];

alter table public.profiles
  add constraint profiles_hangout_personality_allowed check (
    cardinality(hangout_personality) <= 5
    and hangout_personality <@ array[
      'Coffee',
      'Explore',
      'Foodie',
      'Music',
      'Culture',
      'Markets',
      'Parks',
      'Fitness',
      'Games',
      'Nightlife',
      'Nature',
      'Community'
    ]::text[]
    and array_position(hangout_personality, null) is null
  );
