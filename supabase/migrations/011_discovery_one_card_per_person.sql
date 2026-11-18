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
       and mine.profile_id = auth.uid()
      join public.places pl on pl.id = mine.place_id
      where theirs.profile_id = p.id
    )
  from public.profiles p
  where p.id <> auth.uid()
    and p.birth_date is not null
    and p.photo_url is not null
    and exists (
      select 1
      from public.profile_places theirs
      join public.profile_places mine
        on mine.place_id = theirs.place_id
       and mine.profile_id = auth.uid()
      where theirs.profile_id = p.id
    )
    and not exists (
      select 1
      from public.swipes s
      where s.swiper_id = auth.uid() and s.target_id = p.id
    )
    and not public.is_blocked(auth.uid(), p.id)
  order by (
    select count(*)
    from public.profile_places theirs
    join public.profile_places mine
      on mine.place_id = theirs.place_id
     and mine.profile_id = auth.uid()
    where theirs.profile_id = p.id
  ) desc, p.created_at desc
  limit greatest(1, least(limit_count, 50));
$$;

alter function public.discover_candidates(int) owner to postgres;
alter function public.discover_candidates(int) set search_path = public, pg_temp;
revoke all on function public.discover_candidates(int) from public, anon;
grant execute on function public.discover_candidates(int) to authenticated;
