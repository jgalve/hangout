alter table public.profiles
  add column hangout_personality text[] not null default '{}',
  add constraint profiles_hangout_personality_allowed check (
    cardinality(hangout_personality) <= 5
    and hangout_personality <@ array[
      'Coffee and conversation',
      'Walk and explore',
      'Food trip',
      'Live music',
      'Museums and galleries',
      'Markets and pop-ups',
      'Quiet parks',
      'Sports and fitness',
      'Games and activities',
      'Nightlife',
      'Beach or nature trips',
      'Community events'
    ]::text[]
    and array_position(hangout_personality, null) is null
  );

create function public.validate_hangout_personality()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  unique_choices integer;
begin
  if tg_op = 'UPDATE' and new.hangout_personality is not distinct from old.hangout_personality then
    return new;
  end if;

  if cardinality(new.hangout_personality) = 0 then
    if tg_op = 'INSERT' then
      return new;
    end if;
  else
    select count(distinct choice)
      into unique_choices
      from unnest(new.hangout_personality) as choices(choice);

    if cardinality(new.hangout_personality) not between 3 and 5
      or unique_choices <> cardinality(new.hangout_personality) then
      raise exception 'Choose 3 to 5 unique hangout personalities.'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.validate_hangout_personality() from public, anon, authenticated;

create trigger profiles_validate_hangout_personality
before insert or update on public.profiles
for each row execute function public.validate_hangout_personality();

drop function public.discover_candidates(int);

create function public.discover_candidates(limit_count int default 20)
returns table(
  id uuid,
  first_name text,
  bio text,
  photo_url text,
  hangout_personality text[],
  additional_photo_urls text[],
  dating_intention text,
  gender_identity text,
  gender_identity_detail text,
  age integer,
  zodiac_sign text,
  shared_places jsonb
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    p.id,
    p.first_name,
    p.bio,
    p.photo_url,
    p.hangout_personality,
    p.additional_photo_urls,
    p.dating_intention,
    p.gender_identity,
    p.gender_identity_detail,
    extract(year from age(current_date, p.birth_date))::integer,
    case
      when (extract(month from p.birth_date) = 1 and extract(day from p.birth_date) >= 20)
        or (extract(month from p.birth_date) = 2 and extract(day from p.birth_date) <= 18) then 'Aquarius'
      when (extract(month from p.birth_date) = 2 and extract(day from p.birth_date) >= 19)
        or (extract(month from p.birth_date) = 3 and extract(day from p.birth_date) <= 20) then 'Pisces'
      when (extract(month from p.birth_date) = 3 and extract(day from p.birth_date) >= 21)
        or (extract(month from p.birth_date) = 4 and extract(day from p.birth_date) <= 20) then 'Aries'
      when (extract(month from p.birth_date) = 4 and extract(day from p.birth_date) >= 21)
        or (extract(month from p.birth_date) = 5 and extract(day from p.birth_date) <= 20) then 'Taurus'
      when (extract(month from p.birth_date) = 5 and extract(day from p.birth_date) >= 21)
        or (extract(month from p.birth_date) = 6 and extract(day from p.birth_date) <= 20) then 'Gemini'
      when (extract(month from p.birth_date) = 6 and extract(day from p.birth_date) >= 21)
        or (extract(month from p.birth_date) = 7 and extract(day from p.birth_date) <= 22) then 'Cancer'
      when (extract(month from p.birth_date) = 7 and extract(day from p.birth_date) >= 23)
        or (extract(month from p.birth_date) = 8 and extract(day from p.birth_date) <= 22) then 'Leo'
      when (extract(month from p.birth_date) = 8 and extract(day from p.birth_date) >= 23)
        or (extract(month from p.birth_date) = 9 and extract(day from p.birth_date) <= 22) then 'Virgo'
      when (extract(month from p.birth_date) = 9 and extract(day from p.birth_date) >= 23)
        or (extract(month from p.birth_date) = 10 and extract(day from p.birth_date) <= 22) then 'Libra'
      when (extract(month from p.birth_date) = 10 and extract(day from p.birth_date) >= 23)
        or (extract(month from p.birth_date) = 11 and extract(day from p.birth_date) <= 21) then 'Scorpio'
      when (extract(month from p.birth_date) = 11 and extract(day from p.birth_date) >= 22)
        or (extract(month from p.birth_date) = 12 and extract(day from p.birth_date) <= 21) then 'Sagittarius'
      else 'Capricorn'
    end,
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', pl.id,
          'name', pl.name,
          'story', theirs.place_story
        )
        order by mine.position
      )
      from public.profile_places theirs
      join public.profile_places mine
        on mine.place_id = theirs.place_id
       and mine.profile_id = viewer.id
      join public.places pl on pl.id = mine.place_id
      where theirs.profile_id = p.id
    )
  from public.profiles p
  join public.profiles viewer on viewer.id = auth.uid()
  where p.id <> viewer.id
    and p.birth_date is not null
    and p.photo_url is not null
    and cardinality(p.hangout_personality) between 3 and 5
    and cardinality(viewer.hangout_personality) between 3 and 5
    and exists (
      select 1
      from public.profile_places theirs
      join public.profile_places mine
        on mine.place_id = theirs.place_id
       and mine.profile_id = viewer.id
      where theirs.profile_id = p.id
    )
    and (
      viewer.open_to_all_genders
      or p.gender_identity is null
      or p.gender_identity = any(viewer.interested_in_genders)
    )
    and (
      p.open_to_all_genders
      or viewer.gender_identity is null
      or viewer.gender_identity = any(p.interested_in_genders)
    )
    and not exists (
      select 1
      from public.swipes s
      where s.swiper_id = viewer.id and s.target_id = p.id
    )
    and not public.is_blocked(viewer.id, p.id)
  order by (
    select count(*)
    from public.profile_places theirs
    join public.profile_places mine
      on mine.place_id = theirs.place_id
     and mine.profile_id = viewer.id
    where theirs.profile_id = p.id
  ) desc, p.created_at desc
  limit greatest(1, least(limit_count, 50));
$$;

alter function public.discover_candidates(int) owner to postgres;
alter function public.discover_candidates(int) set search_path = public, pg_temp;
revoke all on function public.discover_candidates(int) from public, anon;
grant execute on function public.discover_candidates(int) to authenticated;
