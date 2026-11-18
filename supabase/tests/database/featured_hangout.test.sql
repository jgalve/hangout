begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(20);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'featured-admin@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Admin"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'featured-moderator@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Moderator"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'featured-member@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Member"}', now(), now());

insert into public.moderator_roles (user_id, role, granted_by) values
  ('11111111-1111-4111-8111-111111111111', 'admin', '11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222', 'moderator', '11111111-1111-4111-8111-111111111111');

set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';

select extensions.is(
  (select count(*) from public.get_featured_hangout()),
  1::bigint,
  'active users can read the single published featured hangout'
);
select extensions.is(
  (select venue_name from public.get_featured_hangout()),
  'Solaire Pasay',
  'the seeded sample uses the configured venue'
);
select extensions.is(
  (select place_id from public.get_featured_hangout()),
  (select id from public.places where osm_type = 'way' and osm_id = '32978383'),
  'the featured sample is linked to the canonical OSM place'
);
select extensions.is(
  (select osm_type from public.get_featured_hangout()),
  'way',
  'the featured map target uses an OpenStreetMap way'
);
select extensions.is(
  (select osm_id from public.get_featured_hangout()),
  '32978383',
  'the featured place exposes its map element identifier'
);
select extensions.ok(
  (select demo_only from public.get_featured_hangout()),
  'the published sample is explicitly marked as a demo'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.featured_hangout_settings', 'SELECT'),
  'authenticated users cannot read configuration rows directly'
);
select extensions.throws_ok(
  $$select * from public.admin_get_featured_hangout()$$,
  '42501', null,
  'ordinary users cannot read admin configuration'
);
select extensions.throws_ok(
  $$select * from public.admin_save_featured_hangout((select id from public.places where osm_type = 'way' and osm_id = '32978383'), 'Solaire Pasay', 'Demo', 'A demo promo concept for two people.', 'Demo only, not redeemable.', null, null, null, true, true)$$,
  '42501', null,
  'ordinary users cannot save admin configuration'
);
select extensions.ok(
  not has_function_privilege('anon', 'public.get_featured_hangout()', 'EXECUTE'),
  'anonymous users cannot read the featured hangout'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select extensions.throws_ok(
  $$select * from public.admin_get_featured_hangout()$$,
  '42501', null,
  'moderators cannot read admin configuration'
);
select extensions.throws_ok(
  $$select * from public.admin_save_featured_hangout((select id from public.places where osm_type = 'way' and osm_id = '32978383'), 'Solaire Pasay', 'Demo', 'A demo promo concept for two people.', 'Demo only, not redeemable.', null, null, null, true, true)$$,
  '42501', null,
  'moderators cannot save admin configuration'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.is(
  (select venue_name from public.admin_get_featured_hangout()),
  'Solaire Pasay',
  'admins can read the featured configuration'
);
select extensions.throws_ok(
  $$select * from public.admin_save_featured_hangout('00000000-0000-0000-0000-000000000000', 'Solaire Pasay', 'Demo', 'A demo promo concept for two people.', 'Demo only, not redeemable.', null, null, null, true, true)$$,
  'P0001', 'Select a valid place from the place catalog.',
  'admins cannot save an unknown place'
);
select extensions.throws_ok(
  $$select * from public.admin_save_featured_hangout((select id from public.places where osm_type = 'way' and osm_id = '32978383'), 'Solaire Pasay', 'Demo', 'A demo promo concept for two people.', 'Demo only, not redeemable.', 'http://example.test/photo.jpg', null, null, true, true)$$,
  'P0001', 'Photo URL must be a valid HTTPS URL.',
  'admins cannot save an insecure photo URL'
);
select extensions.is(
  (select count(*) from public.admin_save_featured_hangout(
    (select id from public.places where osm_type = 'way' and osm_id = '32978383'),
    'Solaire Pasay',
    'Sample: Date Night for Two',
    'A demo concept for a shared evening out. No discount, package, or venue benefit has been confirmed.',
    'SAMPLE ONLY. This is not a real Solaire Pasay offer, is not redeemable, and is not affiliated with the venue.',
    null, null, null, true, false
  )),
  1::bigint,
  'admins can save the featured hangout as a draft'
);
select extensions.is(
  (select count(*) from public.get_featured_hangout()),
  0::bigint,
  'draft configuration is not returned to Discover users'
);
select extensions.is(
  (select count(*) from public.admin_save_featured_hangout(
    (select id from public.places where osm_type = 'way' and osm_id = '32978383'),
    'Solaire Pasay',
    'Sample: Date Night for Two',
    'A demo concept for a shared evening out. No discount, package, or venue benefit has been confirmed.',
    'SAMPLE ONLY. This is not a real Solaire Pasay offer, is not redeemable, and is not affiliated with the venue.',
    null, null, null, true, true
  )),
  1::bigint,
  'admins can publish the configured sample'
);
select extensions.is(
  (select venue_name from public.get_featured_hangout()),
  'Solaire Pasay',
  'published configuration is returned to Discover users'
);
select extensions.ok(
  (select demo_only from public.get_featured_hangout()),
  'the sample disclaimer state is preserved after publishing'
);

select * from extensions.finish();
rollback;
