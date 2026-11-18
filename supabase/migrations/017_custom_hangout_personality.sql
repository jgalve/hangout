alter table public.profiles
  add column custom_hangout_personality text,
  add constraint profiles_custom_hangout_personality_valid check (
    custom_hangout_personality is null
    or (
      custom_hangout_personality = btrim(custom_hangout_personality)
      and char_length(custom_hangout_personality) between 1 and 30
      and custom_hangout_personality !~ '[[:space:]]'
      and lower(custom_hangout_personality) <> all (array[
        'coffee',
        'explore',
        'foodie',
        'music',
        'culture',
        'markets',
        'parks',
        'fitness',
        'games',
        'nightlife',
        'nature',
        'community'
      ]::text[])
    )
  );

drop function public.discover_candidates(int);

create function public.discover_candidates(limit_count int default 20)
returns table(
  id uuid,
  first_name text,
  bio text,
  photo_url text,
  hangout_personality text[],
  custom_hangout_personality text,
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
    candidates.id,
    candidates.first_name,
    candidates.bio,
    candidates.photo_url,
    candidates.hangout_personality,
    p.custom_hangout_personality,
    candidates.additional_photo_urls,
    candidates.dating_intention,
    candidates.gender_identity,
    candidates.gender_identity_detail,
    candidates.age,
    candidates.zodiac_sign,
    candidates.shared_places
  from public.discover_candidates_before_admin(limit_count) candidates
  join public.profiles p on p.id = candidates.id
  where public.is_account_active()
    and p.account_active;
$$;

alter function public.discover_candidates(int) owner to postgres;
alter function public.discover_candidates(int) set search_path = public, pg_temp;
revoke all on function public.discover_candidates(int) from public, anon;
grant execute on function public.discover_candidates(int) to authenticated;
