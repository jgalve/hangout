begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('identity-documents', 'identity-documents', false, 8388608, array['image/jpeg'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create table public.identity_verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text unique
    check (storage_path is null or storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'),
  status text not null check (status in ('uploading', 'pending', 'verified', 'rejected', 'withdrawn')),
  consented_at timestamptz not null default now(),
  consent_version text not null,
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  decided_at timestamptz,
  reviewer_id uuid references auth.users(id) on delete set null,
  image_deleted_at timestamptz,
  check ((storage_path is null) = (image_deleted_at is not null)),
  check (
    (status = 'uploading' and submitted_at is null and decided_at is null and reviewer_id is null)
    or (status = 'pending' and submitted_at is not null and decided_at is null and reviewer_id is null)
    or (status in ('verified', 'rejected') and submitted_at is not null and decided_at is not null and reviewer_id is not null)
    or (status = 'withdrawn' and decided_at is not null and reviewer_id is null)
  )
);

create unique index identity_verification_one_open_user_idx
  on public.identity_verification_requests(user_id)
  where status in ('uploading', 'pending');
create index identity_verification_review_queue_idx
  on public.identity_verification_requests(submitted_at)
  where status = 'pending';
create index identity_verification_cleanup_idx
  on public.identity_verification_requests(storage_path)
  where storage_path is not null;

create table public.identity_verification_events (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.identity_verification_requests(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event text not null check (event in ('upload_started', 'submitted', 'verified', 'rejected', 'withdrawn', 'image_deleted')),
  created_at timestamptz not null default now()
);

alter table public.identity_verification_requests enable row level security;
alter table public.identity_verification_events enable row level security;
revoke all on public.identity_verification_requests from public, anon, authenticated;
revoke all on public.identity_verification_events from anon, authenticated;
grant select on public.identity_verification_events to authenticated;

create policy "moderators read identity verification events"
on public.identity_verification_events
for select
to authenticated
using (public.is_moderator());

create function public.can_upload_identity_file(file_path text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
    and public.is_account_active()
    and exists (
      select 1
      from public.identity_verification_requests r
      where r.user_id = auth.uid()
        and r.storage_path = file_path
        and r.status = 'uploading'
    );
$$;

create function public.can_review_identity_file(file_path text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_moderator()
    and exists (
      select 1
      from public.identity_verification_requests r
      where r.storage_path = file_path
        and r.user_id <> auth.uid()
        and r.status = 'pending'
    );
$$;

create function public.can_delete_identity_file(file_path text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
      select 1
      from public.identity_verification_requests r
      where r.storage_path = file_path
        and r.user_id = auth.uid()
        and r.status in ('uploading', 'withdrawn')
    )
    or (
      public.is_moderator()
      and exists (
        select 1
        from public.identity_verification_requests r
        where r.storage_path = file_path
          and r.user_id <> auth.uid()
          and r.status in ('verified', 'rejected', 'withdrawn')
      )
    );
$$;

alter function public.can_upload_identity_file(text) owner to postgres;
alter function public.can_review_identity_file(text) owner to postgres;
alter function public.can_delete_identity_file(text) owner to postgres;
alter function public.can_upload_identity_file(text) set search_path = public, pg_temp;
alter function public.can_review_identity_file(text) set search_path = public, pg_temp;
alter function public.can_delete_identity_file(text) set search_path = public, pg_temp;
revoke all on function public.can_upload_identity_file(text) from public, anon;
revoke all on function public.can_review_identity_file(text) from public, anon;
revoke all on function public.can_delete_identity_file(text) from public, anon;
grant execute on function public.can_upload_identity_file(text) to authenticated;
grant execute on function public.can_review_identity_file(text) to authenticated;
grant execute on function public.can_delete_identity_file(text) to authenticated;

create policy "verification upload reserved path"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'identity-documents'
  and public.can_upload_identity_file(name)
);

create policy "verification owner resumes upload"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'identity-documents'
  and public.can_upload_identity_file(name)
);

create policy "verification moderators read pending files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'identity-documents'
  and public.can_review_identity_file(name)
);

create policy "verification owner replaces upload"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'identity-documents'
  and public.can_upload_identity_file(name)
)
with check (
  bucket_id = 'identity-documents'
  and public.can_upload_identity_file(name)
);

create policy "verification owner or reviewer deletes file"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'identity-documents'
  and public.can_delete_identity_file(name)
);

create function public.begin_identity_verification_upload(consent_confirmed boolean)
returns table(request_id uuid, upload_path text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_request public.identity_verification_requests%rowtype;
  new_request_id uuid;
  new_upload_path text;
begin
  if auth.uid() is null or consent_confirmed is distinct from true then
    raise exception 'Confirm the ID review and privacy notice before uploading.';
  end if;
  if not public.is_account_active() then
    raise exception 'This account cannot submit an ID for review.' using errcode = '42501';
  end if;

  perform 1
  from public.profiles p
  where p.id = auth.uid()
    and p.account_active
  for update;
  if not found then
    raise exception 'This account cannot submit an ID for review.' using errcode = '42501';
  end if;

  select r.* into current_request
  from public.identity_verification_requests r
  where r.user_id = auth.uid()
  order by r.created_at desc
  limit 1
  for update;

  if found then
    if current_request.status = 'uploading' then
      return query select current_request.id, current_request.storage_path;
      return;
    end if;
    if current_request.status = 'pending' then
      raise exception 'An ID review is already pending.';
    end if;
    if current_request.status = 'verified' then
      raise exception 'This account has already been verified.';
    end if;
    if current_request.storage_path is not null then
      raise exception 'The previous ID image is still being deleted. Please try again later.';
    end if;
  end if;

  if exists (
    select 1
    from public.identity_verification_requests r
    where r.user_id = auth.uid()
      and r.status = 'verified'
      and r.storage_path is null
  ) then
    raise exception 'This account has already been verified.';
  end if;

  new_request_id := gen_random_uuid();
  new_upload_path := auth.uid()::text || '/' || new_request_id::text || '.jpg';

  insert into public.identity_verification_requests (
    id, user_id, storage_path, status, consent_version
  )
  values (
    new_request_id, auth.uid(), new_upload_path, 'uploading', 'manual-id-review-v1'
  );

  insert into public.identity_verification_events (request_id, user_id, actor_id, event)
  values (new_request_id, auth.uid(), auth.uid(), 'upload_started');

  return query select new_request_id, new_upload_path;
end;
$$;

create function public.complete_identity_verification_upload(target_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  request_row public.identity_verification_requests%rowtype;
begin
  if not public.is_account_active() then
    raise exception 'This account cannot submit an ID for review.' using errcode = '42501';
  end if;

  select r.* into request_row
  from public.identity_verification_requests r
  where r.id = target_request_id
    and r.user_id = auth.uid()
  for update;
  if not found then
    raise exception 'Verification upload not found.' using errcode = '42501';
  end if;
  if request_row.status = 'pending' then
    return;
  end if;
  if request_row.status <> 'uploading' then
    raise exception 'This upload can no longer be submitted.';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'identity-documents'
      and o.name = request_row.storage_path
  ) then
    raise exception 'The ID image upload is incomplete.';
  end if;

  update public.identity_verification_requests
  set status = 'pending',
      submitted_at = now()
  where id = request_row.id;

  insert into public.identity_verification_events (request_id, user_id, actor_id, event)
  values (request_row.id, request_row.user_id, auth.uid(), 'submitted');
end;
$$;

create function public.my_identity_verification_status()
returns table(
  request_id uuid,
  status text,
  submitted_at timestamptz,
  decided_at timestamptz,
  upload_path text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    r.id,
    case
      when r.storage_path is not null and r.status = 'withdrawn' then 'withdrawn_cleanup_pending'
      when r.storage_path is not null and r.status in ('verified', 'rejected') then 'cleanup_pending'
      else r.status
    end,
    r.submitted_at,
    r.decided_at,
    case when r.status = 'uploading' then r.storage_path else null end
  from public.identity_verification_requests r
  where r.user_id = auth.uid()
    and (r.status <> 'withdrawn' or r.storage_path is not null)
  order by r.created_at desc
  limit 1;
$$;

create function public.moderator_identity_verification_queue(limit_count integer default 50)
returns table(
  request_id uuid,
  user_id uuid,
  first_name text,
  status text,
  submitted_at timestamptz,
  decided_at timestamptz,
  storage_path text
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

  return query
  select r.id,
    r.user_id,
    p.first_name,
    r.status,
    r.submitted_at,
    r.decided_at,
    r.storage_path
  from public.identity_verification_requests r
  join public.profiles p on p.id = r.user_id
  where r.user_id <> auth.uid()
    and (
      r.status = 'pending'
      or (r.status in ('verified', 'rejected', 'withdrawn') and r.storage_path is not null)
    )
  order by (r.status <> 'pending'), r.submitted_at asc nulls first
  limit greatest(1, least(coalesce(limit_count, 50), 100));
end;
$$;

create function public.moderate_identity_verification(target_request_id uuid, next_status text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  request_row public.identity_verification_requests%rowtype;
begin
  if not public.is_moderator() then
    raise exception 'Moderator access required.' using errcode = '42501';
  end if;
  if next_status is null or next_status not in ('verified', 'rejected') then
    raise exception 'Choose a valid ID review decision.';
  end if;

  select r.* into request_row
  from public.identity_verification_requests r
  where r.id = target_request_id
  for update;
  if not found or request_row.status <> 'pending' or request_row.user_id = auth.uid() then
    raise exception 'This ID review is no longer available.';
  end if;

  update public.identity_verification_requests
  set status = next_status,
      decided_at = now(),
      reviewer_id = auth.uid()
  where id = request_row.id;

  insert into public.identity_verification_events (request_id, user_id, actor_id, event)
  values (request_row.id, request_row.user_id, auth.uid(), next_status);

  return request_row.storage_path;
end;
$$;

create function public.withdraw_identity_verification(target_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  request_row public.identity_verification_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select r.* into request_row
  from public.identity_verification_requests r
  where r.id = target_request_id
    and r.user_id = auth.uid()
  for update;
  if not found then
    raise exception 'Verification request not found.' using errcode = '42501';
  end if;

  if request_row.status in ('uploading', 'pending') then
    update public.identity_verification_requests
    set status = 'withdrawn',
        decided_at = now()
    where id = request_row.id;

    insert into public.identity_verification_events (request_id, user_id, actor_id, event)
    values (request_row.id, request_row.user_id, auth.uid(), 'withdrawn');
    return request_row.storage_path;
  end if;

  if request_row.status = 'withdrawn' then
    return request_row.storage_path;
  end if;

  raise exception 'This ID review can no longer be withdrawn.';
end;
$$;

create function public.finalize_identity_verification_cleanup(target_request_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  request_row public.identity_verification_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select r.* into request_row
  from public.identity_verification_requests r
  where r.id = target_request_id
  for update;
  if not found then
    raise exception 'Verification request not found.';
  end if;

  if not (
    (request_row.status = 'withdrawn' and request_row.user_id = auth.uid())
    or (
      request_row.status in ('verified', 'rejected', 'withdrawn')
      and request_row.user_id <> auth.uid()
      and public.is_moderator()
    )
  ) then
    raise exception 'You cannot finalize this ID cleanup.' using errcode = '42501';
  end if;

  if request_row.storage_path is null then
    return true;
  end if;
  if exists (
    select 1 from storage.objects o
    where o.bucket_id = 'identity-documents'
      and o.name = request_row.storage_path
  ) then
    raise exception 'The ID image must be deleted before cleanup can be finalized.';
  end if;

  update public.identity_verification_requests
  set storage_path = null,
      image_deleted_at = now()
  where id = request_row.id;

  insert into public.identity_verification_events (request_id, user_id, actor_id, event)
  values (request_row.id, request_row.user_id, auth.uid(), 'image_deleted');

  return true;
end;
$$;

alter function public.begin_identity_verification_upload(boolean) owner to postgres;
alter function public.complete_identity_verification_upload(uuid) owner to postgres;
alter function public.my_identity_verification_status() owner to postgres;
alter function public.moderator_identity_verification_queue(integer) owner to postgres;
alter function public.moderate_identity_verification(uuid, text) owner to postgres;
alter function public.withdraw_identity_verification(uuid) owner to postgres;
alter function public.finalize_identity_verification_cleanup(uuid) owner to postgres;
alter function public.begin_identity_verification_upload(boolean) set search_path = public, pg_temp;
alter function public.complete_identity_verification_upload(uuid) set search_path = public, pg_temp;
alter function public.my_identity_verification_status() set search_path = public, pg_temp;
alter function public.moderator_identity_verification_queue(integer) set search_path = public, pg_temp;
alter function public.moderate_identity_verification(uuid, text) set search_path = public, pg_temp;
alter function public.withdraw_identity_verification(uuid) set search_path = public, pg_temp;
alter function public.finalize_identity_verification_cleanup(uuid) set search_path = public, pg_temp;
revoke all on function public.begin_identity_verification_upload(boolean) from public, anon;
revoke all on function public.complete_identity_verification_upload(uuid) from public, anon;
revoke all on function public.my_identity_verification_status() from public, anon;
revoke all on function public.moderator_identity_verification_queue(integer) from public, anon;
revoke all on function public.moderate_identity_verification(uuid, text) from public, anon;
revoke all on function public.withdraw_identity_verification(uuid) from public, anon;
revoke all on function public.finalize_identity_verification_cleanup(uuid) from public, anon;
grant execute on function public.begin_identity_verification_upload(boolean) to authenticated;
grant execute on function public.complete_identity_verification_upload(uuid) to authenticated;
grant execute on function public.my_identity_verification_status() to authenticated;
grant execute on function public.moderator_identity_verification_queue(integer) to authenticated;
grant execute on function public.moderate_identity_verification(uuid, text) to authenticated;
grant execute on function public.withdraw_identity_verification(uuid) to authenticated;
grant execute on function public.finalize_identity_verification_cleanup(uuid) to authenticated;

create function public.prevent_identity_file_orphan()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1
    from public.identity_verification_requests r
    where r.user_id = old.id
      and r.storage_path is not null
  ) then
    raise exception 'Delete or withdraw the pending ID review before deleting this account.';
  end if;
  return old;
end;
$$;

alter function public.prevent_identity_file_orphan() owner to postgres;
alter function public.prevent_identity_file_orphan() set search_path = public, pg_temp;
revoke all on function public.prevent_identity_file_orphan() from public, anon, authenticated;
create trigger profiles_no_identity_file_orphan
before delete on public.profiles
for each row execute function public.prevent_identity_file_orphan();

create function public.prevent_identity_verification_event_mutation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception 'Identity verification audit records are immutable.';
end;
$$;

create trigger identity_verification_events_immutable
before update or delete on public.identity_verification_events
for each row execute function public.prevent_identity_verification_event_mutation();
create trigger identity_verification_events_no_truncate
before truncate on public.identity_verification_events
for each statement execute function public.prevent_identity_verification_event_mutation();
revoke all on function public.prevent_identity_verification_event_mutation() from public, anon, authenticated;

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
  shared_places jsonb,
  is_verified boolean
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
    candidates.shared_places,
    exists (
      select 1
      from public.identity_verification_requests v
      where v.user_id = candidates.id
        and v.status = 'verified'
        and v.storage_path is null
    )
  from public.discover_candidates_before_admin(limit_count) candidates
  join public.profiles p on p.id = candidates.id
  where public.is_account_active()
    and p.account_active;
$$;

alter function public.discover_candidates(int) owner to postgres;
alter function public.discover_candidates(int) set search_path = public, pg_temp;
revoke all on function public.discover_candidates(int) from public, anon;
grant execute on function public.discover_candidates(int) to authenticated;

commit;
