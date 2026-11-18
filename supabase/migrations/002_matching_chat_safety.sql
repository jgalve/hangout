-- HangOut Phase 2: discovery, swipes, matches, realtime chat, meetup proposals, blocks and reports
create type public.swipe_decision as enum ('like','pass');
create type public.meetup_status as enum ('pending','accepted','declined','changed','cancelled');
create type public.report_status as enum ('open','reviewing','resolved','dismissed');

create table public.swipes (
  swiper_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  decision public.swipe_decision not null,
  created_at timestamptz not null default now(),
  primary key(swiper_id,target_id),
  check(swiper_id<>target_id)
);
create table public.matches (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profiles(id) on delete cascade,
  user_high uuid not null references public.profiles(id) on delete cascade,
  shared_place_id uuid references public.places(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(user_low,user_high), check(user_low<user_high)
);
create table public.messages (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check(char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index messages_match_created_idx on public.messages(match_id,created_at);
create table public.meetup_proposals (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  proposer_id uuid not null references public.profiles(id) on delete cascade,
  place_id uuid not null references public.places(id),
  proposed_for timestamptz not null,
  note text not null default '' check(char_length(note)<=280),
  status public.meetup_status not null default 'pending',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(blocker_id,blocked_id), check(blocker_id<>blocked_id)
);
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  match_id uuid references public.matches(id) on delete set null,
  reason text not null check(reason in ('harassment','spam','impersonation','underage','unsafe','other')),
  details text not null default '' check(char_length(details)<=1000),
  status public.report_status not null default 'open', created_at timestamptz not null default now(), check(reporter_id<>reported_id)
);

create or replace function public.are_matched(match_uuid uuid, user_uuid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from matches m where m.id=match_uuid and user_uuid in(m.user_low,m.user_high)); $$;
create or replace function public.is_blocked(a uuid,b uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from blocks where (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a)); $$;
create or replace function public.discover_candidates(limit_count int default 20)
returns table(id uuid,first_name text,bio text,photo_url text,shared_place_id uuid,shared_place_name text)
language sql stable security definer set search_path=public as $$
 select p.id,p.first_name,p.bio,p.photo_url,pl.id,pl.name
 from profiles p join profile_places theirs on theirs.profile_id=p.id
 join profile_places mine on mine.place_id=theirs.place_id and mine.profile_id=auth.uid()
 join places pl on pl.id=mine.place_id
 where p.id<>auth.uid() and p.birth_date is not null
 and not exists(select 1 from swipes s where s.swiper_id=auth.uid() and s.target_id=p.id)
 and not public.is_blocked(auth.uid(),p.id)
 group by p.id,p.first_name,p.bio,p.photo_url,pl.id,pl.name
 order by count(*) over(partition by p.id) desc,p.created_at desc limit greatest(1,least(limit_count,50)); $$;
create or replace function public.record_swipe(target uuid, choice public.swipe_decision)
returns uuid language plpgsql security definer set search_path=public as $$
declare match_id uuid; low_id uuid; high_id uuid; common_place uuid;
begin
 if target=auth.uid() or public.is_blocked(auth.uid(),target) then raise exception 'Invalid swipe target'; end if;
 insert into swipes(swiper_id,target_id,decision) values(auth.uid(),target,choice)
 on conflict(swiper_id,target_id) do update set decision=excluded.decision,created_at=now();
 if choice='like' and exists(select 1 from swipes where swiper_id=target and target_id=auth.uid() and decision='like') then
  low_id:=least(auth.uid(),target); high_id:=greatest(auth.uid(),target);
  select mine.place_id into common_place from profile_places mine join profile_places theirs using(place_id)
  where mine.profile_id=auth.uid() and theirs.profile_id=target order by mine.position limit 1;
  insert into matches(user_low,user_high,shared_place_id) values(low_id,high_id,common_place)
  on conflict(user_low,user_high) do update set shared_place_id=coalesce(matches.shared_place_id,excluded.shared_place_id)
  returning id into match_id;
 end if; return match_id;
end; $$;
create or replace function public.list_matches()
returns table(id uuid,other_user_id uuid,other_first_name text,other_photo_url text,shared_place_id uuid,shared_place_name text,created_at timestamptz,unread_count bigint)
language sql stable security definer set search_path=public as $$
 select m.id,case when m.user_low=auth.uid() then m.user_high else m.user_low end,p.first_name,p.photo_url,m.shared_place_id,pl.name,m.created_at,
 (select count(*) from messages msg where msg.match_id=m.id and msg.sender_id<>auth.uid() and msg.read_at is null)
 from matches m join profiles p on p.id=case when m.user_low=auth.uid() then m.user_high else m.user_low end
 left join places pl on pl.id=m.shared_place_id
 where auth.uid() in(m.user_low,m.user_high) and not public.is_blocked(m.user_low,m.user_high) order by m.created_at desc; $$;

alter table public.swipes enable row level security; alter table public.matches enable row level security;
alter table public.messages enable row level security; alter table public.meetup_proposals enable row level security;
alter table public.blocks enable row level security; alter table public.reports enable row level security;
create policy "swipes own" on public.swipes for all to authenticated using(swiper_id=auth.uid()) with check(swiper_id=auth.uid());
create policy "matches participants read" on public.matches for select to authenticated using(auth.uid() in(user_low,user_high));
create policy "messages participants read" on public.messages for select to authenticated using(public.are_matched(match_id,auth.uid()));
create policy "messages participants send" on public.messages for insert to authenticated with check(sender_id=auth.uid() and public.are_matched(match_id,auth.uid()));
create policy "messages recipient marks read" on public.messages for update to authenticated using(sender_id<>auth.uid() and public.are_matched(match_id,auth.uid())) with check(public.are_matched(match_id,auth.uid()));
create policy "meetups participants read" on public.meetup_proposals for select to authenticated using(public.are_matched(match_id,auth.uid()));
create policy "meetups participants create" on public.meetup_proposals for insert to authenticated with check(proposer_id=auth.uid() and public.are_matched(match_id,auth.uid()));
create policy "meetups participants update" on public.meetup_proposals for update to authenticated using(public.are_matched(match_id,auth.uid())) with check(public.are_matched(match_id,auth.uid()));
create policy "blocks own" on public.blocks for all to authenticated using(blocker_id=auth.uid()) with check(blocker_id=auth.uid());
create policy "reports reporter create" on public.reports for insert to authenticated with check(reporter_id=auth.uid());
create policy "reports reporter read" on public.reports for select to authenticated using(reporter_id=auth.uid());
grant select,insert,update on public.swipes,public.messages,public.meetup_proposals to authenticated;
grant select on public.matches to authenticated; grant select,insert,delete on public.blocks to authenticated;
grant select,insert on public.reports to authenticated; grant usage,select on sequence public.messages_id_seq to authenticated;
grant execute on function public.discover_candidates(int),public.record_swipe(uuid,public.swipe_decision),public.list_matches() to authenticated;
alter publication supabase_realtime add table public.messages,public.meetup_proposals;
