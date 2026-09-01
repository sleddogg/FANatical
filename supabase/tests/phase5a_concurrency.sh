#!/usr/bin/env bash
set -euo pipefail

database_container="supabase_db_fanatical-local"
database_command=(
  docker exec -i "$database_container"
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q
)
fan_a="85000000-0000-0000-0000-000000000011"
fan_b="85000000-0000-0000-0000-000000000012"
race_a_log="/tmp/fanatical-phase5a-handle-race-a.log"
race_b_log="/tmp/fanatical-phase5a-handle-race-b.log"
comment_a_log="/tmp/fanatical-phase5a-comment-race-a.log"
comment_b_log="/tmp/fanatical-phase5a-comment-race-b.log"

cleanup() {
  "${database_command[@]}" >/dev/null <<SQL
begin;
alter table public.community_comment_versions
  disable trigger protect_community_comment_versions;
alter table public.community_posting_restrictions
  disable trigger protect_community_posting_restrictions;
alter table public.community_moderation_actions
  disable trigger protect_community_moderation_actions;
delete from public.community_notifications
where user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
   or actor_user_id in ('$fan_a'::uuid, '$fan_b'::uuid);
delete from public.community_moderation_notices
where user_id in ('$fan_a'::uuid, '$fan_b'::uuid);
delete from public.community_moderation_actions
where staff_user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
   or target_user_id in ('$fan_a'::uuid, '$fan_b'::uuid);
delete from public.community_posting_restrictions
where user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
   or applied_by_staff_user_id in ('$fan_a'::uuid, '$fan_b'::uuid);
delete from public.community_reports
where reporting_user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
   or comment_id in (
     select id from public.community_comments
     where author_user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
   );
delete from public.community_comment_versions
where comment_id in (
  select id from public.community_comments
  where author_user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
);
delete from public.community_comments
where author_user_id in ('$fan_a'::uuid, '$fan_b'::uuid);
delete from public.community_discussions discussion
where discussion.created_by_user_id in ('$fan_a'::uuid, '$fan_b'::uuid)
  and not exists (
    select 1 from public.community_comments comment
    where comment.discussion_id = discussion.id
  );
delete from public.community_hide_intents
where hider_id in ('$fan_a'::uuid, '$fan_b'::uuid)
   or hidden_id in ('$fan_a'::uuid, '$fan_b'::uuid);
delete from auth.users where id in ('$fan_a'::uuid, '$fan_b'::uuid);
alter table public.community_comment_versions
  enable trigger protect_community_comment_versions;
alter table public.community_posting_restrictions
  enable trigger protect_community_posting_restrictions;
alter table public.community_moderation_actions
  enable trigger protect_community_moderation_actions;
commit;
SQL
}

trap cleanup EXIT
cleanup

"${database_command[@]}" >/dev/null <<SQL
do \$fixture\$
begin
  if exists (
    select 1
    from public.community_discussions discussion
    join public.news_items item on item.id = discussion.news_item_id
    join public.news_item_versions version
      on version.news_item_id = item.id and version.is_current
    join public.catalog_teams team on team.id = discussion.team_id
    where version.headline = 'Demo Desk: Oilers set their opening-night focus'
      and discussion.context_kind = 'team'
      and team.team_id = 'hockey-000027'
  ) then
    raise exception 'Phase 5A concurrency context is not empty; reset the local acceptance baseline first';
  end if;
end
\$fixture\$;

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000', '$fan_a',
    'authenticated', 'authenticated',
    'phase5a-concurrency-a@fanatical.invalid', '', now(), '{}'::jsonb,
    '{"display_name":"Phase 5A Concurrency A"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000', '$fan_b',
    'authenticated', 'authenticated',
    'phase5a-concurrency-b@fanatical.invalid', '', now(), '{}'::jsonb,
    '{"display_name":"Phase 5A Concurrency B"}'::jsonb, now(), now()
  );

insert into public.user_followed_teams(user_id, team_id, sort_order)
values
  ('$fan_a'::uuid, 'hockey-000027', 0),
  ('$fan_b'::uuid, 'hockey-000027', 0);
SQL

"${database_command[@]}" >"$race_a_log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub', '$fan_a', true);
set local role authenticated;
select public.set_my_fanatical_name('RaceFan');
select pg_sleep(0.5);
commit;
SQL
race_a_pid=$!
sleep 0.1
"${database_command[@]}" >"$race_b_log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub', '$fan_b', true);
set local role authenticated;
select public.set_my_fanatical_name('racefan');
commit;
SQL
race_b_pid=$!

set +e
wait "$race_a_pid"
race_a_status=$?
wait "$race_b_pid"
race_b_status=$?
set -e

if [[ "$race_a_status" -eq 0 && "$race_b_status" -eq 0 ]] \
  || [[ "$race_a_status" -ne 0 && "$race_b_status" -ne 0 ]]; then
  echo "The Fanatical Name race did not produce exactly one winner." >&2
  sed -n '1,80p' "$race_a_log" >&2
  sed -n '1,80p' "$race_b_log" >&2
  exit 1
fi

# Normalize ownership independently of process scheduling, then record history
# while A owns RaceFan and prove immediate release and reclaim.
"${database_command[@]}" >/dev/null <<SQL
begin;
select set_config('request.jwt.claim.sub', '$fan_b', true);
set local role authenticated;
select public.set_my_fanatical_name('ConcurrencyTwo');
commit;

begin;
select set_config('request.jwt.claim.sub', '$fan_a', true);
set local role authenticated;
select public.set_my_fanatical_name('RaceFan');
commit;
SQL

"${database_command[@]}" >/dev/null <<SQL
begin;
select set_config('request.jwt.claim.sub', '$fan_a', true);
select set_config(
  'test.phase5a.sport_item',
  (
    select item.news_item_id
    from public.news_items item
    join public.news_item_versions version
      on version.news_item_id = item.id and version.is_current
    where version.headline = 'Local Demo Podcast: Morning skate briefing'
  ),
  true
);
set local role authenticated;
select public.post_news_discussion_comment(
  current_setting('test.phase5a.sport_item'),
  'sport',
  'hockey',
  'History remains with the first UUID'
);
select public.set_my_fanatical_name('ConcurrencyOne');
commit;

begin;
select set_config('request.jwt.claim.sub', '$fan_b', true);
set local role authenticated;
select public.set_my_fanatical_name('RACEFAN');
commit;
SQL

# Hold A's transaction open after the first insert so B must wait on the same
# Item+Team advisory key. Both authenticated submissions must still converge.
"${database_command[@]}" >"$comment_a_log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub', '$fan_a', true);
select set_config(
  'test.phase5a.team_item',
  (
    select item.news_item_id
    from public.news_items item
    join public.news_item_versions version
      on version.news_item_id = item.id and version.is_current
    where version.headline = 'Demo Desk: Oilers set their opening-night focus'
  ),
  true
);
set local role authenticated;
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'),
  'team',
  'hockey-000027',
  'Concurrent first comment A'
);
select pg_sleep(0.5);
commit;
SQL
comment_a_pid=$!
sleep 0.1
"${database_command[@]}" >"$comment_b_log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub', '$fan_b', true);
select set_config(
  'test.phase5a.team_item',
  (
    select item.news_item_id
    from public.news_items item
    join public.news_item_versions version
      on version.news_item_id = item.id and version.is_current
    where version.headline = 'Demo Desk: Oilers set their opening-night focus'
  ),
  true
);
set local role authenticated;
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'),
  'team',
  'hockey-000027',
  'Concurrent first comment B'
);
commit;
SQL
comment_b_pid=$!

if ! wait "$comment_a_pid"; then
  sed -n '1,100p' "$comment_a_log" >&2
  exit 1
fi
if ! wait "$comment_b_pid"; then
  sed -n '1,100p' "$comment_b_log" >&2
  exit 1
fi

"${database_command[@]}" >/dev/null <<SQL
do \$proof\$
declare
  team_discussion_count integer;
  team_comment_count integer;
  team_durable_count bigint;
  history_author uuid;
  history_payload jsonb;
begin
  select count(*), coalesce(sum(discussion.comment_count), 0)
  into team_discussion_count, team_durable_count
  from public.community_discussions discussion
  join public.news_items item on item.id = discussion.news_item_id
  join public.news_item_versions version
    on version.news_item_id = item.id and version.is_current
  join public.catalog_teams team on team.id = discussion.team_id
  where version.headline = 'Demo Desk: Oilers set their opening-night focus'
    and discussion.context_kind = 'team'
    and team.team_id = 'hockey-000027';

  select count(*)
  into team_comment_count
  from public.community_comments comment
  join public.community_discussions discussion
    on discussion.id = comment.discussion_id
  join public.news_items item on item.id = discussion.news_item_id
  join public.news_item_versions version
    on version.news_item_id = item.id and version.is_current
  where version.headline = 'Demo Desk: Oilers set their opening-night focus'
    and comment.author_user_id in ('$fan_a'::uuid, '$fan_b'::uuid);

  if team_discussion_count <> 1
    or team_comment_count <> 2
    or team_durable_count <> 2 then
    raise exception 'Concurrent first comments did not converge on one discussion with a durable count of two';
  end if;

  select comment.author_user_id
  into history_author
  from public.community_comments comment
  where comment.body = 'History remains with the first UUID';

  if history_author is distinct from '$fan_a'::uuid
    or (select handle from public.profiles where user_id = '$fan_a'::uuid)
       <> 'ConcurrencyOne'
    or (select handle from public.profiles where user_id = '$fan_b'::uuid)
       <> 'RACEFAN' then
    raise exception 'Fanatical Name release/reclaim rebound ownership or failed to preserve display capitalization';
  end if;

  perform set_config('request.jwt.claim.sub', '$fan_b', true);
  select public.get_community_discussion(discussion.discussion_id)
  into history_payload
  from public.community_discussions discussion
  join public.news_items item on item.id = discussion.news_item_id
  join public.news_item_versions version
    on version.news_item_id = item.id and version.is_current
  where version.headline = 'Local Demo Podcast: Morning skate briefing'
    and discussion.context_kind = 'sport';

  if history_payload #>> '{comments,0,fanatical_name}' <> 'ConcurrencyOne' then
    raise exception 'Historical comment attribution did not resolve the original UUID current Fanatical Name';
  end if;
end
\$proof\$;
SQL

echo "Passed Phase 5A Fanatical Name and first-comment two-session concurrency tests."
