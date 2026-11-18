begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(3);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'discovery-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'discovery-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'discovery-shared-1', 'First cafe', 'First cafe', 14.55, 121.02),
  ('ffffffff-ffff-4fff-8fff-ffffffffffff', 'node', 'discovery-shared-2', 'Second cafe', 'Second cafe', 14.56, 121.03),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'node', 'discovery-private', 'Other place', 'Other place', 14.57, 121.04);

insert into public.profile_places (profile_id, place_id, position, place_story)
values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1, null),
  ('11111111-1111-4111-8111-111111111111', 'ffffffff-ffff-4fff-8fff-ffffffffffff', 2, null),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1, 'Morning coffee.'),
  ('22222222-2222-4222-8222-222222222222', 'ffffffff-ffff-4fff-8fff-ffffffffffff', 2, 'The garden patio.'),
  ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 3, 'A private place story.');

update public.profiles
set first_name = 'Alpha', birth_date = date '1990-01-01', photo_url = 'https://example.test/alpha.jpg'
where id = '11111111-1111-4111-8111-111111111111';

update public.profiles
set first_name = 'Bravo', birth_date = date '1990-01-01', photo_url = 'https://example.test/bravo.jpg'
where id = '22222222-2222-4222-8222-222222222222';

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select extensions.is(
  (select count(*) from public.discover_candidates(20)
   where id = '22222222-2222-4222-8222-222222222222'),
  1::bigint,
  'a candidate sharing multiple places appears once'
);

select extensions.is(
  (select jsonb_array_length(shared_places)
   from public.discover_candidates(20)
   where id = '22222222-2222-4222-8222-222222222222'),
  2,
  'the candidate card includes all shared places'
);

select extensions.is(
  (select shared_places
   from public.discover_candidates(20)
   where id = '22222222-2222-4222-8222-222222222222'),
  '[
    {"id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","name":"First cafe","story":"Morning coffee."},
    {"id":"ffffffff-ffff-4fff-8fff-ffffffffffff","name":"Second cafe","story":"The garden patio."}
  ]'::jsonb,
  'only shared places and their associated stories are returned'
);

select * from extensions.finish();
rollback;
