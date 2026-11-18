begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(6);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gender-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gender-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gender-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now()),
  ('44444444-4444-4444-8444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gender-d@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Delta"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'gender-test', 'Test cafe', 'Test cafe', 14.55, 121.02);

insert into public.profile_places (profile_id, place_id, position)
values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('33333333-3333-4333-8333-333333333333', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('44444444-4444-4444-8444-444444444444', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1);

update public.profiles
set first_name = 'Alpha', birth_date = date '1990-01-01', photo_url = 'https://example.test/alpha.jpg',
    gender_identity = 'woman', interested_in_genders = array['man'], open_to_all_genders = false
where id = '11111111-1111-4111-8111-111111111111';

update public.profiles
set first_name = 'Bravo', birth_date = date '1990-01-01', photo_url = 'https://example.test/bravo.jpg',
    gender_identity = 'man', interested_in_genders = array['woman'], open_to_all_genders = false
where id = '22222222-2222-4222-8222-222222222222';

update public.profiles
set first_name = 'Charlie', birth_date = date '1990-01-01', photo_url = 'https://example.test/charlie.jpg',
    gender_identity = 'woman', interested_in_genders = array['woman'], open_to_all_genders = false
where id = '33333333-3333-4333-8333-333333333333';

update public.profiles
set first_name = 'Delta', birth_date = date '1990-01-01', photo_url = 'https://example.test/delta.jpg'
where id = '44444444-4444-4444-8444-444444444444';

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select extensions.is(
  (select count(*) from public.discover_candidates(20)),
  2::bigint,
  'gender preferences are mutual and undisclosed identities remain eligible'
);

select extensions.is(
  (select gender_identity from public.discover_candidates(20)
   where id = '22222222-2222-4222-8222-222222222222'),
  'man',
  'discovery returns a disclosed gender identity'
);

select extensions.is(
  (select count(*) from public.discover_candidates(20)
   where id = '33333333-3333-4333-8333-333333333333'),
  0::bigint,
  'candidate who does not reciprocate is excluded'
);

select extensions.is(
  (select open_to_all_genders from public.profiles
   where id = '44444444-4444-4444-8444-444444444444'),
  true,
  'existing profiles default to open to everyone'
);

update public.profiles
set interested_in_genders = array['woman']
where id = '11111111-1111-4111-8111-111111111111';

select extensions.is(
  (select count(*) from public.discover_candidates(20)
   where id = '33333333-3333-4333-8333-333333333333'),
  1::bigint,
  'a mutually compatible gender preference appears in discovery'
);

select extensions.throws_ok(
  $$update public.profiles
    set gender_identity = 'self_described', gender_identity_detail = null
    where id = '11111111-1111-4111-8111-111111111111'$$,
  '23514', null, 'self-described gender requires a description'
);

select * from extensions.finish();
rollback;
