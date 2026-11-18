begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(16);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'personality-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'personality-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'personality-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'personality-test', 'Test cafe', 'Test cafe', 14.55, 121.02);

insert into public.profile_places (profile_id, place_id, position)
values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('33333333-3333-4333-8333-333333333333', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1);

update public.profiles
set first_name = 'Alpha',
    birth_date = date '1990-01-01',
    photo_url = 'https://example.test/alpha.jpg',
    hangout_personality = array['Coffee', 'Explore', 'Foodie']
where id = '11111111-1111-4111-8111-111111111111';

update public.profiles
set first_name = 'Bravo',
    birth_date = date '1990-01-01',
    photo_url = 'https://example.test/bravo.jpg',
    hangout_personality = array['Music', 'Parks', 'Community'],
    custom_hangout_personality = 'Climbing'
where id = '22222222-2222-4222-8222-222222222222';

update public.profiles
set first_name = 'Charlie',
    birth_date = date '1990-01-01',
    photo_url = 'https://example.test/charlie.jpg'
where id = '33333333-3333-4333-8333-333333333333';

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select extensions.is(
  (select cardinality(hangout_personality) from public.profiles where id = auth.uid()),
  3,
  'profiles can save three Hangout personality choices'
);

select extensions.is(
  (select candidate.hangout_personality
   from public.discover_candidates(20) candidate
   where candidate.id = '22222222-2222-4222-8222-222222222222'),
  array['Music', 'Parks', 'Community'],
  'discovery returns Hangout personality choices'
);

select extensions.is(
  (select candidate.custom_hangout_personality
   from public.discover_candidates(20) candidate
   where candidate.id = '22222222-2222-4222-8222-222222222222'),
  'Climbing',
  'discovery returns the custom personality'
);

update public.profiles
set hangout_personality = array['Coffee', 'Explore', 'Foodie', 'Music', 'Culture'],
    custom_hangout_personality = 'Cycling, Hiking, Photography'
where id = auth.uid();

select extensions.is(
  (select cardinality(hangout_personality) from public.profiles where id = auth.uid()),
  5,
  'custom personality is additional to five predefined choices'
);

select extensions.is(
  (select custom_hangout_personality from public.profiles where id = auth.uid()),
  'Cycling, Hiking, Photography',
  'profile saves three comma-separated custom personalities'
);

select extensions.is(
  (select count(*) from public.discover_candidates(20) where id = '33333333-3333-4333-8333-333333333333'),
  0::bigint,
  'discovery excludes profiles without the required choices'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.is(
  (select count(*) from public.discover_candidates(20)),
  0::bigint,
  'discovery requires the viewer to complete their personality choices'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.throws_ok(
  $$update public.profiles
    set hangout_personality = array['Coffee', 'Explore']
    where id = auth.uid()$$,
  '23514', null, 'database rejects fewer than three choices'
);

select extensions.throws_ok(
  $$update public.profiles
    set hangout_personality = array['Coffee', 'Explore', 'Unsupported']
    where id = auth.uid()$$,
  '23514', null, 'database rejects unsupported choices'
);

select extensions.throws_ok(
  $$update public.profiles
    set custom_hangout_personality = 'Trail running'
    where id = auth.uid()$$,
  '23514', null, 'database rejects multi-word custom personalities'
);

select extensions.throws_ok(
  $$update public.profiles
    set custom_hangout_personality = 'coffee'
    where id = auth.uid()$$,
  '23514', null, 'database rejects a custom duplicate of a predefined choice'
);

select extensions.throws_ok(
  $$update public.profiles
    set custom_hangout_personality = repeat('a', 31)
    where id = auth.uid()$$,
  '23514', null, 'database rejects custom personalities longer than 30 characters'
);

select extensions.throws_ok(
  $$update public.profiles
    set custom_hangout_personality = 'Cycling, Hiking, Photography, Cooking'
    where id = auth.uid()$$,
  '23514', null, 'database rejects more than three custom personalities'
);

select extensions.throws_ok(
  $$update public.profiles
    set custom_hangout_personality = 'Cycling, cycling'
    where id = auth.uid()$$,
  '23514', null, 'database rejects duplicate custom personalities'
);

update public.profiles set bio = 'Profile remains editable.' where id = auth.uid();
select extensions.is(
  (select bio from public.profiles where id = auth.uid()),
  'Profile remains editable.',
  'unrelated profile edits remain available'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
update public.profiles set bio = 'Legacy profile remains editable.' where id = auth.uid();
select extensions.is(
  (select cardinality(hangout_personality) from public.profiles where id = auth.uid()),
  0,
  'existing profiles may edit other fields before choosing personalities'
);

select * from extensions.finish();
rollback;
