begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(24);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderation-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderation-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderation-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now()),
  ('44444444-4444-4444-8444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderation-d@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Delta"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'moderation-test', 'Test cafe', 'Test cafe', 14.55, 121.02);

insert into public.matches (id, user_low, user_high, shared_place_id)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-444444444444', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');

update public.profiles
set first_name = 'Bravo', bio = 'Profile snapshot text', birth_date = date '1990-01-01', photo_url = 'https://example.test/bravo.jpg'
where id = '22222222-2222-4222-8222-222222222222';

insert into public.messages (match_id, sender_id, body, created_at)
select
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  case when n % 2 = 0 then '11111111-1111-4111-8111-111111111111'::uuid else '22222222-2222-4222-8222-222222222222'::uuid end,
  'Evidence message ' || n,
  now() - (22 - n) * interval '1 minute'
from generate_series(1, 21) n;

insert into public.messages (match_id, sender_id, body)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '33333333-3333-4333-8333-333333333333', 'Other conversation');
select set_config(
  'test.other_message_id',
  (select id::text from public.messages where body = 'Other conversation'),
  true
);

insert into public.moderator_roles (user_id, role, granted_by)
values ('44444444-4444-4444-8444-444444444444', 'moderator', '44444444-4444-4444-8444-444444444444');

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select public.submit_report(
  '22222222-2222-4222-8222-222222222222',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'non_consensual',
  'Please review this conversation.'
);

select extensions.is(
  (select count(*) from public.reports where reporter_id = '11111111-1111-4111-8111-111111111111'),
  1::bigint,
  'authenticated user can submit a report through the RPC'
);
select extensions.is(
  (select reason from public.reports where reporter_id = '11111111-1111-4111-8111-111111111111'),
  'non_consensual',
  'report category is stored'
);
select extensions.ok(
  (select reported_profile_snapshot->>'first_name' = 'Bravo'
    and reported_profile_snapshot->>'bio' = 'Profile snapshot text'
    and reported_profile_snapshot ? 'age_years'
   from public.report_evidence e join public.reports r on r.id = e.report_id
   where r.reporter_id = '11111111-1111-4111-8111-111111111111'),
  'report captures a limited profile snapshot'
);
select extensions.is(
  (select jsonb_array_length(message_snapshot)
   from public.report_evidence e join public.reports r on r.id = e.report_id
   where r.reporter_id = '11111111-1111-4111-8111-111111111111'),
  20,
  'default evidence is limited to 20 messages'
);
select extensions.is(
  (select message_snapshot->0->>'body'
   from public.report_evidence e join public.reports r on r.id = e.report_id
   where r.reporter_id = '11111111-1111-4111-8111-111111111111'),
  'Evidence message 2',
  'default evidence starts with the oldest of the latest 20 messages'
);
select extensions.is(
  (select message_snapshot->19->>'body'
   from public.report_evidence e join public.reports r on r.id = e.report_id
   where r.reporter_id = '11111111-1111-4111-8111-111111111111'),
  'Evidence message 21',
  'default evidence ends with the newest message'
);

select public.submit_report(
  '22222222-2222-4222-8222-222222222222',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'harassment',
  '',
  array[(select id from public.messages where body = 'Evidence message 1')]
);
select extensions.is(
  (select jsonb_array_length(message_snapshot)
   from public.report_evidence e join public.reports r on r.id = e.report_id
   where r.reporter_id = '11111111-1111-4111-8111-111111111111'
   order by r.created_at desc limit 1),
  1,
  'reporter may submit explicitly selected messages'
);
select extensions.throws_ok(
  $$select public.submit_report(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'other',
    '',
    array[current_setting('test.other_message_id')::bigint]
  )$$,
  'P0001', null, 'selected messages from another conversation are rejected'
);
select extensions.throws_ok(
  $$select public.submit_report(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'other',
    '',
    array(select id from public.messages where match_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' limit 21)
  )$$,
  'P0001', null, 'more than 20 selected messages are rejected'
);
select extensions.throws_ok(
  $$select public.submit_report('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'invalid', '')$$,
  'P0001', null, 'unsupported report categories are rejected'
);
select extensions.throws_ok(
  $$select public.submit_report('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'other', repeat('x', 1001))$$,
  'P0001', null, 'report details above 1,000 characters are rejected'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.throws_ok(
  $$select public.submit_report('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'other', '')$$,
  'P0001', null, 'user outside the conversation cannot report a participant'
);
select extensions.throws_ok(
  $$insert into public.moderator_roles (user_id, role) values ('33333333-3333-4333-8333-333333333333', 'admin')$$,
  '42501', null, 'ordinary users cannot grant moderator roles'
);
select extensions.throws_ok(
  $$insert into public.moderation_actions (report_id, moderator_id, reported_id, action) values ('00000000-0000-4000-8000-000000000000', '33333333-3333-4333-8333-333333333333', '22222222-2222-4222-8222-222222222222', 'ban')$$,
  '42501', null, 'ordinary users cannot create moderation actions'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.is(
  (select count(*) from public.report_evidence),
  2::bigint,
  'reporter can read evidence for their own reports'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select extensions.is(
  (select count(*) from public.reports),
  0::bigint,
  'reported user cannot read reports about themselves'
);
select extensions.is(
  (select count(*) from public.report_evidence),
  0::bigint,
  'reported user cannot read report evidence'
);

reset role;
insert into public.moderation_actions (report_id, moderator_id, reported_id, action, note)
select r.id, '44444444-4444-4444-8444-444444444444', r.reported_id, 'warn', 'Test moderation action'
from public.reports r
where r.reporter_id = '11111111-1111-4111-8111-111111111111'
order by r.created_at
limit 1;
select extensions.is(
  (select count(*) from public.moderation_audit_log),
  1::bigint,
  'moderation action automatically creates an audit record'
);
select extensions.throws_ok(
  $$update public.moderation_audit_log set event = 'tampered'$$,
  'P0001', 'Moderation audit records are immutable.', 'audit records cannot be modified'
);
select extensions.throws_ok(
  $$truncate table public.moderation_audit_log$$,
  'P0001', 'Moderation audit records are immutable.', 'audit records cannot be truncated'
);

set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
select extensions.is(
  (select count(*) from public.reports),
  2::bigint,
  'moderators can read reports'
);
select extensions.is(
  (select count(*) from public.report_evidence),
  2::bigint,
  'moderators can read report evidence'
);
select extensions.is(
  (select count(*) from public.moderation_actions),
  1::bigint,
  'moderators can read moderation actions'
);
select extensions.is(
  (select count(*) from public.moderation_audit_log),
  1::bigint,
  'moderators can read the audit timeline'
);

select * from extensions.finish();
rollback;
