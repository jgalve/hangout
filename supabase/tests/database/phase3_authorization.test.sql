begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(22);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase3-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase3-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase3-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now()),
  ('44444444-4444-4444-8444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase3-d@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Delta"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'phase3-test', 'Test cafe', 'Test cafe', 14.55, 121.02);

insert into public.matches (id, user_low, user_high, shared_place_id)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-444444444444', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');

insert into public.blocks (blocker_id, blocked_id)
values ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222');

create temporary table blocks (blocker_id uuid, blocked_id uuid);
select extensions.ok(
  public.is_blocked('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222'),
  'temporary tables cannot shadow block checks'
);

insert into public.messages (match_id, sender_id, body)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '22222222-2222-4222-8222-222222222222', 'Blocked conversation'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '33333333-3333-4333-8333-333333333333', 'Normal conversation');

insert into public.meetup_proposals (
  id, match_id, proposer_id, place_id, proposed_for, note
) values
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', now() + interval '2 days', 'Blocked proposal'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '33333333-3333-4333-8333-333333333333', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', now() + interval '2 days', 'First proposal'),
  ('ffffffff-ffff-4fff-8fff-ffffffffffff', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '33333333-3333-4333-8333-333333333333', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', now() + interval '3 days', 'Second proposal');

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.is((select count(*) from public.matches), 0::bigint, 'blocked user cannot read match');
select extensions.throws_ok(
  $$insert into public.messages (match_id, sender_id, body) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'Cannot send')$$,
  '42501', null, 'blocked user cannot send a message'
);
select extensions.throws_ok(
  $$insert into public.meetup_proposals (match_id, proposer_id, place_id, proposed_for) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', now() + interval '4 days')$$,
  '42501', null, 'blocked user cannot create a meetup proposal'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select extensions.is((select count(*) from public.messages where match_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 0::bigint, 'block prevents reads in the reverse direction');
select extensions.is((select count(*) from public.meetup_proposals where match_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 0::bigint, 'blocked meetup proposals are hidden');

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.is((select count(*) from public.matches where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 0::bigint, 'unrelated user cannot read another match');
select extensions.is((select count(*) from public.messages where match_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 0::bigint, 'unrelated user cannot read messages');
select extensions.throws_ok(
  $$update public.meetup_proposals set note = 'tampered' where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  '42501', null, 'unrelated user cannot update a meetup proposal'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.throws_ok(
  $$select public.respond_to_meetup('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'accepted')$$,
  'P0001', null, 'proposer cannot respond to their own proposal'
);

set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
select extensions.throws_ok(
  $$select public.respond_to_meetup('dddddddd-dddd-4ddd-8ddd-dddddddddddd', null)$$,
  'P0001', null, 'null response action is rejected'
);
select extensions.is(
  public.respond_to_meetup('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'accepted')::text,
  'accepted',
  'recipient can accept a pending proposal'
);
update public.messages
set read_at = now()
where match_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  and sender_id = '33333333-3333-4333-8333-333333333333';
select extensions.ok(
  (select read_at is not null from public.messages where match_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  'recipient can mark a message read'
);
select extensions.throws_ok(
  $$update public.messages set body = 'tampered' where match_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'$$,
  '42501', null, 'recipient cannot edit message content'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.ok(
  public.change_meetup('dddddddd-dddd-4ddd-8ddd-dddddddddddd', now() + interval '5 days', 'New time') is not null,
  'accepted proposal can be changed through a replacement proposal'
);
select extensions.is(
  (select status::text from public.meetup_proposals where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
  'changed',
  'changing a proposal marks the prior proposal changed'
);
select extensions.ok(
  exists(select 1 from public.meetup_proposals where supersedes_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd' and status = 'pending'),
  'change creates a pending replacement'
);

set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
select extensions.throws_ok(
  $$select public.cancel_meetup((select id from public.meetup_proposals where supersedes_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'))$$,
  'P0001', null, 'recipient cannot cancel another user pending replacement'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.is(
  public.cancel_meetup((select id from public.meetup_proposals where supersedes_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'))::text,
  'cancelled',
  'proposer can cancel a pending replacement'
);

set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
select extensions.is(
  public.respond_to_meetup('ffffffff-ffff-4fff-8fff-ffffffffffff', 'accepted')::text,
  'accepted',
  'recipient can accept another pending proposal'
);
select extensions.is(
  public.cancel_meetup('ffffffff-ffff-4fff-8fff-ffffffffffff')::text,
  'cancelled',
  'either participant can cancel an accepted meetup'
);
select extensions.is(
  (select status::text from public.meetup_proposals where id = 'ffffffff-ffff-4fff-8fff-ffffffffffff'),
  'cancelled',
  'cancellation persists the terminal status'
);

select * from extensions.finish();
rollback;
