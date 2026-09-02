#!/usr/bin/env bash
set -euo pipefail

database_container="supabase_db_fanatical-local"
database_command=(
  docker exec -i "$database_container"
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q
)
fan_a="87000000-0000-0000-0000-000000000011"
fan_b="87000000-0000-0000-0000-000000000012"
staff_c="87000000-0000-0000-0000-000000000013"
submit_first_log="/tmp/fanatical-phase5a-request-submit-first.log"
resolve_after_log="/tmp/fanatical-phase5a-request-resolve-after.log"
resolve_first_log="/tmp/fanatical-phase5a-request-resolve-first.log"
submit_after_log="/tmp/fanatical-phase5a-request-submit-after.log"

cleanup() {
  "${database_command[@]}" >/dev/null <<SQL
begin;
alter table public.news_follow_request_resolution_decisions
  disable trigger protect_news_request_resolution_decisions;
alter table public.user_news_follow_requests
  disable trigger protect_user_news_follow_requests;
delete from public.community_notifications
where user_id in ('$fan_a'::uuid, '$fan_b'::uuid, '$staff_c'::uuid)
   or requester_relation_id in (
     select request.id
     from public.user_news_follow_requests request
     join public.news_follow_request_targets target
       on target.id = request.request_target_id
     where target.normalized_input in (
       'phase 5 submit first race',
       'phase 5 resolve first race'
     )
   );
delete from public.news_follow_request_resolution_decisions decision
using public.news_follow_request_targets target
where target.id = decision.request_target_id
  and target.normalized_input in (
    'phase 5 submit first race',
    'phase 5 resolve first race'
  );
delete from public.user_news_follow_requests request
using public.news_follow_request_targets target
where target.id = request.request_target_id
  and target.normalized_input in (
    'phase 5 submit first race',
    'phase 5 resolve first race'
  );
delete from public.news_follow_request_targets
where normalized_input in (
  'phase 5 submit first race',
  'phase 5 resolve first race'
);
delete from public.staff_roles where user_id = '$staff_c'::uuid;
delete from auth.users
where id in ('$fan_a'::uuid, '$fan_b'::uuid, '$staff_c'::uuid);
alter table public.news_follow_request_resolution_decisions
  enable trigger protect_news_request_resolution_decisions;
alter table public.user_news_follow_requests
  enable trigger protect_user_news_follow_requests;
commit;
SQL
}

show_logs_and_fail() {
  echo "A Phase 5A Request concurrency session failed." >&2
  for log_path in \
    "$submit_first_log" "$resolve_after_log" \
    "$resolve_first_log" "$submit_after_log"; do
    if [[ -f "$log_path" ]]; then
      sed -n '1,100p' "$log_path" >&2
    fi
  done
  exit 1
}

trap cleanup EXIT
cleanup

"${database_command[@]}" >/dev/null <<SQL
insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000', '$fan_a',
    'authenticated', 'authenticated',
    'phase5a-request-a@fanatical.invalid', '', now(), '{}'::jsonb,
    '{"display_name":"Phase 5A Request A"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000', '$fan_b',
    'authenticated', 'authenticated',
    'phase5a-request-b@fanatical.invalid', '', now(), '{}'::jsonb,
    '{"display_name":"Phase 5A Request B"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000', '$staff_c',
    'authenticated', 'authenticated',
    'phase5a-request-staff@fanatical.invalid', '', now(), '{}'::jsonb,
    '{"display_name":"Phase 5A Request Staff"}'::jsonb, now(), now()
  );

insert into public.staff_roles(user_id, role, permissions, is_active)
values ('$staff_c'::uuid, 'admin', array['community_moderate', 'news_request_resolve']::text[], true);

do \$fixture\$
begin
  if not exists (
    select 1
    from private.current_news_followable_identities() followable
    where followable.target_type = 'organization'
      and followable.display_name = 'FANatical Local Demo Desk'
  ) then
    raise exception 'The governed local followable organization fixture is required';
  end if;
end
\$fixture\$;

begin;
select set_config('request.jwt.claim.sub', '$fan_a', true);
set local role authenticated;
select public.submit_news_follow_request('name', 'Phase 5 Submit First Race');
select public.submit_news_follow_request('name', 'Phase 5 Resolve First Race');
commit;
SQL

# Submit holds the shared target row; resolution waits, then notifies both
# requesters exactly once when the submit transaction commits.
"${database_command[@]}" >"$submit_first_log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub', '$fan_b', true);
set local role authenticated;
select public.submit_news_follow_request('name', 'Phase 5 Submit First Race');
select pg_sleep(0.5);
commit;
SQL
submit_first_pid=$!
sleep 0.1
"${database_command[@]}" >"$resolve_after_log" 2>&1 <<SQL &
begin;
select set_config(
  'test.phase5a.request_target',
  (
    select target.request_target_id
    from public.news_follow_request_targets target
    where target.normalized_input = 'phase 5 submit first race'
  ),
  true
);
select set_config(
  'test.phase5a.follow_target',
  (
    select followable.target_id
    from private.current_news_followable_identities() followable
    where followable.target_type = 'organization'
      and followable.display_name = 'FANatical Local Demo Desk'
  ),
  true
);
select set_config('request.jwt.claim.sub', '$staff_c', true);
set local role authenticated;
select public.admin_resolve_news_follow_request(
  current_setting('test.phase5a.request_target'),
  'available',
  'organization',
  current_setting('test.phase5a.follow_target'),
  'Concurrent submit-first resolution proof.'
);
commit;
SQL
resolve_after_pid=$!

wait "$submit_first_pid" || show_logs_and_fail
wait "$resolve_after_pid" || show_logs_and_fail

# Resolution holds the shared target row; a later submit waits, observes the
# terminal state, and creates its own one idempotent final notification.
"${database_command[@]}" >"$resolve_first_log" 2>&1 <<SQL &
begin;
select set_config(
  'test.phase5a.request_target',
  (
    select target.request_target_id
    from public.news_follow_request_targets target
    where target.normalized_input = 'phase 5 resolve first race'
  ),
  true
);
select set_config(
  'test.phase5a.follow_target',
  (
    select followable.target_id
    from private.current_news_followable_identities() followable
    where followable.target_type = 'organization'
      and followable.display_name = 'FANatical Local Demo Desk'
  ),
  true
);
select set_config('request.jwt.claim.sub', '$staff_c', true);
set local role authenticated;
select public.admin_resolve_news_follow_request(
  current_setting('test.phase5a.request_target'),
  'available',
  'organization',
  current_setting('test.phase5a.follow_target'),
  'Concurrent resolve-first resolution proof.'
);
select pg_sleep(0.5);
commit;
SQL
resolve_first_pid=$!
sleep 0.1
"${database_command[@]}" >"$submit_after_log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub', '$fan_b', true);
set local role authenticated;
select public.submit_news_follow_request('name', 'Phase 5 Resolve First Race');
commit;
SQL
submit_after_pid=$!

wait "$resolve_first_pid" || show_logs_and_fail
wait "$submit_after_pid" || show_logs_and_fail

"${database_command[@]}" >/dev/null <<SQL
do \$proof\$
declare
  target_record record;
begin
  for target_record in
    select target.id, target.normalized_input, target.resolution_state
    from public.news_follow_request_targets target
    where target.normalized_input in (
      'phase 5 submit first race',
      'phase 5 resolve first race'
    )
  loop
    if target_record.resolution_state <> 'available'
      or (select count(*) from public.user_news_follow_requests request
          where request.request_target_id = target_record.id) <> 2
      or (select count(*) from public.news_follow_request_resolution_decisions decision
          where decision.request_target_id = target_record.id) <> 1
      or exists (
        select 1
        from public.user_news_follow_requests request
        left join public.community_notifications notification
          on notification.requester_relation_id = request.id
         and notification.notification_type = 'request_available'
        where request.request_target_id = target_record.id
        group by request.id
        having count(notification.id) <> 1
      ) then
      raise exception 'Request race % did not converge on two requester relations with one final notification each',
        target_record.normalized_input;
    end if;
  end loop;

  if (select count(*) from public.news_follow_request_targets target
      where target.normalized_input in (
        'phase 5 submit first race',
        'phase 5 resolve first race'
      )) <> 2
    or exists (
      select 1
      from public.user_news_identity_follows follow_record
      where follow_record.user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
    ) then
    raise exception 'Request races duplicated a target or auto-Followed a requester';
  end if;
end
\$proof\$;
SQL

echo "Passed Phase 5A submit-before-resolve and resolve-before-submit concurrency tests."
