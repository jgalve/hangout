begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(25);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Admin"}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderator@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Moderator"}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alpha@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Alpha"}', now(), now()),
  ('44444444-4444-4444-8444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bravo@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Bravo"}', now(), now());

insert into public.moderator_roles (user_id, role, granted_by) values
  ('11111111-1111-4111-8111-111111111111', 'admin', '11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222', 'moderator', '11111111-1111-4111-8111-111111111111');

insert into public.matches (id, user_low, user_high)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-444444444444');

insert into public.reports (id, reporter_id, reported_id, match_id, reason, details)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'spam',
  'Test report'
);

set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.throws_ok(
  $$select * from public.admin_dashboard_stats()$$,
  '42501', null, 'ordinary users cannot read admin statistics'
);
select extensions.throws_ok(
  $$select * from public.admin_search_users('alpha')$$,
  '42501', null, 'ordinary users cannot search user names or email addresses'
);
select extensions.throws_ok(
  $$select * from public.moderator_report_queue()$$,
  '42501', null, 'ordinary users cannot access the moderation queue'
);
select extensions.throws_ok(
  $$select public.admin_set_account_active('44444444-4444-4444-8444-444444444444', false, 'Test')$$,
  '42501', null, 'ordinary users cannot deactivate accounts'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select extensions.throws_ok(
  $$select * from public.admin_dashboard_stats()$$,
  '42501', null, 'moderators cannot read admin-only statistics'
);
select extensions.throws_ok(
  $$select * from public.admin_search_users('alpha')$$,
  '42501', null, 'moderators cannot search private user email addresses'
);
select extensions.is(
  (select count(*) from public.moderator_report_queue()),
  1::bigint,
  'moderators can access the report queue'
);
select extensions.is(
  (select count(*) from public.account_status_events),
  0::bigint,
  'moderators cannot read admin account-status history'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select extensions.is(
  (select total_users from public.admin_dashboard_stats()),
  4::bigint,
  'admin statistics return the total user count'
);
select extensions.is(
  (select enabled_users from public.admin_dashboard_stats()),
  4::bigint,
  'admin statistics return enabled account count'
);
select extensions.is(
  (select matches_30d from public.admin_dashboard_stats()),
  1::bigint,
  'admin statistics return recent matches'
);
select extensions.is(
  (select pending_reports from public.admin_dashboard_stats()),
  1::bigint,
  'admin statistics include open reports'
);
select extensions.is(
  (select email from public.admin_search_users('ALPHA') where id = '33333333-3333-4333-8333-333333333333'),
  'alpha@example.test',
  'admin search supports case-insensitive name lookup and returns email'
);
select extensions.is(
  (select id from public.admin_search_users('BRAVO@EXAMPLE.TEST') where id = '44444444-4444-4444-8444-444444444444'),
  '44444444-4444-4444-8444-444444444444'::uuid,
  'admin search supports case-insensitive email lookup'
);
select extensions.is(
  public.admin_set_account_active('44444444-4444-4444-8444-444444444444', false, 'Safety review'),
  false,
  'admin can deactivate an account'
);
select extensions.ok(
  not (select account_active from public.profiles where id = '44444444-4444-4444-8444-444444444444'),
  'deactivation is persisted on the profile'
);
select extensions.is(
  (select count(*) from public.account_status_events where user_id = '44444444-4444-4444-8444-444444444444'),
  1::bigint,
  'deactivation creates an audit event'
);
select extensions.throws_ok(
  $$select public.admin_set_account_active('11111111-1111-4111-8111-111111111111', false, 'Self')$$,
  'P0001', 'You cannot deactivate your own admin account.', 'an admin cannot deactivate their own account'
);
select extensions.throws_ok(
  $$update public.account_status_events set reason = 'tampered' where user_id = '44444444-4444-4444-8444-444444444444'$$,
  '42501', null, 'account status history cannot be changed through the client API'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.throws_ok(
  $$select public.record_swipe('44444444-4444-4444-8444-444444444444', 'like')$$,
  'P0001', null, 'active users cannot swipe on a deactivated account'
);
set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
select extensions.throws_ok(
  $$insert into public.places (osm_type, osm_id, name, display_name, lat, lon) values ('node', 'inactive', 'Inactive place', 'Inactive place', 14.55, 121.02)$$,
  '42501', null, 'deactivated users cannot mutate the shared place catalog'
);
select extensions.is(
  (with updated as (
    update public.profiles set first_name = 'Changed' where id = '44444444-4444-4444-8444-444444444444'
    returning id
  ) select count(*) from updated),
  0::bigint,
  'deactivated users cannot update their profile through direct table access'
);
set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
select extensions.is(
  (select count(*) from public.matches),
  0::bigint,
  'deactivation removes that user from other users’ match access'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select public.moderate_report('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'resolved', 'Reviewed test case');
select extensions.is(
  (select status::text from public.reports where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  'resolved',
  'moderator can update a report through the protected action function'
);
select extensions.is(
  (select count(*) from public.moderation_audit_log),
  1::bigint,
  'report actions are written to the moderation audit log'
);

select * from extensions.finish();
rollback;
