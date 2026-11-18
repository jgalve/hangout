begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(6);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'social-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'social-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'social-c@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Charlie"}', now(), now());

update public.profiles
set facebook_url = 'https://www.facebook.com/bravo',
    instagram_url = 'https://www.instagram.com/bravo',
    tiktok_url = 'https://www.tiktok.com/@bravo'
where id = '22222222-2222-4222-8222-222222222222';

insert into public.matches (id, user_low, user_high)
values (
  '44444444-4444-4444-8444-444444444444',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222'
);

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select extensions.is(
  (select array[facebook_url, instagram_url, tiktok_url]
   from public.get_match_social_links('44444444-4444-4444-8444-444444444444')),
  array[
    'https://www.facebook.com/bravo',
    'https://www.instagram.com/bravo',
    'https://www.tiktok.com/@bravo'
  ],
  'a match can read the other profile social links'
);

select extensions.is(
  (select count(*) from public.profiles where id = '22222222-2222-4222-8222-222222222222'),
  0::bigint,
  'a match cannot read social links directly from another profile'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.is(
  (select count(*) from public.get_match_social_links('44444444-4444-4444-8444-444444444444')),
  0::bigint,
  'a non-match cannot read social links'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select extensions.throws_ok(
  $$update public.profiles
    set facebook_url = 'https://facebook.com.attacker.example/bravo'
    where id = auth.uid()$$,
  '23514', null, 'database rejects non-Facebook hosts'
);

select extensions.throws_ok(
  $$update public.profiles
    set instagram_url = 'http://www.instagram.com/bravo'
    where id = auth.uid()$$,
  '23514', null, 'database requires HTTPS social links'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), '22222222-2222-4222-8222-222222222222');
select extensions.is(
  (select count(*) from public.get_match_social_links('44444444-4444-4444-8444-444444444444')),
  0::bigint,
  'blocked users cannot read match social links'
);

select * from extensions.finish();
rollback;
