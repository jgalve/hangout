begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(4);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'intention-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'intention-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now());

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'intention-test', 'Test cafe', 'Test cafe', 14.55, 121.02);

insert into public.profile_places (profile_id, place_id, position)
values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1);

update public.profiles
set first_name = 'Alpha',
    birth_date = date '1990-01-01',
    photo_url = 'https://example.test/alpha.jpg'
where id = '11111111-1111-4111-8111-111111111111';

update public.profiles
set first_name = 'Bravo',
    birth_date = date '1990-01-01',
    photo_url = 'https://example.test/bravo.jpg'
where id = '22222222-2222-4222-8222-222222222222';

select extensions.is(
  (select dating_intention from public.profiles where id = '11111111-1111-4111-8111-111111111111'),
  'Still figuring it out',
  'existing profiles receive the safe default intention'
);

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.is(
  (select candidate.dating_intention
   from public.discover_candidates(20) candidate
   where candidate.id = '22222222-2222-4222-8222-222222222222'),
  'Still figuring it out',
  'discovery returns a candidate primary intention'
);
update public.profiles
set dating_intention = 'Long-term relationship'
where id = '11111111-1111-4111-8111-111111111111';
select extensions.is(
  (select dating_intention from public.profiles where id = '11111111-1111-4111-8111-111111111111'),
  'Long-term relationship',
  'users can save one of the allowed primary intentions'
);
select extensions.throws_ok(
  $$update public.profiles set dating_intention = 'Anything goes' where id = '11111111-1111-4111-8111-111111111111'$$,
  '23514', null, 'database rejects unsupported intentions'
);

select * from extensions.finish();
rollback;
