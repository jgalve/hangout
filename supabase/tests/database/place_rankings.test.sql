begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(9);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now()),
  ('44444444-4444-4444-8444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-d@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Delta"}', now(), now()),
  ('55555555-5555-4555-8555-555555555555', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-e@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Echo"}', now(), now()),
  ('66666666-6666-4666-8666-666666666666', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-f@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Foxtrot"}', now(), now()),
  ('77777777-7777-4777-8777-777777777777', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-g@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Golf"}', now(), now()),
  ('88888888-8888-4888-8888-888888888888', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ranking-h@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Hotel"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values
  ('eeeeeeee-eeee-4eee-8eee-000000000001', 'node', 'ranking-1', 'Evergreen Cafe', 'Evergreen Cafe', 14.55, 121.02),
  ('eeeeeeee-eeee-4eee-8eee-000000000002', 'node', 'ranking-2', 'Fresh Park', 'Fresh Park', 14.56, 121.03),
  ('eeeeeeee-eeee-4eee-8eee-000000000003', 'node', 'ranking-3', 'Garden', 'Garden', 14.57, 121.04),
  ('eeeeeeee-eeee-4eee-8eee-000000000004', 'node', 'ranking-4', 'Market', 'Market', 14.58, 121.05),
  ('eeeeeeee-eeee-4eee-8eee-000000000005', 'node', 'ranking-5', 'Music Hall', 'Music Hall', 14.59, 121.06),
  ('eeeeeeee-eeee-4eee-8eee-000000000006', 'node', 'ranking-6', 'Trail', 'Trail', 14.60, 121.07);

insert into public.profile_places (profile_id, place_id, position, created_at)
values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-000000000001', 1, now() - interval '1 day'),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-000000000001', 1, now() - interval '8 days'),
  ('33333333-3333-4333-8333-333333333333', 'eeeeeeee-eeee-4eee-8eee-000000000001', 1, now() - interval '8 days'),
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-000000000002', 2, now() - interval '1 day'),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-000000000002', 2, now() - interval '1 day'),
  ('44444444-4444-4444-8444-444444444444', 'eeeeeeee-eeee-4eee-8eee-000000000003', 1, now() - interval '1 day'),
  ('55555555-5555-4555-8555-555555555555', 'eeeeeeee-eeee-4eee-8eee-000000000004', 1, now() - interval '1 day'),
  ('66666666-6666-4666-8666-666666666666', 'eeeeeeee-eeee-4eee-8eee-000000000005', 1, now() - interval '1 day'),
  ('77777777-7777-4777-8777-777777777777', 'eeeeeeee-eeee-4eee-8eee-000000000006', 1, now() - interval '1 day'),
  ('88888888-8888-4888-8888-888888888888', 'eeeeeeee-eeee-4eee-8eee-000000000001', 1, now() - interval '1 day');

update public.profiles
set account_active = false
where id = '88888888-8888-4888-8888-888888888888';

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select extensions.is(
  (select user_count from public.discover_hangout_rankings()
   where category = 'popular' and place_name = 'Evergreen Cafe'),
  3::bigint,
  'popular counts distinct active users'
);

select extensions.is(
  (select place_name from public.discover_hangout_rankings()
   where category = 'popular' and ranking_position = 1),
  'Evergreen Cafe',
  'the most popular place ranks first'
);

select extensions.is(
  (select count(*) from public.discover_hangout_rankings() where category = 'popular'),
  5::bigint,
  'popular results are capped at five places'
);

select extensions.is(
  (select user_count from public.discover_hangout_rankings()
   where category = 'trending' and place_name = 'Fresh Park'),
  2::bigint,
  'trending counts distinct users who pinned in the last seven days'
);

select extensions.is(
  (select place_name from public.discover_hangout_rankings()
   where category = 'trending' and ranking_position = 1),
  'Fresh Park',
  'the place with the most new pins ranks first'
);

select extensions.is(
  (select user_count from public.discover_hangout_rankings()
   where category = 'trending' and place_name = 'Evergreen Cafe'),
  1::bigint,
  'older pins do not contribute to the trending count'
);

select extensions.is(
  (select count(*) from public.discover_hangout_rankings() where category = 'trending'),
  5::bigint,
  'trending results are capped at five places'
);

set local request.jwt.claim.sub = '88888888-8888-4888-8888-888888888888';
select extensions.is(
  (select count(*) from public.discover_hangout_rankings()),
  0::bigint,
  'inactive users cannot retrieve place rankings'
);

select extensions.ok(
  not has_function_privilege('anon', 'public.discover_hangout_rankings()', 'EXECUTE'),
  'anonymous users cannot retrieve place rankings'
);

select * from extensions.finish();
rollback;
