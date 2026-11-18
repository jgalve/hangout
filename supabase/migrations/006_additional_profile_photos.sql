alter table public.profiles
  add column additional_photo_urls text[] not null default array[null, null]::text[],
  add constraint profiles_additional_photo_slots check (cardinality(additional_photo_urls) = 2);

drop function public.discover_candidates(int);

create function public.discover_candidates(limit_count int default 20)
returns table(
  id uuid,
  first_name text,
  bio text,
  photo_url text,
  interests text[],
  additional_photo_urls text[],
  shared_place_id uuid,
  shared_place_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.first_name,
    p.bio,
    p.photo_url,
    p.interests,
    p.additional_photo_urls,
    pl.id,
    pl.name
  from profiles p
  join profile_places theirs on theirs.profile_id = p.id
  join profile_places mine on mine.place_id = theirs.place_id and mine.profile_id = auth.uid()
  join places pl on pl.id = mine.place_id
  where p.id <> auth.uid()
    and p.birth_date is not null
    and p.photo_url is not null
    and not exists (
      select 1
      from swipes s
      where s.swiper_id = auth.uid() and s.target_id = p.id
    )
    and not public.is_blocked(auth.uid(), p.id)
  group by
    p.id,
    p.first_name,
    p.bio,
    p.photo_url,
    p.interests,
    p.additional_photo_urls,
    pl.id,
    pl.name
  order by count(*) over (partition by p.id) desc, p.created_at desc
  limit greatest(1, least(limit_count, 50));
$$;

grant execute on function public.discover_candidates(int) to authenticated;
