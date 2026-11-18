create function public.get_match_profile(match_uuid uuid)
returns table(
  id uuid,
  first_name text,
  age integer,
  zodiac_sign text,
  bio text,
  photo_url text,
  hangout_personality text[],
  custom_hangout_personality text,
  additional_photo_urls text[],
  dating_intention text,
  gender_identity text,
  gender_identity_detail text,
  shared_places jsonb,
  is_verified boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    other_profile.id,
    other_profile.first_name,
    case
      when other_profile.birth_date is not null
        then extract(year from age(current_date, other_profile.birth_date))::integer
    end,
    case when other_profile.birth_date is null then null else case
      when (extract(month from other_profile.birth_date) = 1 and extract(day from other_profile.birth_date) >= 20)
        or (extract(month from other_profile.birth_date) = 2 and extract(day from other_profile.birth_date) <= 18) then 'Aquarius'
      when (extract(month from other_profile.birth_date) = 2 and extract(day from other_profile.birth_date) >= 19)
        or (extract(month from other_profile.birth_date) = 3 and extract(day from other_profile.birth_date) <= 20) then 'Pisces'
      when (extract(month from other_profile.birth_date) = 3 and extract(day from other_profile.birth_date) >= 21)
        or (extract(month from other_profile.birth_date) = 4 and extract(day from other_profile.birth_date) <= 20) then 'Aries'
      when (extract(month from other_profile.birth_date) = 4 and extract(day from other_profile.birth_date) >= 21)
        or (extract(month from other_profile.birth_date) = 5 and extract(day from other_profile.birth_date) <= 20) then 'Taurus'
      when (extract(month from other_profile.birth_date) = 5 and extract(day from other_profile.birth_date) >= 21)
        or (extract(month from other_profile.birth_date) = 6 and extract(day from other_profile.birth_date) <= 20) then 'Gemini'
      when (extract(month from other_profile.birth_date) = 6 and extract(day from other_profile.birth_date) >= 21)
        or (extract(month from other_profile.birth_date) = 7 and extract(day from other_profile.birth_date) <= 22) then 'Cancer'
      when (extract(month from other_profile.birth_date) = 7 and extract(day from other_profile.birth_date) >= 23)
        or (extract(month from other_profile.birth_date) = 8 and extract(day from other_profile.birth_date) <= 22) then 'Leo'
      when (extract(month from other_profile.birth_date) = 8 and extract(day from other_profile.birth_date) >= 23)
        or (extract(month from other_profile.birth_date) = 9 and extract(day from other_profile.birth_date) <= 22) then 'Virgo'
      when (extract(month from other_profile.birth_date) = 9 and extract(day from other_profile.birth_date) >= 23)
        or (extract(month from other_profile.birth_date) = 10 and extract(day from other_profile.birth_date) <= 22) then 'Libra'
      when (extract(month from other_profile.birth_date) = 10 and extract(day from other_profile.birth_date) >= 23)
        or (extract(month from other_profile.birth_date) = 11 and extract(day from other_profile.birth_date) <= 21) then 'Scorpio'
      when (extract(month from other_profile.birth_date) = 11 and extract(day from other_profile.birth_date) >= 22)
        or (extract(month from other_profile.birth_date) = 12 and extract(day from other_profile.birth_date) <= 21) then 'Sagittarius'
      else 'Capricorn'
    end end,
    other_profile.bio,
    other_profile.photo_url,
    other_profile.hangout_personality,
    other_profile.custom_hangout_personality,
    other_profile.additional_photo_urls,
    other_profile.dating_intention,
    other_profile.gender_identity,
    other_profile.gender_identity_detail,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', place.id,
          'name', place.name,
          'story', other_place.place_story
        )
        order by viewer_place.position
      )
      from public.profile_places other_place
      join public.profile_places viewer_place
        on viewer_place.place_id = other_place.place_id
       and viewer_place.profile_id = auth.uid()
      join public.places place on place.id = viewer_place.place_id
      where other_place.profile_id = other_profile.id
    ), '[]'::jsonb),
    exists (
      select 1
      from public.identity_verification_requests verification
      where verification.user_id = other_profile.id
        and verification.status = 'verified'
        and verification.storage_path is null
    )
  from public.matches matched
  join public.profiles other_profile
    on other_profile.id = case
      when matched.user_low = auth.uid() then matched.user_high
      else matched.user_low
    end
  where matched.id = match_uuid
    and auth.uid() in (matched.user_low, matched.user_high)
    and public.is_account_active()
    and other_profile.account_active
    and not public.is_blocked(matched.user_low, matched.user_high);
$$;

alter function public.get_match_profile(uuid) owner to postgres;
alter function public.get_match_profile(uuid) set search_path = public, pg_temp;
revoke all on function public.get_match_profile(uuid) from public, anon;
grant execute on function public.get_match_profile(uuid) to authenticated;
