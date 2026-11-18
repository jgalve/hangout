-- HangOut Phase 1: accounts, profiles and pinned places
create extension if not exists pgcrypto;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null check (char_length(first_name) between 1 and 50),
  birth_date date check (birth_date <= current_date - interval '18 years'),
  bio text not null default '' check (char_length(bio) <= 280),
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  osm_type text not null,
  osm_id text not null,
  name text not null,
  display_name text not null,
  lat double precision not null,
  lon double precision not null,
  created_at timestamptz not null default now(),
  unique(osm_type,osm_id)
);
create table if not exists public.profile_places (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  position smallint not null check(position between 1 and 5),
  created_at timestamptz not null default now(),
  primary key(profile_id,place_id), unique(profile_id,position)
);
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,first_name) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'first_name',''),'Member'));return new;end;$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
alter table public.profiles enable row level security;
alter table public.places enable row level security;
alter table public.profile_places enable row level security;
create policy "profiles owner read" on public.profiles for select to authenticated using ((select auth.uid())=id);
create policy "profiles owner insert" on public.profiles for insert to authenticated with check ((select auth.uid())=id);
create policy "profiles owner update" on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);
create policy "places authenticated read" on public.places for select to authenticated using (true);
create policy "places authenticated insert" on public.places for insert to authenticated with check (true);
create policy "places authenticated update" on public.places for update to authenticated using (true) with check (true);
create policy "profile places owner read" on public.profile_places for select to authenticated using ((select auth.uid())=profile_id);
create policy "profile places owner insert" on public.profile_places for insert to authenticated with check ((select auth.uid())=profile_id and (select count(*) from public.profile_places pp where pp.profile_id=(select auth.uid()))<5);
create policy "profile places owner delete" on public.profile_places for delete to authenticated using ((select auth.uid())=profile_id);
grant usage on schema public to authenticated;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,update on public.places to authenticated;
grant select,insert,delete on public.profile_places to authenticated;
