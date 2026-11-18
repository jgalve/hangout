alter table public.profiles
  add column gender_identity text
    check (gender_identity is null or gender_identity in ('woman', 'man', 'non_binary', 'self_described')),
  add column gender_identity_detail text,
  add column interested_in_genders text[] not null default '{}'
    check (
      cardinality(interested_in_genders) <= 4
      and interested_in_genders <@ array['woman', 'man', 'non_binary', 'self_described']::text[]
      and array_position(interested_in_genders, null) is null
    ),
  add column open_to_all_genders boolean not null default true,
  add constraint profiles_gender_identity_detail_check check (
    (
      gender_identity = 'self_described'
      and gender_identity_detail is not null
      and char_length(btrim(gender_identity_detail)) between 1 and 50
    )
    or (
      gender_identity is distinct from 'self_described'
      and gender_identity_detail is null
    )
  ),
  add constraint profiles_gender_preference_check check (
    (open_to_all_genders and cardinality(interested_in_genders) = 0)
    or (not open_to_all_genders and cardinality(interested_in_genders) > 0)
  );

drop function public.discover_candidates(int);

create function public.discover_candidates(limit_count int default 20)
returns table(
  id uuid,
  first_name text,
  bio text,
  photo_url text,
  interests text[],
  additional_photo_urls text[],
  dating_intention text,
  gender_identity text,
  gender_identity_detail text,
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
    p.interests,
    p.additional_photo_urls,
    p.dating_intention,
    p.gender_identity,
    p.gender_identity_detail,
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
