create table public.featured_hangout_settings (
  singleton boolean primary key default true check (singleton),
  place_id uuid not null references public.places(id) on delete restrict,
  venue_name text not null check (char_length(btrim(venue_name)) between 2 and 120),
  promo_title text not null check (char_length(btrim(promo_title)) between 3 and 120),
  promo_description text not null check (char_length(btrim(promo_description)) between 10 and 500),
  promo_terms text not null check (char_length(btrim(promo_terms)) between 3 and 1000),
  photo_url text check (
    photo_url is null
    or (char_length(photo_url) <= 2048 and lower(photo_url) ~ '^https://[^/[:space:]]+([/?#][^[:space:]]*)?$')
  ),
  promo_cta_label text check (promo_cta_label is null or char_length(btrim(promo_cta_label)) between 2 and 60),
  promo_cta_url text check (
    promo_cta_url is null
    or (char_length(promo_cta_url) <= 2048 and lower(promo_cta_url) ~ '^https://[^/[:space:]]+([/?#][^[:space:]]*)?$')
  ),
  demo_only boolean not null default true,
  is_published boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint featured_hangout_cta_pair_check
    check ((promo_cta_label is null) = (promo_cta_url is null))
);

alter table public.featured_hangout_settings enable row level security;
revoke all on public.featured_hangout_settings from public, anon, authenticated;

insert into public.places (osm_type, osm_id, name, display_name, lat, lon)
values (
  'way',
  '32978383',
  'Solaire Resort & Casino',
  'Solaire Resort & Casino, 1 Asean Avenue, Parañaque',
  14.5225354,
  120.98233565
)
on conflict (osm_type, osm_id) do nothing;

insert into public.featured_hangout_settings (
  singleton, place_id, venue_name, promo_title, promo_description, promo_terms,
  photo_url, promo_cta_label, promo_cta_url, demo_only, is_published
) select
  true,
  place.id,
  'Solaire Pasay',
  'Sample: Date Night for Two',
  'A demo concept for a shared evening out. No discount, package, or venue benefit has been confirmed.',
  'SAMPLE ONLY. This is not a real Solaire Pasay offer, is not redeemable, and is not affiliated with the venue.',
  null,
  null,
  null,
  true,
  true
from public.places place
where place.osm_type = 'way'
  and place.osm_id = '32978383'
on conflict (singleton) do nothing;

create function public.get_featured_hangout()
returns table(
  place_id uuid,
  osm_type text,
  osm_id text,
  venue_name text,
  promo_title text,
  promo_description text,
  promo_terms text,
  photo_url text,
  promo_cta_label text,
  promo_cta_url text,
  demo_only boolean,
  is_published boolean,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    featured.place_id,
    place.osm_type,
    place.osm_id,
    featured.venue_name,
    featured.promo_title,
    featured.promo_description,
    featured.promo_terms,
    featured.photo_url,
    featured.promo_cta_label,
    featured.promo_cta_url,
    featured.demo_only,
    featured.is_published,
    featured.updated_at
  from public.featured_hangout_settings featured
  join public.places place on place.id = featured.place_id
  where featured.singleton
    and featured.is_published
    and public.is_account_active();
$$;

alter function public.get_featured_hangout() owner to postgres;
alter function public.get_featured_hangout() set search_path = public, pg_temp;
revoke all on function public.get_featured_hangout() from public, anon;
grant execute on function public.get_featured_hangout() to authenticated;

create function public.admin_get_featured_hangout()
returns table(
  place_id uuid,
  osm_type text,
  osm_id text,
  venue_name text,
  promo_title text,
  promo_description text,
  promo_terms text,
  photo_url text,
  promo_cta_label text,
  promo_cta_url text,
  demo_only boolean,
  is_published boolean,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  return query
  select
    featured.place_id,
    place.osm_type,
    place.osm_id,
    featured.venue_name,
    featured.promo_title,
    featured.promo_description,
    featured.promo_terms,
    featured.photo_url,
    featured.promo_cta_label,
    featured.promo_cta_url,
    featured.demo_only,
    featured.is_published,
    featured.updated_at
  from public.featured_hangout_settings featured
  join public.places place on place.id = featured.place_id
  where featured.singleton;
end;
$$;

alter function public.admin_get_featured_hangout() owner to postgres;
alter function public.admin_get_featured_hangout() set search_path = public, pg_temp;
revoke all on function public.admin_get_featured_hangout() from public, anon;
grant execute on function public.admin_get_featured_hangout() to authenticated;

create function public.admin_save_featured_hangout(
  p_place_id uuid,
  p_venue_name text,
  p_promo_title text,
  p_promo_description text,
  p_promo_terms text,
  p_photo_url text,
  p_promo_cta_label text,
  p_promo_cta_url text,
  p_demo_only boolean,
  p_is_published boolean
)
returns table(
  place_id uuid,
  osm_type text,
  osm_id text,
  venue_name text,
  promo_title text,
  promo_description text,
  promo_terms text,
  photo_url text,
  promo_cta_label text,
  promo_cta_url text,
  demo_only boolean,
  is_published boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  if p_place_id is null or not exists (
    select 1 from public.places where id = p_place_id
  ) then
    raise exception 'Select a valid place from the place catalog.';
  end if;

  p_venue_name := btrim(p_venue_name);
  p_promo_title := btrim(p_promo_title);
  p_promo_description := btrim(p_promo_description);
  p_promo_terms := btrim(p_promo_terms);
  p_photo_url := nullif(btrim(p_photo_url), '');
  p_promo_cta_label := nullif(btrim(p_promo_cta_label), '');
  p_promo_cta_url := nullif(btrim(p_promo_cta_url), '');

  if p_venue_name is null
    or p_promo_title is null
    or p_promo_description is null
    or p_promo_terms is null
    or p_demo_only is null
    or p_is_published is null
    or char_length(p_venue_name) not between 2 and 120
    or char_length(p_promo_title) not between 3 and 120
    or char_length(p_promo_description) not between 10 and 500
    or char_length(p_promo_terms) not between 3 and 1000 then
    raise exception 'Check the required text lengths before saving.';
  end if;

  if p_photo_url is not null
    and (char_length(p_photo_url) > 2048 or lower(p_photo_url) !~ '^https://[^/[:space:]]+([/?#][^[:space:]]*)?$') then
    raise exception 'Photo URL must be a valid HTTPS URL.';
  end if;

  if (p_promo_cta_label is null) <> (p_promo_cta_url is null) then
    raise exception 'Provide both a call-to-action label and URL, or leave both blank.';
  end if;

  if p_promo_cta_label is not null and char_length(p_promo_cta_label) not between 2 and 60 then
    raise exception 'Call-to-action label must be between 2 and 60 characters.';
  end if;

  if p_promo_cta_url is not null
    and (char_length(p_promo_cta_url) > 2048 or lower(p_promo_cta_url) !~ '^https://[^/[:space:]]+([/?#][^[:space:]]*)?$') then
    raise exception 'Call-to-action URL must be a valid HTTPS URL.';
  end if;

  insert into public.featured_hangout_settings (
    singleton, place_id, venue_name, promo_title, promo_description, promo_terms,
    photo_url, promo_cta_label, promo_cta_url, demo_only, is_published, updated_by, updated_at
  ) values (
    true, p_place_id, p_venue_name, p_promo_title, p_promo_description, p_promo_terms,
    p_photo_url, p_promo_cta_label, p_promo_cta_url, p_demo_only, p_is_published, auth.uid(), now()
  )
  on conflict (singleton) do update set
    place_id = excluded.place_id,
    venue_name = excluded.venue_name,
    promo_title = excluded.promo_title,
    promo_description = excluded.promo_description,
    promo_terms = excluded.promo_terms,
    photo_url = excluded.photo_url,
    promo_cta_label = excluded.promo_cta_label,
    promo_cta_url = excluded.promo_cta_url,
    demo_only = excluded.demo_only,
    is_published = excluded.is_published,
    updated_by = excluded.updated_by,
    updated_at = excluded.updated_at;

  return query
  select
    saved.place_id,
    place.osm_type,
    place.osm_id,
    saved.venue_name,
    saved.promo_title,
    saved.promo_description,
    saved.promo_terms,
    saved.photo_url,
    saved.promo_cta_label,
    saved.promo_cta_url,
    saved.demo_only,
    saved.is_published,
    saved.updated_at
  from public.featured_hangout_settings saved
  join public.places place on place.id = saved.place_id
  where saved.singleton;
end;
$$;

alter function public.admin_save_featured_hangout(uuid, text, text, text, text, text, text, text, boolean, boolean) owner to postgres;
alter function public.admin_save_featured_hangout(uuid, text, text, text, text, text, text, text, boolean, boolean) set search_path = public, pg_temp;
revoke all on function public.admin_save_featured_hangout(uuid, text, text, text, text, text, text, text, boolean, boolean) from public, anon;
grant execute on function public.admin_save_featured_hangout(uuid, text, text, text, text, text, text, text, boolean, boolean) to authenticated;
