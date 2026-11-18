begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(8);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'profile-view-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'profile-view-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'profile-view-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now());

update public.profiles
set first_name = 'Bravo',
    birth_date = date '1990-01-01',
    bio = 'Likes quiet cafes.',
    photo_url = 'https://example.test/bravo.jpg',
    additional_photo_urls = array['https://example.test/bravo-2.jpg', null]::text[],
    hangout_personality = array['Coffee', 'Explore', 'Foodie']::text[],
    custom_hangout_personality = 'Reader',
    gender_identity = 'woman'
where id = '22222222-2222-4222-8222-222222222222';

insert into public.places (id, osm_type, osm_id, name, display_name, lat, lon)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'node', 'profile-view-test', 'Test cafe', 'Test cafe', 14.55, 121.02);

insert into public.profile_places (profile_id, place_id, position)
values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1),
  ('22222222-2222-4222-8222-222222222222', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1);

update public.profile_places
set place_story = 'A favorite quiet spot.'
where profile_id = '22222222-2222-4222-8222-222222222222';

insert into public.matches (id, user_low, user_high, shared_place_id)
values (
  '44444444-4444-4444-8444-444444444444',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
);

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select extensions.is(
  (select id from public.get_match_profile('44444444-4444-4444-8444-444444444444')),
  '22222222-2222-4222-8222-222222222222'::uuid,
  'a match can view the other matched profile'
);

select extensions.is(
  (select first_name from public.get_match_profile('44444444-4444-4444-8444-444444444444')),
  'Bravo',
  'the match profile returns the expected name'
);

select extensions.is(
  (select age::text || '|' || zodiac_sign from public.get_match_profile('44444444-4444-4444-8444-444444444444')),
  extract(year from age(current_date, date '1990-01-01'))::integer::text || '|Capricorn',
  'the match profile returns age and zodiac but not birth date'
);

select extensions.is(
  (select array_to_string(hangout_personality, ',') || '|' || custom_hangout_personality
   from public.get_match_profile('44444444-4444-4444-8444-444444444444')),
  'Coffee,Explore,Foodie|Reader',
  'the match profile returns hangout personalities'
);

select extensions.is(
  (select shared_places->0->>'story'
   from public.get_match_profile('44444444-4444-4444-8444-444444444444')),
  'A favorite quiet spot.',
  'the match profile returns stories only for shared places'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.is(
  (select count(*) from public.get_match_profile('44444444-4444-4444-8444-444444444444')),
  0::bigint,
  'a non-match cannot view the profile'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), '22222222-2222-4222-8222-222222222222');
select extensions.is(
  (select count(*) from public.get_match_profile('44444444-4444-4444-8444-444444444444')),
  0::bigint,
  'blocked matches cannot view the profile'
);

select extensions.ok(
  not has_function_privilege('anon', 'public.get_match_profile(uuid)', 'EXECUTE'),
  'anonymous users cannot view match profiles'
);

select * from extensions.finish();
rollback;
