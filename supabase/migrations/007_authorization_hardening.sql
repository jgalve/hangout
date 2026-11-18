drop policy if exists "matches participants read" on public.matches;
drop policy if exists "messages participants read" on public.messages;
drop policy if exists "messages participants send" on public.messages;
drop policy if exists "messages recipient marks read" on public.messages;
drop policy if exists "meetups participants read" on public.meetup_proposals;
drop policy if exists "meetups participants create" on public.meetup_proposals;
drop policy if exists "meetups participants update" on public.meetup_proposals;

drop function if exists public.are_matched(uuid, uuid);

alter function public.is_blocked(uuid, uuid) owner to postgres;
alter function public.is_blocked(uuid, uuid) set search_path = public, pg_temp;

create function public.are_matched(match_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = match_uuid
      and auth.uid() in (m.user_low, m.user_high)
      and not public.is_blocked(m.user_low, m.user_high)
  );
$$;

alter function public.are_matched(uuid) owner to postgres;
alter function public.are_matched(uuid) set search_path = public, pg_temp;
revoke all on function public.are_matched(uuid) from public, anon;
grant execute on function public.are_matched(uuid) to authenticated;
revoke all on function public.is_blocked(uuid, uuid) from public, anon, authenticated;

create policy "matches active participants read"
on public.matches
for select
to authenticated
using (
  public.are_matched(id)
);

create policy "messages active participants read"
on public.messages
for select
to authenticated
using (public.are_matched(match_id));

create policy "messages active participants send"
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and public.are_matched(match_id)
);

create policy "messages recipient marks read"
on public.messages
for update
to authenticated
using (
  sender_id <> auth.uid()
  and public.are_matched(match_id)
)
with check (
  sender_id <> auth.uid()
  and public.are_matched(match_id)
);

revoke update on public.messages from authenticated;
grant update (read_at) on public.messages to authenticated;

create policy "meetups active participants read"
on public.meetup_proposals
for select
to authenticated
using (public.are_matched(match_id));

create policy "meetups active participants create"
on public.meetup_proposals
for insert
to authenticated
with check (
  proposer_id = auth.uid()
  and public.are_matched(match_id)
  and proposed_for > now()
  and char_length(note) <= 280
  and exists (
    select 1
    from public.matches m
    where m.id = match_id
      and m.shared_place_id = place_id
  )
);

revoke update on public.meetup_proposals from authenticated;

alter table public.meetup_proposals
  add column supersedes_id uuid references public.meetup_proposals(id) on delete set null;

create function public.respond_to_meetup(proposal_id uuid, action text)
returns public.meetup_status
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  proposal public.meetup_proposals%rowtype;
  next_status public.meetup_status;
begin
  if action is null or action not in ('accepted', 'declined') then
    raise exception 'Action must be accepted or declined.';
  end if;

  select * into proposal
  from public.meetup_proposals mp
  where mp.id = proposal_id
  for update;

  if not found or not public.are_matched(proposal.match_id) then
    raise exception 'Meetup proposal not found.';
  end if;
  if proposal.status <> 'pending' then
    raise exception 'Only pending proposals can be answered.';
  end if;
  if proposal.proposer_id = auth.uid() then
    raise exception 'The proposer cannot respond to their own proposal.';
  end if;

  next_status := action::public.meetup_status;
  update public.meetup_proposals
  set status = next_status, updated_at = now()
  where id = proposal_id;
  return next_status;
end;
$$;

alter function public.respond_to_meetup(uuid, text) owner to postgres;
alter function public.respond_to_meetup(uuid, text) set search_path = public, pg_temp;

create function public.cancel_meetup(proposal_id uuid)
returns public.meetup_status
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  proposal public.meetup_proposals%rowtype;
begin
  select * into proposal
  from public.meetup_proposals mp
  where mp.id = proposal_id
  for update;

  if not found or not public.are_matched(proposal.match_id) then
    raise exception 'Meetup proposal not found.';
  end if;
  if proposal.status = 'pending' and proposal.proposer_id <> auth.uid() then
    raise exception 'Only the proposer can cancel a pending proposal.';
  end if;
  if proposal.status not in ('pending', 'accepted') then
    raise exception 'This meetup can no longer be cancelled.';
  end if;

  update public.meetup_proposals
  set status = 'cancelled', updated_at = now()
  where id = proposal_id;
  return 'cancelled'::public.meetup_status;
end;
$$;

alter function public.cancel_meetup(uuid) owner to postgres;
alter function public.cancel_meetup(uuid) set search_path = public, pg_temp;

create function public.change_meetup(
  proposal_id uuid,
  new_proposed_for timestamptz,
  new_note text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  proposal public.meetup_proposals%rowtype;
  replacement_id uuid;
begin
  if new_proposed_for is null or new_proposed_for <= now() then
    raise exception 'Choose a future date and time.';
  end if;
  if char_length(coalesce(new_note, '')) > 280 then
    raise exception 'The meetup note must be 280 characters or fewer.';
  end if;

  select * into proposal
  from public.meetup_proposals mp
  where mp.id = proposal_id
  for update;

  if not found or not public.are_matched(proposal.match_id) then
    raise exception 'Meetup proposal not found.';
  end if;
  if proposal.status <> 'accepted' then
    raise exception 'Only accepted meetups can be changed.';
  end if;

  update public.meetup_proposals
  set status = 'changed', updated_at = now()
  where id = proposal_id;

  insert into public.meetup_proposals (
    match_id, proposer_id, place_id, proposed_for, note, status, supersedes_id
  )
  values (
    proposal.match_id,
    auth.uid(),
    proposal.place_id,
    new_proposed_for,
    coalesce(new_note, ''),
    'pending',
    proposal_id
  )
  returning id into replacement_id;

  return replacement_id;
end;
$$;

alter function public.change_meetup(uuid, timestamptz, text) owner to postgres;
alter function public.change_meetup(uuid, timestamptz, text) set search_path = public, pg_temp;

revoke all on function public.respond_to_meetup(uuid, text) from public, anon;
revoke all on function public.cancel_meetup(uuid) from public, anon;
revoke all on function public.change_meetup(uuid, timestamptz, text) from public, anon;
grant execute on function public.respond_to_meetup(uuid, text) to authenticated;
grant execute on function public.cancel_meetup(uuid) to authenticated;
grant execute on function public.change_meetup(uuid, timestamptz, text) to authenticated;

revoke all on function public.discover_candidates(int) from public, anon;
revoke all on function public.record_swipe(uuid, public.swipe_decision) from public, anon;
revoke all on function public.list_matches() from public, anon;
alter function public.discover_candidates(int) owner to postgres;
alter function public.record_swipe(uuid, public.swipe_decision) owner to postgres;
alter function public.list_matches() owner to postgres;
alter function public.discover_candidates(int) set search_path = public, pg_temp;
alter function public.record_swipe(uuid, public.swipe_decision) set search_path = public, pg_temp;
alter function public.list_matches() set search_path = public, pg_temp;
grant execute on function public.discover_candidates(int) to authenticated;
grant execute on function public.record_swipe(uuid, public.swipe_decision) to authenticated;
grant execute on function public.list_matches() to authenticated;
