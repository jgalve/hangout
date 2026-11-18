begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(5);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'story-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'story-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'story-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'story-test', 'Test cafe', 'Test cafe', 14.55, 121.02);

insert into public.profile_places (profile_id, place_id, position)
values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1);

update public.profiles
set first_name = 'Alpha', birth_date = date '1990-01-01', photo_url = 'https://example.test/alpha.jpg'
where id = '11111111-1111-4111-8111-111111111111';

update public.profiles
set first_name = 'Bravo', birth_date = date '1990-01-01', photo_url = 'https://example.test/bravo.jpg'
where id = '22222222-2222-4222-8222-222222222222';

set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
update public.profile_places
set place_story = 'I like the quiet mornings here.'
where profile_id = '22222222-2222-4222-8222-222222222222';

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.is(
  (select count(*) from public.discover_candidates(20) candidate
   where candidate.id = '22222222-2222-4222-8222-222222222222'),
  0::bigint,
  'discovery does not return a story when there is no shared place'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select extensions.is(
  (select place_story from public.profile_places
   where profile_id = '22222222-2222-4222-8222-222222222222'),
  'I like the quiet mornings here.',
  'users can save their own place story'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.is(
  (select candidate.shared_places->0->>'story'
   from public.discover_candidates(20) candidate
   where candidate.id = '22222222-2222-4222-8222-222222222222'),
  'I like the quiet mornings here.',
  'discovery returns a story for the shared place'
);

select extensions.is(
  (with updated as (
    update public.profile_places
    set place_story = 'Unauthorized edit'
    where profile_id = '22222222-2222-4222-8222-222222222222'
      and place_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
    returning 1
  )
  select count(*) from updated),
  0::bigint,
  'users cannot edit another profile place story'
);

select extensions.throws_ok(
  $$update public.profile_places
    set place_story = repeat('x', 281)
    where profile_id = '11111111-1111-4111-8111-111111111111'
      and place_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'$$,
  '23514', null, 'place stories are limited to 280 characters'
);

select * from extensions.finish();
rollback;
