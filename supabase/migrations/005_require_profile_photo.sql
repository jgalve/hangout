drop policy if exists "profiles owner insert" on public.profiles;
create policy "profiles owner insert"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id and photo_url is not null);

drop policy if exists "profiles owner update" on public.profiles;
create policy "profiles owner update"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id and photo_url is not null);

create or replace function public.discover_candidates(limit_count int default 20)
returns table(
  id uuid,
  first_name text,
  bio text,
  photo_url text,
  interests text[],
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
  group by p.id, p.first_name, p.bio, p.photo_url, p.interests, pl.id, pl.name
  order by count(*) over (partition by p.id) desc, p.created_at desc
  limit greatest(1, least(limit_count, 50));
$$;

create or replace function public.record_swipe(target uuid, choice public.swipe_decision)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  match_id uuid;
  low_id uuid;
  high_id uuid;
  common_place uuid;
begin
  if not exists (
    select 1 from profiles p
    where p.id = auth.uid() and p.photo_url is not null
  ) then
    raise exception 'Add a profile photo before discovering people.';
  end if;

  if target = auth.uid() or public.is_blocked(auth.uid(), target) then
    raise exception 'Invalid swipe target';
  end if;

  if not exists (
    select 1 from profiles p
    where p.id = target and p.photo_url is not null
  ) then
    raise exception 'This person is not available to discover.';
  end if;

  insert into swipes(swiper_id, target_id, decision)
  values(auth.uid(), target, choice)
  on conflict(swiper_id, target_id)
  do update set decision = excluded.decision, created_at = now();

  if choice = 'like' and exists (
    select 1 from swipes
    where swiper_id = target and target_id = auth.uid() and decision = 'like'
  ) then
    low_id := least(auth.uid(), target);
    high_id := greatest(auth.uid(), target);
    select mine.place_id into common_place
    from profile_places mine
    join profile_places theirs using(place_id)
    where mine.profile_id = auth.uid() and theirs.profile_id = target
    order by mine.position
    limit 1;

    insert into matches(user_low, user_high, shared_place_id)
    values(low_id, high_id, common_place)
    on conflict(user_low, user_high)
    do update set shared_place_id = coalesce(matches.shared_place_id, excluded.shared_place_id)
    returning id into match_id;
  end if;

  return match_id;
end;
$$;
