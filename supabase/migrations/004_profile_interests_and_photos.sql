alter table public.profiles
  add column interests text[] not null default '{}',
  add constraint profiles_interests_limit check (cardinality(interests) <= 5),
  add constraint profiles_interests_allowed check (
    interests <@ array[
      'Coffee',
      'Live music',
      'Outdoors',
      'Food spots',
      'Books',
      'Art & culture',
      'Fitness',
      'Markets',
      'Movies',
      'Board games',
      'Dogs'
    ]::text[]
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', true, 8388608, array['image/jpeg'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "profile photos owner read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "profile photos owner upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "profile photos owner update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "profile photos owner delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop function public.discover_candidates(int);

create function public.discover_candidates(limit_count int default 20)
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

grant execute on function public.discover_candidates(int) to authenticated;
