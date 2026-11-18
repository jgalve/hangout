begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(19);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'id-admin@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Admin"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'id-moderator@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Moderator"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'id-alpha@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('44444444-4444-4444-8444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'id-bravo@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now());

insert into public.moderator_roles (user_id, role, granted_by) values
  ('11111111-1111-4111-8111-111111111111', 'admin', '11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222', 'moderator', '11111111-1111-4111-8111-111111111111');

insert into public.identity_verification_requests (
  id, user_id, storage_path, status, consent_version, submitted_at
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '44444444-4444-4444-8444-444444444444', '44444444-4444-4444-8444-444444444444/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.jpg', 'pending', 'manual-id-review-v1', now()),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222/dddddddd-dddd-4ddd-8ddd-dddddddddddd.jpg', 'pending', 'manual-id-review-v1', now());

select extensions.ok(
  (select not public from storage.buckets where id = 'identity-documents'),
  'identity documents are stored in a private bucket'
);
select extensions.ok(
  not has_function_privilege('anon', 'public.begin_identity_verification_upload(boolean)', 'execute'),
  'anonymous users cannot begin ID uploads'
);
select extensions.ok(
  position('is_verified' in pg_get_function_result('public.discover_candidates(integer)'::regprocedure)) > 0,
  'discovery exposes only the public verification status'
);

set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.throws_ok(
  $$select * from public.identity_verification_requests$$,
  '42501', null, 'users cannot read verification request records directly'
);
select extensions.throws_ok(
  $$select * from public.moderator_identity_verification_queue()$$,
  '42501', null, 'ordinary users cannot access the ID review queue'
);
select extensions.throws_ok(
  $$select * from public.begin_identity_verification_upload(false)$$,
  'P0001', null, 'ID upload requires explicit consent'
);
select extensions.lives_ok(
  $$select * from public.begin_identity_verification_upload(true)$$,
  'an active user can reserve one ID upload after consent'
);
select extensions.is(
  (select status from public.my_identity_verification_status()),
  'uploading',
  'users can see their own upload status'
);
select extensions.throws_ok(
  $$select public.complete_identity_verification_upload((select request_id from public.my_identity_verification_status()))$$,
  'P0001', null, 'an upload without a stored image cannot be submitted'
);
select extensions.ok(
  public.withdraw_identity_verification((select request_id from public.my_identity_verification_status()))
    ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$',
  'users can withdraw their own unfinished request'
);
select extensions.is(
  public.finalize_identity_verification_cleanup((select request_id from public.my_identity_verification_status())),
  true,
  'withdrawn upload cleanup can be finalized after the file is absent'
);
select extensions.is(
  (select count(*) from public.identity_verification_events),
  0::bigint,
  'ordinary users cannot read ID review audit events'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select extensions.is(
  (select count(*) from public.moderator_identity_verification_queue()),
  1::bigint,
  'moderators can see pending requests but not their own'
);
select extensions.throws_ok(
  $$select public.moderate_identity_verification('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'verified')$$,
  'P0001', null, 'moderators cannot review their own ID'
);
select extensions.is(
  public.moderate_identity_verification('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'verified'),
  '44444444-4444-4444-8444-444444444444/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.jpg',
  'moderators can record a decision for another user'
);
select extensions.is(
  public.finalize_identity_verification_cleanup('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  true,
  'moderators can finalize cleanup after the file is absent'
);
select extensions.is(
  (select count(*) from public.identity_verification_events where user_id = '44444444-4444-4444-8444-444444444444'),
  2::bigint,
  'review decisions and image deletion are audited'
);

set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
select extensions.is(
  (select status from public.my_identity_verification_status()),
  'verified',
  'users can see their final verification status'
);
select extensions.throws_ok(
  $$select * from public.begin_identity_verification_upload(true)$$,
  'P0001', null, 'verified users cannot submit another ID'
);

select * from extensions.finish();
rollback;
