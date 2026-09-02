-- Transactional proof that catalog agent/service identities remain outside
-- the fan population and automatically protect their canonical identifiers.

begin;

create or replace function pg_temp.assert_true(
  condition_value boolean,
  message_value text
)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition_value, false) then
    raise exception 'Operational identity assertion failed: %', message_value;
  end if;
end;
$$;

create or replace function pg_temp.assert_statement_rejected(
  statement_value text,
  expected_message_fragment text,
  message_value text
)
returns void
language plpgsql
as $$
begin
  begin
    execute statement_value;
  exception
    when others then
      if position(lower(expected_message_fragment) in lower(sqlerrm)) = 0 then
        raise exception 'Operational identity assertion failed: % (unexpected error: %)',
          message_value,
          sqlerrm;
      end if;
      return;
  end;

  raise exception 'Operational identity assertion failed: % (statement unexpectedly succeeded)',
    message_value;
end;
$$;

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '84000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'proof-agent@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Proof Agent"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '84000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'proof-service@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Proof Service"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '84000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'proof-fan@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Proof Fan"}'::jsonb, now(), now()
  );

insert into public.catalog_actors(
  id, actor_key, actor_type, auth_user_id, display_name, active
)
values
  (
    '84100000-0000-0000-0000-000000000001',
    'ProofAgent',
    'agent',
    '84000000-0000-0000-0000-000000000001',
    'Proof Agent',
    true
  ),
  (
    '84100000-0000-0000-0000-000000000002',
    'openclaw-proof-service',
    'service',
    '84000000-0000-0000-0000-000000000002',
    'Proof Service',
    false
  );

update public.profiles
set handle = 'ProofFan'
where user_id = '84000000-0000-0000-0000-000000000003';

select pg_temp.assert_true(
  (
    select count(*) = 4
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.reservation_source = 'manual'
      and reservation.normalized_value = any(array[
        'informationlineageresolver',
        'informationlineagereviewer',
        'sourcequalificationagent',
        'teamcoloragent'
      ])
  ),
  'all four released legacy operational handles must remain manually reserved'
);

select pg_temp.assert_true(
  exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = 'proofagent'
      and reservation.reservation_source = 'catalog_actor'
      and reservation.catalog_actor_id = '84100000-0000-0000-0000-000000000001'
  ),
  'an active agent actor_key must create a case-normalized automatic reservation'
);

select pg_temp.assert_true(
  exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = 'openclaw-proof-service'
      and reservation.reservation_source = 'catalog_actor'
      and reservation.catalog_actor_id = '84100000-0000-0000-0000-000000000002'
  ),
  'an inactive service must reserve its unchanged canonical actor_key, including punctuation'
);

select pg_temp.assert_true(
  (
    select count(*) = 2
    from public.profiles profile
    where profile.user_id in (
      '84000000-0000-0000-0000-000000000001',
      '84000000-0000-0000-0000-000000000002'
    )
      and profile.handle = ''
  ),
  'shared Auth bootstrap may retain technical operational profiles, but both handles must be unclaimed'
);

select pg_temp.assert_true(
  (
    select count(*) = 1
    from private.fan_profile_population fan_profile
    where fan_profile.user_id in (
      '84000000-0000-0000-0000-000000000001',
      '84000000-0000-0000-0000-000000000002',
      '84000000-0000-0000-0000-000000000003'
    )
      and fan_profile.user_id = '84000000-0000-0000-0000-000000000003'
  ),
  'the canonical fan population must exclude both active and inactive operational identities'
);

select set_config(
  'request.jwt.claim.sub',
  '84000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('ProofAgent') is null,
  'an active agent profile must not appear through the signed-in fan profile boundary'
);
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('ProofService') is null,
  'an inactive service profile must not appear through the signed-in fan profile boundary'
);
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('ProofFan') is not null,
  'an ordinary fan profile must remain addressable to itself'
);
reset role;

select pg_temp.assert_statement_rejected(
  $statement$
    update public.profiles
    set handle = 'OperationalFan'
    where user_id = '84000000-0000-0000-0000-000000000001'
  $statement$,
  'cannot claim public fan handles',
  'an agent-linked profile must not claim an unrelated fan handle'
);

select pg_temp.assert_statement_rejected(
  $statement$
    update public.profiles
    set handle = 'RetiredService'
    where user_id = '84000000-0000-0000-0000-000000000002'
  $statement$,
  'cannot claim public fan handles',
  'an inactive service identity must not become a fan merely because it is inactive'
);

select pg_temp.assert_statement_rejected(
  $statement$
    update public.profiles
    set handle = 'pRoOfAgEnT'
    where user_id = '84000000-0000-0000-0000-000000000003'
  $statement$,
  'reserved',
  'a fan must not claim an active operational identifier case-insensitively'
);

select set_config(
  'request.jwt.claim.sub',
  '84000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $statement$
    select public.save_my_profile(
      '{"display_name":"Proof Agent","handle":"AgentPublic","featured_fan_photo_category":"Fan Cave","visibility":"public"}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb
    )
  $statement$,
  'ordinary fan profile',
  'the authenticated profile-write RPC must reject operational identities through the canonical ordinary-fan guard'
);
reset role;

select pg_temp.assert_statement_rejected(
  $statement$
    delete from private.profile_handle_reservations
    where reservation_type = 'exact'
      and normalized_value = 'proofagent'
  $statement$,
  'cannot be removed',
  'an active actor current-identifier reservation must not be removable'
);

select pg_temp.assert_statement_rejected(
  $statement$
    update private.profile_handle_reservations
    set normalized_value = 'stolenagent'
    where reservation_type = 'exact'
      and normalized_value = 'proofagent'
  $statement$,
  'cannot be reassigned',
  'an active actor current-identifier reservation must not be reassigned'
);

insert into private.profile_handle_reservations(
  reservation_type, normalized_value, reason
)
values ('exact', 'temporarymanualreservation', 'Transactional manual proof');
delete from private.profile_handle_reservations
where reservation_type = 'exact'
  and normalized_value = 'temporarymanualreservation';
select pg_temp.assert_true(
  not exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = 'temporarymanualreservation'
  ),
  'a manual reservation must remain removable'
);

update public.catalog_actors
set actor_key = 'ProofAgentRenamed'
where id = '84100000-0000-0000-0000-000000000001';

select pg_temp.assert_true(
  exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = 'proofagentrenamed'
      and reservation.reservation_source = 'catalog_actor'
      and reservation.catalog_actor_id = '84100000-0000-0000-0000-000000000001'
  ),
  'renaming an active actor must automatically reserve the new canonical identifier'
);

delete from private.profile_handle_reservations
where reservation_type = 'exact'
  and normalized_value = 'proofagent';
select pg_temp.assert_true(
  not exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = 'proofagent'
  ),
  'the old automatic reservation must become removable after an actor rename'
);

update public.catalog_actors
set active = false
where id = '84100000-0000-0000-0000-000000000001';
delete from private.profile_handle_reservations
where reservation_type = 'exact'
  and normalized_value = 'proofagentrenamed';
select pg_temp.assert_true(
  not exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = 'proofagentrenamed'
  ),
  'an automatic reservation must become removable after operational retirement'
);

select pg_temp.assert_true(
  exists (
    select 1
    from public.catalog_actors actor
    where actor.id = '84100000-0000-0000-0000-000000000001'
      and actor.auth_user_id = '84000000-0000-0000-0000-000000000001'
      and actor.actor_type = 'agent'
      and not actor.active
  ),
  'removing a retired reservation must preserve the permanent actor and Auth linkage'
);

update public.catalog_actors
set active = true
where id = '84100000-0000-0000-0000-000000000001';
select pg_temp.assert_true(
  exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = 'proofagentrenamed'
      and reservation.catalog_actor_id = '84100000-0000-0000-0000-000000000001'
  ),
  'reactivating an operational identity must restore its current automatic reservation'
);

delete from private.profile_handle_reservations
where reservation_type = 'exact'
  and normalized_value = 'openclaw-proof-service';
select pg_temp.assert_true(
  exists (
    select 1
    from public.catalog_actors actor
    where actor.id = '84100000-0000-0000-0000-000000000002'
      and not actor.active
  ),
  'removing an inactive service reservation must leave the service identity intact'
);

insert into public.catalog_actors(
  id, actor_key, actor_type, display_name, active
)
values (
  '84100000-0000-0000-0000-000000000003',
  'DormantService',
  'service',
  'Dormant Service',
  false
);
delete from private.profile_handle_reservations
where reservation_type = 'exact'
  and normalized_value = 'dormantservice';
update public.profiles
set handle = 'DormantService'
where user_id = '84000000-0000-0000-0000-000000000003';

select pg_temp.assert_statement_rejected(
  $statement$
    update public.catalog_actors
    set active = true
    where id = '84100000-0000-0000-0000-000000000003'
  $statement$,
  'conflicts with an existing claimed handle',
  'an operational actor must not become active while a fan holds its identifier'
);
select pg_temp.assert_true(
  (
    select not actor.active
    from public.catalog_actors actor
    where actor.id = '84100000-0000-0000-0000-000000000003'
  ),
  'a rejected activation must leave the operational actor inactive'
);

rollback;
