begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'free@test.local'),
  ('22222222-2222-4222-8222-222222222222', 'premium@test.local'),
  ('33333333-3333-4333-8333-333333333333', 'expired@test.local'),
  ('44444444-4444-4444-8444-444444444444', 'target@test.local');

select public.apply_entitlement(
  '22222222-2222-4222-8222-222222222222', true, now() + interval '30 days', now()
);
select public.apply_entitlement(
  '33333333-3333-4333-8333-333333333333', true, now() - interval '1 day', now()
);

-- free user
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';

select throws_ok(
  $$ insert into public.backups (user_id, content)
     values ('11111111-1111-4111-8111-111111111111', '{}') $$,
  '42501', null, 'non-premium user cannot insert a backup'
);
select throws_ok(
  $$ insert into public.entitlements (user_id, is_premium, expires_at)
     values ('11111111-1111-4111-8111-111111111111', true, now() + interval '1 year') $$,
  '42501', null, 'user cannot insert into entitlements'
);
select throws_ok(
  $$ update public.entitlements set is_premium = true $$,
  '42501', null, 'user cannot update entitlements'
);
select throws_ok(
  $$ select public.apply_entitlement(
       '11111111-1111-4111-8111-111111111111', true, now() + interval '1 year', now()) $$,
  '42501', null, 'user cannot call apply_entitlement'
);
select throws_ok(
  $$ select public.transfer_entitlement(
       array['22222222-2222-4222-8222-222222222222']::uuid[],
       '11111111-1111-4111-8111-111111111111', null, now()) $$,
  '42501', null, 'user cannot call transfer_entitlement'
);
select is(
  public.is_premium('22222222-2222-4222-8222-222222222222'), false,
  'is_premium does not reveal another user''s status'
);
select is(
  (select count(*) from public.entitlements)::int, 0,
  'user sees no entitlement rows of other users'
);

-- expired premium
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';

select throws_ok(
  $$ insert into public.backups (user_id, content)
     values ('33333333-3333-4333-8333-333333333333', '{}') $$,
  '42501', null, 'expired premium cannot insert a backup'
);
select is(
  public.is_premium('33333333-3333-4333-8333-333333333333'), false,
  'expired premium is not premium'
);

-- active premium
set local request.jwt.claims to '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}';

select is(
  public.is_premium('22222222-2222-4222-8222-222222222222'), true,
  'active premium is premium'
);
select lives_ok(
  $$ insert into public.backups (user_id, content)
     values ('22222222-2222-4222-8222-222222222222', '{"v":1}') $$,
  'active premium can insert a backup'
);
select lives_ok(
  $$ update public.backups set content = '{"v":2}'
     where user_id = '22222222-2222-4222-8222-222222222222' $$,
  'active premium can update a backup'
);
select is(
  (select content ->> 'v' from public.backups
   where user_id = '22222222-2222-4222-8222-222222222222'),
  '2', 'premium update was stored'
);
select is(
  (select count(*) from public.entitlements)::int, 1,
  'user sees only their own entitlement row'
);

reset role;
insert into public.backups (user_id, content) values
  ('11111111-1111-4111-8111-111111111111', '{"v":1}'),
  ('33333333-3333-4333-8333-333333333333', '{"v":1}');

set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';

select throws_ok(
  $$ update public.backups set content = '{"v":9}'
     where user_id = '11111111-1111-4111-8111-111111111111' $$,
  '42501', null, 'non-premium user cannot update a backup'
);
select is(
  (select content ->> 'v' from public.backups
   where user_id = '11111111-1111-4111-8111-111111111111'),
  '1', 'non-premium user can still read (restore) their backup'
);
select is(
  (select count(*) from public.backups)::int, 1,
  'user reads only their own backup'
);

set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';

select throws_ok(
  $$ update public.backups set content = '{"v":9}'
     where user_id = '33333333-3333-4333-8333-333333333333' $$,
  '42501', null, 'expired premium cannot update a backup'
);
select is(
  (select content ->> 'v' from public.backups
   where user_id = '33333333-3333-4333-8333-333333333333'),
  '1', 'expired premium can still read (restore) their backup'
);

-- webhook writes (service role)
reset role;
set local role service_role;

select public.apply_entitlement(
  '22222222-2222-4222-8222-222222222222', false, now(), now() - interval '1 hour'
);
select is(
  (select is_premium from public.entitlements
   where user_id = '22222222-2222-4222-8222-222222222222'),
  true, 'an older event does not overwrite a newer one'
);

select public.apply_entitlement(
  '33333333-3333-4333-8333-333333333333', true, now() + interval '1 year', now() + interval '1 second'
);
select is(
  (select expires_at > now() from public.entitlements
   where user_id = '33333333-3333-4333-8333-333333333333'),
  true, 'a newer event overwrites the stored row'
);

select lives_ok(
  $$ select public.apply_entitlement(
       '99999999-9999-4999-8999-999999999999', true, now() + interval '1 year', now()) $$,
  'an event for a deleted user is skipped without error'
);
select is(
  (select count(*) from public.entitlements
   where user_id = '99999999-9999-4999-8999-999999999999')::int,
  0, 'no row is created for an unknown user'
);

select public.transfer_entitlement(
  array['22222222-2222-4222-8222-222222222222']::uuid[],
  '44444444-4444-4444-8444-444444444444', null, now() + interval '2 seconds'
);
select is(
  (select is_premium and expires_at > now() + interval '29 days' from public.entitlements
   where user_id = '44444444-4444-4444-8444-444444444444'),
  true, 'transfer moves the subscription to the destination'
);
select is(
  (select is_premium from public.entitlements
   where user_id = '22222222-2222-4222-8222-222222222222'),
  false, 'transfer revokes the source'
);

select * from finish();
rollback;
