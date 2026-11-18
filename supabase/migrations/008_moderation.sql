alter table public.reports
  drop constraint reports_reason_check,
  add constraint reports_reason_check
    check (reason in ('harassment', 'spam', 'impersonation', 'underage', 'unsafe', 'non_consensual', 'other'));

create table public.moderator_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('moderator', 'admin')),
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.report_evidence (
  report_id uuid primary key references public.reports(id) on delete cascade,
  reported_profile_snapshot jsonb not null,
  message_snapshot jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(reported_profile_snapshot) = 'object'),
  check (jsonb_typeof(message_snapshot) = 'array' and jsonb_array_length(message_snapshot) <= 20)
);

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  moderator_id uuid not null references public.moderator_roles(user_id) on delete restrict,
  reported_id uuid not null references public.profiles(id) on delete restrict,
  action text not null check (action in ('warn', 'restrict', 'suspend', 'ban', 'dismiss', 'request_information')),
  note text not null default '' check (char_length(note) <= 2000),
  created_at timestamptz not null default now()
);

create table public.moderation_audit_log (
  id bigint generated always as identity primary key,
  action_id uuid not null references public.moderation_actions(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  event text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index moderation_actions_report_created_idx
  on public.moderation_actions(report_id, created_at desc);
create index moderation_audit_action_created_idx
  on public.moderation_audit_log(action_id, created_at desc);

alter table public.moderator_roles enable row level security;
alter table public.report_evidence enable row level security;
alter table public.moderation_actions enable row level security;
alter table public.moderation_audit_log enable row level security;

create function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.moderator_roles mr
    where mr.user_id = auth.uid()
      and mr.role in ('moderator', 'admin')
  );
$$;

alter function public.is_moderator() owner to postgres;
alter function public.is_moderator() set search_path = public, pg_temp;
revoke all on function public.is_moderator() from public, anon;
grant execute on function public.is_moderator() to authenticated;

create policy "moderator roles self or moderator read"
on public.moderator_roles
for select
to authenticated
using (user_id = auth.uid() or public.is_moderator());

create policy "reporters and moderators read report evidence"
on public.report_evidence
for select
to authenticated
using (
  public.is_moderator()
  or exists (
    select 1
    from public.reports r
    where r.id = report_id
      and r.reporter_id = auth.uid()
  )
);

create policy "moderators read moderation actions"
on public.moderation_actions
for select
to authenticated
using (public.is_moderator());

create policy "moderators read audit log"
on public.moderation_audit_log
for select
to authenticated
using (public.is_moderator());

create policy "moderators read reports"
on public.reports
for select
to authenticated
using (public.is_moderator());

revoke all on public.moderator_roles from anon, authenticated;
grant select on public.moderator_roles to authenticated;
revoke all on public.report_evidence from anon, authenticated;
grant select on public.report_evidence to authenticated;
revoke all on public.moderation_actions from anon, authenticated;
grant select on public.moderation_actions to authenticated;
revoke all on public.moderation_audit_log from anon, authenticated;
grant select on public.moderation_audit_log to authenticated;
revoke insert on public.reports from authenticated;

create function public.prevent_moderation_audit_mutation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception 'Moderation audit records are immutable.';
end;
$$;

create trigger moderation_audit_log_immutable
before update or delete on public.moderation_audit_log
for each row execute function public.prevent_moderation_audit_mutation();

create trigger moderation_audit_log_no_truncate
before truncate on public.moderation_audit_log
for each statement execute function public.prevent_moderation_audit_mutation();

revoke all on function public.prevent_moderation_audit_mutation() from public, anon, authenticated;

create function public.log_moderation_action()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.moderation_audit_log (action_id, actor_id, event, details)
  values (
    new.id,
    new.moderator_id,
    new.action,
    jsonb_build_object(
      'report_id', new.report_id,
      'reported_id', new.reported_id,
      'note', new.note
    )
  );
  return new;
end;
$$;

alter function public.log_moderation_action() owner to postgres;
alter function public.log_moderation_action() set search_path = public, pg_temp;
revoke all on function public.log_moderation_action() from public, anon, authenticated;

create trigger moderation_actions_audit_insert
after insert on public.moderation_actions
for each row execute function public.log_moderation_action();

create function public.submit_report(
  target_user_id uuid,
  match_uuid uuid,
  reason text,
  details text default '',
  selected_message_ids bigint[] default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  reporter uuid := auth.uid();
  report_uuid uuid;
  profile_snapshot jsonb;
  message_snapshot jsonb;
  selected_count bigint;
begin
  if reporter is null then
    raise exception 'Sign in before submitting a report.';
  end if;
  if target_user_id is null or target_user_id = reporter then
    raise exception 'Choose another person to report.';
  end if;
  if reason is null or reason not in (
    'harassment', 'spam', 'impersonation', 'underage', 'unsafe', 'non_consensual', 'other'
  ) then
    raise exception 'Choose a valid report category.';
  end if;
  if char_length(coalesce(details, '')) > 1000 then
    raise exception 'Report details must be 1,000 characters or fewer.';
  end if;
  if not exists (
    select 1
    from public.matches m
    where m.id = match_uuid
      and reporter in (m.user_low, m.user_high)
      and target_user_id in (m.user_low, m.user_high)
      and reporter <> target_user_id
  ) then
    raise exception 'This report is not associated with a valid conversation.';
  end if;

  if selected_message_ids is not null then
    if cardinality(selected_message_ids) > 20 then
      raise exception 'Select no more than 20 messages.';
    end if;
    select count(*) into selected_count
    from public.messages msg
    where msg.match_id = match_uuid
      and msg.id = any(selected_message_ids);
    if selected_count <> cardinality(selected_message_ids) then
      raise exception 'Selected messages must belong to this conversation.';
    end if;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', msg.id,
          'sender_id', msg.sender_id,
          'body', msg.body,
          'created_at', msg.created_at
        ) order by msg.created_at, msg.id
      ),
      '[]'::jsonb
    )
    into message_snapshot
    from public.messages msg
    where msg.match_id = match_uuid
      and msg.id = any(selected_message_ids);
  else
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', recent.id,
          'sender_id', recent.sender_id,
          'body', recent.body,
          'created_at', recent.created_at
        ) order by recent.created_at, recent.id
      ),
      '[]'::jsonb
    )
    into message_snapshot
    from (
      select msg.id, msg.sender_id, msg.body, msg.created_at
      from public.messages msg
      where msg.match_id = match_uuid
      order by msg.created_at desc, msg.id desc
      limit 20
    ) recent;
  end if;

  select jsonb_build_object(
    'first_name', p.first_name,
    'bio', p.bio,
    'photo_url', p.photo_url,
    'interests', p.interests,
    'age_years', case
      when p.birth_date is null then null
      else date_part('year', age(current_date, p.birth_date))::integer
    end,
    'account_created_at', p.created_at
  )
  into profile_snapshot
  from public.profiles p
  where p.id = target_user_id;

  if profile_snapshot is null then
    raise exception 'The reported profile is no longer available.';
  end if;

  insert into public.reports (reporter_id, reported_id, match_id, reason, details)
  values (reporter, target_user_id, match_uuid, reason, coalesce(details, ''))
  returning id into report_uuid;

  insert into public.report_evidence (report_id, reported_profile_snapshot, message_snapshot)
  values (report_uuid, profile_snapshot, message_snapshot);

  return report_uuid;
end;
$$;

alter function public.submit_report(uuid, uuid, text, text, bigint[]) owner to postgres;
alter function public.submit_report(uuid, uuid, text, text, bigint[]) set search_path = public, pg_temp;
revoke all on function public.submit_report(uuid, uuid, text, text, bigint[]) from public, anon;
grant execute on function public.submit_report(uuid, uuid, text, text, bigint[]) to authenticated;
