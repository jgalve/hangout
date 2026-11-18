do $$
begin
  if to_regclass('public.profiles') is null
    or to_regclass('public.reports') is null
    or to_regclass('public.moderator_roles') is null
    or to_regclass('public.moderation_actions') is null
    or to_regclass('public.moderation_audit_log') is null then
    raise exception 'Migration 015 requires migrations 001 through 014 to be applied in order, including 008_moderation.sql.';
  end if;
end;
$$;

alter table public.profiles
  add column account_active boolean not null default true;

create table public.account_status_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  account_active boolean not null,
  reason text not null check (char_length(reason) between 3 and 500),
  created_at timestamptz not null default now()
);
create index account_status_events_user_created_idx
  on public.account_status_events(user_id, created_at desc);

alter table public.account_status_events enable row level security;
revoke all on public.account_status_events from anon, authenticated;
grant select on public.account_status_events to authenticated;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.moderator_roles mr
    join public.profiles p on p.id = mr.user_id
    where mr.user_id = auth.uid()
      and mr.role = 'admin'
      and p.account_active
  );
$$;

alter function public.is_admin() owner to postgres;
alter function public.is_admin() set search_path = public, pg_temp;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.moderator_roles mr
    join public.profiles p on p.id = mr.user_id
    where mr.user_id = auth.uid()
      and mr.role in ('moderator', 'admin')
      and p.account_active
  );
$$;

alter function public.is_moderator() owner to postgres;
alter function public.is_moderator() set search_path = public, pg_temp;
revoke all on function public.is_moderator() from public, anon;
grant execute on function public.is_moderator() to authenticated;

create function public.is_account_active()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.account_active
  );
$$;

alter function public.is_account_active() owner to postgres;
alter function public.is_account_active() set search_path = public, pg_temp;
revoke all on function public.is_account_active() from public, anon;
grant execute on function public.is_account_active() to authenticated;

drop policy if exists "account status events admins read" on public.account_status_events;
create policy "account status events admins read"
on public.account_status_events
for select
to authenticated
using (public.is_admin());

drop policy if exists "profiles owner update" on public.profiles;
drop policy if exists "profiles owner insert" on public.profiles;
create policy "profiles active owner insert"
on public.profiles
for insert
to authenticated
with check (id = auth.uid() and account_active and public.is_account_active());

create policy "profiles active owner update"
on public.profiles
for update
to authenticated
using (id = auth.uid() and account_active and public.is_account_active())
with check (id = auth.uid() and account_active and public.is_account_active());

drop policy if exists "places authenticated insert" on public.places;
create policy "active users add places"
on public.places
for insert
to authenticated
with check (public.is_account_active());

drop policy if exists "places authenticated update" on public.places;
create policy "active users update places"
on public.places
for update
to authenticated
using (public.is_account_active())
with check (public.is_account_active());

drop policy if exists "profile places owner insert" on public.profile_places;
create policy "profile places active owner insert"
on public.profile_places
for insert
to authenticated
with check (profile_id = auth.uid() and public.is_account_active());

drop policy if exists "profile places owner delete" on public.profile_places;
create policy "profile places active owner delete"
on public.profile_places
for delete
to authenticated
using (profile_id = auth.uid() and public.is_account_active());

drop policy if exists "swipes own" on public.swipes;
create policy "active users manage own swipes"
on public.swipes
for all
to authenticated
using (swiper_id = auth.uid() and public.is_account_active())
with check (
  swiper_id = auth.uid()
  and public.is_account_active()
);

drop policy if exists "blocks own" on public.blocks;
create policy "active users manage own blocks"
on public.blocks
for all
to authenticated
using (blocker_id = auth.uid() and public.is_account_active())
with check (blocker_id = auth.uid() and public.is_account_active());

drop policy if exists "profile photos owner upload" on storage.objects;
create policy "active profile photos owner upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_account_active()
);

drop policy if exists "profile photos owner update" on storage.objects;
create policy "active profile photos owner update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_account_active()
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_account_active()
);

drop policy if exists "profile photos owner delete" on storage.objects;
create policy "active profile photos owner delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_account_active()
);

create or replace function public.are_matched(match_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.matches m
    join public.profiles low_profile on low_profile.id = m.user_low
    join public.profiles high_profile on high_profile.id = m.user_high
    where m.id = match_uuid
      and auth.uid() in (m.user_low, m.user_high)
      and low_profile.account_active
      and high_profile.account_active
      and not public.is_blocked(m.user_low, m.user_high)
  );
$$;

alter function public.are_matched(uuid) owner to postgres;
alter function public.are_matched(uuid) set search_path = public, pg_temp;
revoke all on function public.are_matched(uuid) from public, anon;
grant execute on function public.are_matched(uuid) to authenticated;

alter function public.discover_candidates(int) rename to discover_candidates_before_admin;
revoke all on function public.discover_candidates_before_admin(int) from public, anon, authenticated;

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
  select candidates.*
  from public.discover_candidates_before_admin(limit_count) candidates
  join public.profiles p on p.id = candidates.id
  where public.is_account_active()
    and p.account_active;
$$;

alter function public.discover_candidates(int) owner to postgres;
alter function public.discover_candidates(int) set search_path = public, pg_temp;
revoke all on function public.discover_candidates(int) from public, anon;
grant execute on function public.discover_candidates(int) to authenticated;

alter function public.record_swipe(uuid, public.swipe_decision) rename to record_swipe_before_admin;
revoke all on function public.record_swipe_before_admin(uuid, public.swipe_decision) from public, anon, authenticated;

create function public.record_swipe(target uuid, choice public.swipe_decision)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_account_active()
    or not exists (
      select 1 from public.profiles p where p.id = target and p.account_active
    ) then
    raise exception 'This account is not available for discovery.';
  end if;

  return public.record_swipe_before_admin(target, choice);
end;
$$;

alter function public.record_swipe(uuid, public.swipe_decision) owner to postgres;
alter function public.record_swipe(uuid, public.swipe_decision) set search_path = public, pg_temp;
revoke all on function public.record_swipe(uuid, public.swipe_decision) from public, anon;
grant execute on function public.record_swipe(uuid, public.swipe_decision) to authenticated;

alter function public.list_matches() rename to list_matches_before_admin;
revoke all on function public.list_matches_before_admin() from public, anon, authenticated;

create function public.list_matches()
returns table(
  id uuid,
  other_user_id uuid,
  other_first_name text,
  other_photo_url text,
  shared_place_id uuid,
  shared_place_name text,
  created_at timestamptz,
  unread_count bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select matches.*
  from public.list_matches_before_admin() matches
  join public.profiles other_profile on other_profile.id = matches.other_user_id
  where public.is_account_active()
    and other_profile.account_active;
$$;

alter function public.list_matches() owner to postgres;
alter function public.list_matches() set search_path = public, pg_temp;
revoke all on function public.list_matches() from public, anon;
grant execute on function public.list_matches() to authenticated;

create function public.guard_active_reporter()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.reporter_id <> auth.uid() or not public.is_account_active() then
    raise exception 'This account cannot submit reports.';
  end if;
  return new;
end;
$$;

create trigger reports_require_active_reporter
before insert on public.reports
for each row execute function public.guard_active_reporter();

revoke all on function public.guard_active_reporter() from public, anon, authenticated;

alter table public.moderation_actions
  drop constraint moderation_actions_action_check,
  add constraint moderation_actions_action_check
    check (action in (
      'warn', 'restrict', 'suspend', 'ban', 'dismiss', 'request_information',
      'review', 'resolve'
    ));

create function public.admin_dashboard_stats()
returns table(
  total_users bigint,
  enabled_users bigint,
  new_users_30d bigint,
  matches_30d bigint,
  pending_reports bigint
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
    (select count(*) from public.profiles),
    (select count(*) from public.profiles p where p.account_active),
    (select count(*) from public.profiles p where p.created_at >= now() - interval '30 days'),
    (select count(*) from public.matches m where m.created_at >= now() - interval '30 days'),
    (select count(*) from public.reports r where r.status in ('open', 'reviewing'));
end;
$$;

alter function public.admin_dashboard_stats() owner to postgres;
alter function public.admin_dashboard_stats() set search_path = public, pg_temp;
revoke all on function public.admin_dashboard_stats() from public, anon;
grant execute on function public.admin_dashboard_stats() to authenticated;

create function public.admin_search_users(
  search_query text default '',
  limit_count integer default 25,
  offset_count integer default 0
)
returns table(
  id uuid,
  first_name text,
  email text,
  created_at timestamptz,
  account_active boolean,
  reports_received bigint
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
  if char_length(coalesce(search_query, '')) > 100 then
    raise exception 'Search text must be 100 characters or fewer.';
  end if;

  return query
  select
    p.id,
    p.first_name,
    u.email::text,
    p.created_at,
    p.account_active,
    (select count(*) from public.reports r where r.reported_id = p.id)
  from public.profiles p
  join auth.users u on u.id = p.id
  where coalesce(trim(search_query), '') = ''
     or strpos(lower(p.first_name), lower(trim(search_query))) > 0
     or strpos(lower(coalesce(u.email, '')), lower(trim(search_query))) > 0
  order by p.created_at desc, p.id
  limit greatest(1, least(coalesce(limit_count, 25), 50))
  offset greatest(coalesce(offset_count, 0), 0);
end;
$$;

alter function public.admin_search_users(text, integer, integer) owner to postgres;
alter function public.admin_search_users(text, integer, integer) set search_path = public, pg_temp;
revoke all on function public.admin_search_users(text, integer, integer) from public, anon;
grant execute on function public.admin_search_users(text, integer, integer) to authenticated;

create function public.moderator_report_queue(
  status_filter text default null,
  limit_count integer default 50
)
returns table(
  id uuid,
  reporter_id uuid,
  reporter_name text,
  reported_id uuid,
  reported_name text,
  reason text,
  details text,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderator access required.' using errcode = '42501';
  end if;
  if status_filter is not null and status_filter not in ('open', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Invalid report status.';
  end if;

  return query
  select r.id, r.reporter_id, reporter.first_name, r.reported_id, reported.first_name,
    r.reason, r.details, r.status::text, r.created_at
  from public.reports r
  join public.profiles reporter on reporter.id = r.reporter_id
  join public.profiles reported on reported.id = r.reported_id
  where status_filter is null or r.status::text = status_filter
  order by
    case r.status when 'open' then 0 when 'reviewing' then 1 else 2 end,
    r.created_at asc
  limit greatest(1, least(coalesce(limit_count, 50), 100));
end;
$$;

alter function public.moderator_report_queue(text, integer) owner to postgres;
alter function public.moderator_report_queue(text, integer) set search_path = public, pg_temp;
revoke all on function public.moderator_report_queue(text, integer) from public, anon;
grant execute on function public.moderator_report_queue(text, integer) to authenticated;

create function public.moderate_report(
  target_report_id uuid,
  next_status text,
  action_note text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  report_row public.reports%rowtype;
  action_name text;
  action_id uuid;
begin
  if not public.is_moderator() then
    raise exception 'Moderator access required.' using errcode = '42501';
  end if;
  if next_status is null or next_status not in ('reviewing', 'resolved', 'dismissed') then
    raise exception 'Choose a valid report status.';
  end if;
  if char_length(coalesce(action_note, '')) > 2000 then
    raise exception 'The moderation note must be 2,000 characters or fewer.';
  end if;

  select * into report_row
  from public.reports r
  where r.id = target_report_id
  for update;
  if not found then
    raise exception 'Report not found.';
  end if;

  action_name := case next_status
    when 'reviewing' then 'review'
    when 'resolved' then 'resolve'
    else 'dismiss'
  end;

  update public.reports
  set status = next_status::public.report_status
  where id = target_report_id;

  insert into public.moderation_actions (
    report_id, moderator_id, reported_id, action, note
  )
  values (
    report_row.id, auth.uid(), report_row.reported_id, action_name, coalesce(action_note, '')
  )
  returning id into action_id;

  return action_id;
end;
$$;

alter function public.moderate_report(uuid, text, text) owner to postgres;
alter function public.moderate_report(uuid, text, text) set search_path = public, pg_temp;
revoke all on function public.moderate_report(uuid, text, text) from public, anon;
grant execute on function public.moderate_report(uuid, text, text) to authenticated;

create function public.admin_set_account_active(
  target_user_id uuid,
  next_active boolean,
  action_reason text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_active boolean;
  target_role text;
  active_admin_count bigint;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(1597463001);
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  if target_user_id is null or next_active is null then
    raise exception 'Choose a user and account status.';
  end if;
  if char_length(btrim(coalesce(action_reason, ''))) not between 3 and 500 then
    raise exception 'Provide a reason between 3 and 500 characters.';
  end if;
  if target_user_id = auth.uid() and not next_active then
    raise exception 'You cannot deactivate your own admin account.';
  end if;

  select p.account_active into current_active
  from public.profiles p
  where p.id = target_user_id
  for update;
  if not found then
    raise exception 'User not found.';
  end if;

  select mr.role into target_role
  from public.moderator_roles mr
  where mr.user_id = target_user_id;

  if target_role = 'admin' and not next_active then
    select count(*) into active_admin_count
    from public.moderator_roles mr
    join public.profiles p on p.id = mr.user_id
    where mr.role = 'admin' and p.account_active;
    if active_admin_count <= 1 then
      raise exception 'The last active admin cannot be deactivated.';
    end if;
  end if;

  if current_active is distinct from next_active then
    update public.profiles
    set account_active = next_active
    where id = target_user_id;

    insert into public.account_status_events (
      user_id, actor_id, account_active, reason
    )
    values (
      target_user_id, auth.uid(), next_active, btrim(action_reason)
    );
  end if;

  return next_active;
end;
$$;

alter function public.admin_set_account_active(uuid, boolean, text) owner to postgres;
alter function public.admin_set_account_active(uuid, boolean, text) set search_path = public, pg_temp;
revoke all on function public.admin_set_account_active(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_account_active(uuid, boolean, text) to authenticated;

create function public.prevent_account_status_event_mutation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception 'Account status events are immutable.';
end;
$$;

create trigger account_status_events_immutable
before update or delete on public.account_status_events
for each row execute function public.prevent_account_status_event_mutation();

create trigger account_status_events_no_truncate
before truncate on public.account_status_events
for each statement execute function public.prevent_account_status_event_mutation();

revoke all on function public.prevent_account_status_event_mutation() from public, anon, authenticated;
