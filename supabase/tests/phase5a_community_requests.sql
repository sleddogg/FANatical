-- Phase 5A transactional real-role proof. The deterministic News rows used by
-- this test are provisioned only by the loopback acceptance fixture.

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
    raise exception 'Phase 5A assertion failed: %', message_value;
  end if;
end;
$$;

create or replace function pg_temp.assert_statement_rejected(
  statement_value text,
  expected_message text,
  message_value text
)
returns void
language plpgsql
as $$
begin
  begin
    execute statement_value;
  exception when others then
    if expected_message is null
      or position(lower(expected_message) in lower(sqlerrm)) > 0 then
      return;
    end if;
    raise exception 'Phase 5A assertion failed: % (unexpected error: %)',
      message_value, sqlerrm;
  end;
  raise exception 'Phase 5A assertion failed: % (statement succeeded)',
    message_value;
end;
$$;

create or replace function pg_temp.assert_check_rejected(
  statement_value text,
  message_value text
)
returns void
language plpgsql
as $$
begin
  begin
    execute statement_value;
  exception when check_violation then
    return;
  end;
  raise exception 'Phase 5A assertion failed: %', message_value;
end;
$$;

select set_config(
  'test.phase5a.team_item',
  (
    select ready.news_item_id
    from public.news_published_item_read_model ready
    where ready.headline = 'Demo Desk: Oilers set their opening-night focus'
  ),
  true
);
select set_config(
  'test.phase5a.competition_item',
  (
    select ready.news_item_id
    from public.news_published_item_read_model ready
    where ready.headline = 'Demo Desk: NHL notebook tracks the week ahead'
  ),
  true
);
select set_config(
  'test.phase5a.sport_item',
  (
    select ready.news_item_id
    from public.news_published_item_read_model ready
    where ready.headline = 'Local Demo Podcast: Morning skate briefing'
  ),
  true
);
select set_config(
  'test.phase5a.followable_organization',
  (
    select followable.target_id
    from private.current_news_followable_identities() followable
    where followable.target_type = 'organization'
      and followable.display_name = 'FANatical Local Demo Desk'
  ),
  true
);

select pg_temp.assert_true(
  current_setting('test.phase5a.team_item', true) <> ''
    and current_setting('test.phase5a.competition_item', true) <> ''
    and current_setting('test.phase5a.sport_item', true) <> ''
    and current_setting('test.phase5a.followable_organization', true) <> '',
  'loopback-only governed acceptance News fixtures must be present'
);

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '85000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'phase5a-brad@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Brad"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '85000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'phase5a-test@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Test Fan"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '85000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'phase5a-later@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Later Fan"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '85000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'phase5a-service@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Operational Demo"}'::jsonb, now(), now());

update public.profiles
set handle = case user_id
    when '85000000-0000-0000-0000-000000000001' then 'BradFan'
    when '85000000-0000-0000-0000-000000000002' then 'Phase5TestFan'
    when '85000000-0000-0000-0000-000000000003' then 'LaterFan'
    else ''
  end,
  visibility = case user_id
    when '85000000-0000-0000-0000-000000000001'
      then 'members_visible'
    else 'private'
  end,
  display_name = case user_id
    when '85000000-0000-0000-0000-000000000001' then 'Brad Display'
    when '85000000-0000-0000-0000-000000000002' then 'Test Display'
    when '85000000-0000-0000-0000-000000000003' then 'Later Display'
    else 'Operational Demo Display'
  end,
  tagline = case user_id
    when '85000000-0000-0000-0000-000000000001' then 'Visible tagline'
    else null
  end,
  given_name = case user_id
    when '85000000-0000-0000-0000-000000000001' then 'Brad Given'
    else null
  end,
  nickname = case user_id
    when '85000000-0000-0000-0000-000000000001' then 'Hidden Nickname'
    else null
  end,
  personal_field_visibility = case user_id
    when '85000000-0000-0000-0000-000000000001'
      then '{"given_name":true,"nickname":false}'::jsonb
    else '{}'::jsonb
  end
where user_id in (
  '85000000-0000-0000-0000-000000000001',
  '85000000-0000-0000-0000-000000000002',
  '85000000-0000-0000-0000-000000000003',
  '85000000-0000-0000-0000-000000000004'
);

insert into public.user_followed_teams(user_id, team_id, sort_order)
values
  ('85000000-0000-0000-0000-000000000001', 'hockey-000027', 0),
  ('85000000-0000-0000-0000-000000000002', 'hockey-000027', 0);

insert into public.staff_roles(user_id, role, permissions, is_active)
values (
  '85000000-0000-0000-0000-000000000001',
  'admin',
  array['community_moderate']::text[],
  true
);

insert into public.catalog_actors(
  id, actor_key, actor_type, auth_user_id, display_name, active
)
values (
  '85100000-0000-0000-0000-000000000002',
  'phase5a-test-catalog-wildcard',
  'human',
  '85000000-0000-0000-0000-000000000002',
  'Phase 5A catalog wildcard fan',
  true
);
insert into public.catalog_actor_capabilities(actor_id, capability)
values ('85100000-0000-0000-0000-000000000002', '*');
insert into public.catalog_actors(
  id, actor_key, actor_type, auth_user_id, display_name, active
)
values (
  '85100000-0000-0000-0000-000000000004',
  'phase5a_operational_service',
  'service',
  '85000000-0000-0000-0000-000000000004',
  'Phase 5A operational service',
  true
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1 from public.get_news_navigation() navigation
    where navigation.filter_type = 'competition'
      and navigation.target_id = 'hockey-nhl'
      and navigation.competition_kind_id = 'league'
  ) and exists (
    select 1 from public.get_news_navigation() navigation
    where navigation.filter_type = 'team'
      and navigation.target_id = 'hockey-000027'
      and navigation.is_followed
  ),
  'News navigation must expose governed Competition kind and followed-Team state'
);
reset role;

-- Signed-out visitors receive only a contextual count teaser. Empty reads do
-- not create rows, and no-origin routing never infers Team.
select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.team_item'),
    'team',
    'hockey-000027'
  ) @> '{"available":true,"requires_auth":true,"comment_count":0}'::jsonb,
  'signed-out explicit Team teaser must expose only availability and zero count'
);
select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.team_item'),
    'team',
    'hockey-nhl-edmonton-oilers'
  ) @> '{"available":true,"context_id":"hockey-000027","comment_count":0}'::jsonb,
  'an unambiguous legacy Team origin must resolve to the canonical Team context'
);
select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.team_item'), 'sport', 'hockey'
  ) @> '{"available":true,"context_kind":"sport","context_id":"hockey"}'::jsonb
    and public.get_news_discussion_teaser(
      current_setting('test.phase5a.competition_item'), 'sport', 'hockey'
    ) @> '{"available":true,"context_kind":"sport","context_id":"hockey"}'::jsonb
    and public.get_news_discussion_teaser(
      current_setting('test.phase5a.sport_item'), 'sport', 'hockey'
    ) @> '{"available":true,"context_kind":"sport","context_id":"hockey"}'::jsonb,
  'explicit Sport routing must use the same Team, Competition, and direct-Sport roll-up as News eligibility'
);
select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.competition_item'),
    'competition',
    'hockey-nhl'
  ) @> '{"available":true,"context_kind":"competition","context_display_kind":"League"}'::jsonb,
  'a league-kind Competition discussion must use the governed League presentation label'
);
select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.team_item'), null, null
  ) ->> 'available' = 'false',
  'direct/no-origin fallback must never infer Team'
);
select pg_temp.assert_true(
  not has_function_privilege(
    'anon', 'public.get_community_discussion(text)', 'EXECUTE'
  )
    and not has_function_privilege(
      'anon',
      'public.get_member_profile_by_fanatical_name(text)',
      'EXECUTE'
    ),
  'anonymous comment-body and profile readers must be denied'
);
reset role;

select pg_temp.assert_true(
  (select count(*) = 0 from public.community_discussions),
  'opening empty Team and direct discussion teasers must insert nothing'
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000004',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.team_item'),
    'team',
    'hockey-000027'
  ) ->> 'viewer_can_access' = 'false'
    and public.get_member_profile_by_fanatical_name('BradFan') is null,
  'an operational actor must be excluded from fan discussion and profile access'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.post_news_discussion_comment(%L,%L,%L,%L)',
    current_setting('test.phase5a.team_item'),
    'team',
    'hockey-000027',
    'Operational actors cannot post'
  ),
  'ordinary fan profile',
  'an operational actor cannot post as a real fan'
);
reset role;

select pg_temp.assert_check_rejected(
  format(
    $sql$
      insert into public.community_discussions(
        news_item_id, context_kind, team_id, sport_id, created_by_user_id
      )
      select item.id, 'team', team.id, sport.id,
        '85000000-0000-0000-0000-000000000001'::uuid
      from public.news_items item
      cross join public.catalog_teams team
      cross join public.catalog_sports sport
      where item.news_item_id = %L
        and team.team_id = 'hockey-000027'
        and sport.sport_id = 'hockey'
    $sql$,
    current_setting('test.phase5a.team_item')
  ),
  'a discussion must have exactly one typed context foreign key'
);
-- The first real comment creates Team context atomically with the node.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'),
  'team',
  'hockey-nhl-edmonton-oilers',
  'Brad team root'
);
select public.post_news_discussion_comment(
  current_setting('test.phase5a.competition_item'),
  'competition',
  'hockey-nhl',
  'Brad competition root'
);
select public.post_news_discussion_comment(
  current_setting('test.phase5a.sport_item'),
  'sport',
  'hockey',
  'Brad sport root'
);
reset role;

select pg_temp.assert_check_rejected(
  $$
    insert into public.community_comments(
      id, comment_id, discussion_id, parent_comment_id,
      author_user_id, body
    )
    select
      '85200000-0000-0000-0000-000000000099'::uuid,
      'community-comment-85200000000000000000000000000099',
      discussion.id,
      '85200000-0000-0000-0000-000000000099'::uuid,
      '85000000-0000-0000-0000-000000000001'::uuid,
      'Self-parenting is invalid'
    from public.community_discussions discussion
    where discussion.context_kind = 'team'
  $$,
  'a comment must never be its own parent'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from (
      values
        ('community_discussions'),
        ('community_comments'),
        ('community_comment_versions'),
        ('community_hide_intents'),
        ('community_reports'),
        ('community_posting_restrictions'),
        ('community_posting_restriction_lifts'),
        ('community_moderation_actions'),
        ('community_moderation_notices'),
        ('community_notifications'),
        ('news_follow_request_targets'),
        ('news_follow_request_resolution_decisions'),
        ('user_news_follow_requests')
    ) governed_table(table_name)
    join pg_catalog.pg_class relation
      on relation.relname = governed_table.table_name
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
     and namespace.nspname = 'public'
    cross join unnest(array[
      'SELECT', 'INSERT', 'UPDATE', 'DELETE'
    ]::text[]) privilege(privilege_name)
    where not relation.relrowsecurity
      or has_table_privilege(
        'anon',
        format('public.%I', governed_table.table_name),
        privilege.privilege_name
      )
      or has_table_privilege(
        'authenticated',
        format('public.%I', governed_table.table_name),
        privilege.privilege_name
      )
  ),
  'all ten Community and three Request tables must enable RLS and expose no browser table writes or reads'
);

select pg_temp.assert_true(
  (
    select count(*) = 3
      and count(*) filter (where context_kind = 'team') = 1
      and count(*) filter (where context_kind = 'competition') = 1
      and count(*) filter (where context_kind = 'sport') = 1
    from public.community_discussions
  ),
  'Team, Competition, and Sport must each create one typed root'
);
select pg_temp.assert_statement_rejected(
  $$insert into public.community_discussions(
      news_item_id, context_kind, team_id, created_by_user_id
    ) select news_item_id, context_kind, team_id, created_by_user_id
      from public.community_discussions where context_kind = 'team'$$,
  'duplicate key',
  'Team Item/context uniqueness must reject a second discussion'
);
select pg_temp.assert_statement_rejected(
  $$insert into public.community_discussions(
      news_item_id, context_kind, competition_id, created_by_user_id
    ) select news_item_id, context_kind, competition_id, created_by_user_id
      from public.community_discussions where context_kind = 'competition'$$,
  'duplicate key',
  'Competition Item/context uniqueness must reject a second discussion'
);
select pg_temp.assert_statement_rejected(
  $$insert into public.community_discussions(
      news_item_id, context_kind, sport_id, created_by_user_id
    ) select news_item_id, context_kind, sport_id, created_by_user_id
      from public.community_discussions where context_kind = 'sport'$$,
  'duplicate key',
  'Sport Item/context uniqueness must reject a second discussion'
);

-- Put exactly one Sport classification on the same Item that already has
-- exactly one Competition classification. This proves the direct/no-origin
-- fallback priority rather than only exercising the two single-type cases.
insert into public.news_item_classifications(
  id, news_item_id, created_by_decision_id
)
select
  '85210000-0000-0000-0000-000000000001',
  classification.news_item_id,
  classification.created_by_decision_id
from public.news_item_classifications classification
join public.news_item_classification_versions version
  on version.classification_id = classification.id
 and version.is_current
 and version.target_type = 'competition'
join public.news_items item on item.id = classification.news_item_id
where item.news_item_id = current_setting('test.phase5a.competition_item')
limit 1;

insert into public.news_item_classification_versions(
  classification_id, target_type, sport_id, recorded_from,
  primary_evidence_id, decision_id
)
select
  '85210000-0000-0000-0000-000000000001',
  'sport',
  sport.id,
  competition_version.recorded_from,
  competition_version.primary_evidence_id,
  competition_version.decision_id
from public.news_item_classifications competition_classification
join public.news_item_classification_versions competition_version
  on competition_version.classification_id = competition_classification.id
 and competition_version.is_current
 and competition_version.target_type = 'competition'
join public.news_items item
  on item.id = competition_classification.news_item_id
join public.catalog_sports sport on sport.sport_id = 'hockey'
where item.news_item_id = current_setting('test.phase5a.competition_item')
limit 1;

select pg_temp.assert_true(
  (
    select count(*) filter (where version.target_type = 'competition') = 1
      and count(*) filter (where version.target_type = 'sport') = 1
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id
     and version.is_current
    join public.news_items item on item.id = classification.news_item_id
    where item.news_item_id = current_setting('test.phase5a.competition_item')
  ),
  'the fallback-priority Item must have exactly one Competition and one Sport'
);
select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.competition_item'), null, null
  ) ->> 'context_kind' = 'competition'
    and public.get_news_discussion_teaser(
      current_setting('test.phase5a.sport_item'), null, null
    ) ->> 'context_kind' = 'sport',
  'no-origin fallback must prefer exactly one Competition over exactly one Sport'
);

-- Removing a current classification stops future origin routing without
-- rewriting the stable discussion, its context, or its fan interaction.
select set_config(
  'test.phase5a.competition_discussion',
  (select discussion_id from public.community_discussions
   where context_kind = 'competition'),
  true
);
select set_config(
  'test.phase5a.competition_root',
  (select comment.comment_id
   from public.community_comments comment
   join public.community_discussions discussion
     on discussion.id = comment.discussion_id
   where discussion.context_kind = 'competition'
     and comment.parent_comment_id is null),
  true
);
set local session_replication_role = replica;
update public.news_item_classification_versions version
set is_current = false,
    recorded_to = statement_timestamp(),
    superseded_at = statement_timestamp()
from public.news_item_classifications classification
join public.news_items item on item.id = classification.news_item_id
where version.classification_id = classification.id
  and version.is_current
  and version.target_type = 'competition'
  and item.news_item_id = current_setting('test.phase5a.competition_item');
set local session_replication_role = origin;

select pg_temp.assert_true(
  public.get_news_discussion_teaser(
    current_setting('test.phase5a.competition_item'),
    'competition', 'hockey-nhl'
  ) ->> 'available' = 'false',
  'a removed classification must stop future origin routing'
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_community_discussion(
    current_setting('test.phase5a.competition_discussion')
  ) ->> 'context_kind' = 'competition'
    and public.get_community_discussion(
      current_setting('test.phase5a.competition_discussion')
    ) ->> 'context_is_current' = 'false',
  'the stable discussion link must remain readable after classification correction'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.post_existing_community_discussion_comment(%L,%L)',
    current_setting('test.phase5a.competition_discussion'),
    'Rejected competition root after correction'
  ),
  'no longer current',
  'a corrected-away discussion must reject new root comments'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.reply_to_community_comment(%L,%L,%L)',
    current_setting('test.phase5a.competition_discussion'),
    current_setting('test.phase5a.competition_root'),
    'Rejected competition reply after correction'
  ),
  'no longer current',
  'a corrected-away discussion must reject new replies'
);
reset role;
select pg_temp.assert_true(
  (select count(*) = 1 and max(comment_count) = 1
   from public.community_discussions where context_kind = 'competition'),
  'classification correction must preserve one discussion without adding interaction'
);

select set_config(
  'test.phase5a.team_discussion',
  (
    select discussion.discussion_id
    from public.community_discussions discussion
    join public.catalog_teams team on team.id = discussion.team_id
    where team.team_id = 'hockey-000027'
      and discussion.news_item_id = (
        select item.id from public.news_items item
        where item.news_item_id = current_setting('test.phase5a.team_item')
      )
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1
    from jsonb_array_elements(
      public.get_team_news_discussions('hockey-000027')
    ) entry
    where entry ->> 'discussion_id' = current_setting('test.phase5a.team_discussion')
      and entry ->> 'news_item_id' = current_setting('test.phase5a.team_item')
      and entry ->> 'context_id' = 'hockey-000027'
      and entry -> 'article' ->> 'headline' =
        'Demo Desk: Oilers set their opening-night focus'
  ),
  'Team FANbase must surface the same durable Item+Team discussion and article reference'
);
reset role;
select set_config(
  'test.phase5a.brad_root',
  (select comment.comment_id
   from public.community_comments comment
   where comment.body = 'Brad team root'),
  true
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format(
    'select public.get_community_discussion(%L)',
    current_setting('test.phase5a.team_discussion')
  ),
  'Follow this Team',
  'News classification alone must not grant Team FANbase discussion access'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.post_existing_community_discussion_comment(%L,%L)',
    current_setting('test.phase5a.team_discussion'),
    'Unauthorized Team root'
  ),
  'Follow this Team',
  'a non-follower must not post into a Team FANbase discussion'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.report_community_comment(%L,%L,%L)',
    current_setting('test.phase5a.brad_root'),
    'spam',
    'Inaccessible Team content'
  ),
  'Follow this Team',
  'a non-follower must not report inaccessible Team discussion content'
);
reset role;

-- A unique legacy external identifier remains a valid followed-Team record.
insert into public.user_followed_teams(user_id, team_id, sort_order)
select '85000000-0000-0000-0000-000000000003'::uuid,
  identifier.identifier,
  0
from public.catalog_team_identifiers identifier
join public.catalog_teams team on team.id = identifier.team_id
where team.team_id = 'hockey-000027'
  and identifier.identifier <> team.team_id
  and not exists (
    select 1 from public.catalog_teams canonical
    where canonical.team_id = identifier.identifier
  )
  and 1 = (
    select count(distinct candidate.team_id)
    from public.catalog_team_identifiers candidate
    where candidate.identifier = identifier.identifier
  )
order by identifier.namespace, identifier.identifier
limit 1;
select pg_temp.assert_true(
  exists (select 1 from public.user_followed_teams
          where user_id = '85000000-0000-0000-0000-000000000003'),
  'the Team fixture must provide one unambiguous legacy identifier'
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_community_discussion(
    current_setting('test.phase5a.team_discussion')
  ) ->> 'comment_count' = '1',
  'an unambiguous legacy followed-Team identifier must authorize FANbase access'
);
reset role;

-- Reply, current-name attribution, and exactly-one direct notification.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.community_hide_intents
   where hider_id in (
     '85000000-0000-0000-0000-000000000001',
     '85000000-0000-0000-0000-000000000002'
   ) and hidden_id in (
     '85000000-0000-0000-0000-000000000001',
     '85000000-0000-0000-0000-000000000002'
   )),
  'the none directed-Hide state must begin with no pair rows'
);
set local role authenticated;
select public.reply_to_community_comment(
  current_setting('test.phase5a.team_discussion'),
  current_setting('test.phase5a.brad_root'),
  'Test direct reply'
);
select pg_temp.assert_true(
  public.get_community_discussion(
    current_setting('test.phase5a.team_discussion')
  ) ->> 'comment_count' = '2',
  'context count must include root and reply'
);
reset role;

select set_config(
  'test.phase5a.test_reply',
  (
    select comment.comment_id
    from public.community_comments comment
    where comment.body = 'Test direct reply'
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_my_community_notifications() ->> 'unread_count' = '1',
  'a direct reply must create one unread notification'
);
select public.set_my_fanatical_name('BradRenamed');
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select public.set_my_fanatical_name('BradFan');
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_community_discussion(
    current_setting('test.phase5a.team_discussion')
  )::text like '%BradRenamed%'
    and public.get_community_discussion(
      current_setting('test.phase5a.team_discussion')
    )::text not like '%"fanatical_name": "BradFan"%',
  'comments must resolve the owner current name and never rebind to a later claimant'
);
reset role;

-- Database-time edit boundary and cross-user mutation denial.
insert into public.community_comments(
  id, comment_id, discussion_id, author_user_id, body, created_at
)
select
  '85200000-0000-0000-0000-000000000001',
  'community-comment-85200000000000000000000000000001',
  discussion.id,
  '85000000-0000-0000-0000-000000000001',
  'Old Brad comment',
  statement_timestamp() - interval '8 days'
from public.community_discussions discussion
where discussion.discussion_id = current_setting('test.phase5a.team_discussion');
insert into public.community_comment_versions(
  comment_id, version_number, change_kind, body, changed_by_user_id, changed_at
)
values (
  '85200000-0000-0000-0000-000000000001', 1, 'created',
  'Old Brad comment', '85000000-0000-0000-0000-000000000001',
  statement_timestamp() - interval '8 days'
);
update public.community_discussions
set comment_count = comment_count + 1
where discussion_id = current_setting('test.phase5a.team_discussion');

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $$select public.edit_my_community_comment(
    'community-comment-85200000000000000000000000000001',
    'Too late'
  )$$,
  'seven-day',
  'comment edit eligibility must use the database seven-day window'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format(
    'select public.edit_my_community_comment(%L,%L)',
    current_setting('test.phase5a.brad_root'),
    'Cross-user edit'
  ),
  'not found for this author',
  'cross-user comment edit must be denied'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.delete_my_community_comment(%L)',
    current_setting('test.phase5a.brad_root')
  ),
  'not found for this author',
  'cross-user comment delete must be denied'
);
reset role;

-- Author tombstones are irreversible, preserve replies, and remain counted.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'),
  'team',
  'hockey-000027',
  'Brad delete root'
);
reset role;
select set_config(
  'test.phase5a.delete_root',
  (select comment_id from public.community_comments
   where body = 'Brad delete root'),
  true
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.reply_to_community_comment(
  current_setting('test.phase5a.team_discussion'),
  current_setting('test.phase5a.delete_root'),
  'Reply survives tombstone'
);
reset role;
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.delete_my_community_comment(
  current_setting('test.phase5a.delete_root')
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.edit_my_community_comment(%L,%L)',
    current_setting('test.phase5a.delete_root'),
    'Restore attempt'
  ),
  'tombstoned',
  'author tombstone must be irreversible'
);
reset role;
select pg_temp.assert_true(
  (
    select parent.status = 'deleted'
      and parent.body is null
      and child.status = 'active'
      and child.body = 'Reply survives tombstone'
    from public.community_comments parent
    join public.community_comments child
      on child.parent_comment_id = parent.id
    where parent.comment_id = current_setting('test.phase5a.delete_root')
  ),
  'tombstoned parent must retain its live reply'
);
select pg_temp.assert_true(
  (
    select discussion.comment_count = count(comment.id)
    from public.community_discussions discussion
    join public.community_comments comment
      on comment.discussion_id = discussion.id
    where discussion.discussion_id = current_setting('test.phase5a.team_discussion')
    group by discussion.comment_count
  ),
  'durable contextual count must include tombstones'
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.delete_root')
      and entry ->> 'status' = 'deleted'
      and entry ->> 'body' = 'Comment deleted'
      and entry ->> 'author_hidden' = 'false'
      and entry ->> 'fanatical_name' = 'BradRenamed'
  ),
  'author tombstones must preserve current author attribution for another visible fan'
);
reset role;

-- Releasing a public name never releases UUID ownership controls. Claim is
-- required for new post/reply only; the owner can still edit/delete their node.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select set_config(
  'test.phase5a.owner_control_comment',
  public.post_news_discussion_comment(
    current_setting('test.phase5a.team_item'),
    'team', 'hockey-000027',
    'Brad owner-control proof'
  ) ->> 'comment_id',
  true
);
select public.set_my_fanatical_name('');
select public.edit_my_community_comment(
  current_setting('test.phase5a.owner_control_comment'),
  'Brad owner-control proof edited'
);
select public.delete_my_community_comment(
  current_setting('test.phase5a.owner_control_comment')
);
select public.set_my_fanatical_name('BradRenamed');
reset role;
select pg_temp.assert_true(
  (select status = 'deleted' and body is null
   from public.community_comments
   where comment_id = (
     select version_comment.comment_id
     from public.community_comment_versions version
     join public.community_comments version_comment
       on version_comment.id = version.comment_id
     where version.body = 'Brad owner-control proof edited'
     limit 1
   )),
  'a no-name owner must retain edit and irreversible delete authority'
);

-- Members-visible allowlist, Private attribution state, reciprocal Hide, all
-- four directed-row states, reply denial, profile denial, and hidden inbox.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('BradRenamed')
    #>> '{personal_fields,given_name}' = 'Brad Given'
    and not (
      (public.get_member_profile_by_fanatical_name('BradRenamed')
        -> 'personal_fields') ? 'nickname'
    )
    and not (
      public.get_member_profile_by_fanatical_name('BradRenamed') ? 'user_id'
    ),
  'Members-visible profile must include only owner-opted and fan-safe fields'
);
select public.hide_community_comment_author(
  current_setting('test.phase5a.brad_root')
);
select set_config(
  'test.phase5a.test_to_brad_hide',
  (
    select entry ->> 'hide_intent_id'
    from jsonb_array_elements(public.get_my_hidden_fans()) entry
    where entry ->> 'fanatical_name' = 'BradRenamed'
  ),
  true
);
select pg_temp.assert_true(
  public.get_my_hidden_fans()
    @> jsonb_build_array(jsonb_build_object(
      'hide_intent_id', current_setting('test.phase5a.test_to_brad_hide'),
      'fanatical_name', 'BradRenamed'
    )),
  'the Test-to-Brad state must expose only the owner-removable opaque intent'
);
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('BradRenamed') is null,
  'reciprocal Hide must deny profile viewing'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.reply_to_community_comment(%L,%L,%L)',
    current_setting('test.phase5a.team_discussion'),
    current_setting('test.phase5a.brad_root'),
    'Hidden reply'
  ),
  'hidden fans',
  'reciprocal Hide must deny direct replies'
);
select pg_temp.assert_true(
  (
    select entry ->> 'body' = 'Content unavailable'
      and entry ->> 'status' = 'unavailable'
      and entry ->> 'author_hidden' = 'true'
      and entry -> 'fanatical_name' = 'null'::jsonb
      and entry -> 'avatar' = 'null'::jsonb
      and entry ->> 'can_unhide' = 'true'
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.brad_root')
  ),
  'Test must see Brad content/name/avatar unavailable and their own Unhide control'
);
select pg_temp.assert_true(
  (
    select entry ->> 'body' = 'Comment deleted'
      and entry ->> 'status' = 'deleted'
      and entry ->> 'author_hidden' = 'true'
      and entry -> 'fanatical_name' = 'null'::jsonb
      and entry -> 'avatar' = 'null'::jsonb
      and entry ->> 'can_unhide' = 'true'
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.delete_root')
  ),
  'a hidden author tombstone must retain Comment deleted while presenting Hidden fan state'
);
reset role;

-- An Author resolved while it is a distinct identity must follow the governed
-- canonical person after a later merge, without reopening or renotifying the
-- historical Request. Current actionability and Following state stay live.
insert into public.catalog_people(id, person_id)
values
  (
    '86000000-0000-0000-0000-000000000001',
    'person-60000000000000000000000000000001'
  ),
  (
    '86000000-0000-0000-0000-000000000002',
    'person-60000000000000000000000000000002'
  );
insert into public.person_identity_versions(person_id, public_name)
values
  ('86000000-0000-0000-0000-000000000001', 'Phase 5 Alias Author'),
  ('86000000-0000-0000-0000-000000000002', 'Phase 5 Canonical Author');
insert into public.news_author_profiles(id, author_id, person_id)
values
  (
    '86100000-0000-0000-0000-000000000001',
    'author-61000000000000000000000000000001',
    '86000000-0000-0000-0000-000000000001'
  ),
  (
    '86100000-0000-0000-0000-000000000002',
    'author-61000000000000000000000000000002',
    '86000000-0000-0000-0000-000000000002'
  );

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.admin_set_news_identity_followability(
  'author',
  'author-61000000000000000000000000000001',
  true,
  'The transactional pre-merge Author is followable.'
);
select public.admin_set_news_identity_followability(
  'author',
  'author-61000000000000000000000000000002',
  true,
  'The transactional canonical Author is followable.'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.submit_news_follow_request('name', 'Phase 5 Author Alias');
reset role;
select set_config(
  'test.phase5a.author_request_target',
  (
    select target.request_target_id
    from public.news_follow_request_targets target
    where target.input_kind = 'name'
      and target.normalized_input = 'phase 5 author alias'
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.admin_resolve_news_follow_request(
  current_setting('test.phase5a.author_request_target'),
  'available',
  'author',
  'author-61000000000000000000000000000001',
  'The requested Author is currently followable.'
);
reset role;
select pg_temp.assert_true(
  not exists (
    select 1
    from public.user_news_identity_follows follow_record
    where follow_record.user_id = '85000000-0000-0000-0000-000000000002'
  ),
  'resolving an Available Author Request must not auto-Follow it'
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.follow_news_identity(
  'author', 'author-61000000000000000000000000000001'
);
reset role;

insert into public.news_identity_resolution_cases(
  id, case_kind, proposed_identity_type, proposed_name,
  subject_person_id, unresolved_question, status,
  created_by_user_id
)
values (
  '86200000-0000-0000-0000-000000000001',
  'person_merge', 'human', 'Phase 5 Canonical Author',
  '86000000-0000-0000-0000-000000000001',
  'Transactional governed Author merge for the Phase 5A Request proof.',
  'resolved_manual', '85000000-0000-0000-0000-000000000001'
);
insert into public.news_identity_resolution_decisions(
  id, case_id, action, decision_origin, result_identity_type,
  result_person_id, question_snapshot, action_payload_snapshot,
  notes, decided_by_user_id
)
values (
  '86210000-0000-0000-0000-000000000001',
  '86200000-0000-0000-0000-000000000001',
  'merge', 'staff', 'human',
  '86000000-0000-0000-0000-000000000002',
  'Transactional governed Author merge for the Phase 5A Request proof.',
  '{"identity_type":"human"}'::jsonb,
  'The existing governed person-pair boundary records the canonical target.',
  '85000000-0000-0000-0000-000000000001'
);
update public.news_identity_resolution_cases
set opened_by_decision_id = '86210000-0000-0000-0000-000000000001'
where id = '86200000-0000-0000-0000-000000000001';
select private.set_news_person_pair_state(
  '86000000-0000-0000-0000-000000000001',
  '86000000-0000-0000-0000-000000000002',
  'merged',
  '86000000-0000-0000-0000-000000000002',
  '86210000-0000-0000-0000-000000000001'
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select entry ->> 'state' = 'Available'
      and entry ->> 'follow_target_type' = 'author'
      and entry ->> 'follow_target_id'
        = 'author-61000000000000000000000000000002'
      and entry ->> 'follow_target_name' = 'Phase 5 Canonical Author'
      and entry ->> 'can_follow' = 'true'
      and entry ->> 'is_following' = 'true'
    from jsonb_array_elements(public.get_my_news_follow_requests()) entry
    where entry ->> 'raw_input' = 'Phase 5 Author Alias'
  ),
  'a terminal Author Request must resolve through a later canonical merge and retain the existing Follow'
);
reset role;
select pg_temp.assert_true(
  (select count(*) = 1
   from public.community_notifications notification
   join public.user_news_follow_requests requester
     on requester.id = notification.requester_relation_id
   where requester.user_id = '85000000-0000-0000-0000-000000000002'
     and requester.raw_input = 'Phase 5 Author Alias'
     and notification.notification_type = 'request_available'),
  'a post-resolution Author merge must not re-notify the requester'
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select entry ->> 'body' = 'Content unavailable'
      and entry ->> 'status' = 'unavailable'
      and entry -> 'fanatical_name' = 'null'::jsonb
      and entry -> 'avatar' = 'null'::jsonb
      and entry ->> 'can_hide' = 'true'
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.test_reply')
  ),
  'Brad must see Test unavailable while retaining the independent reverse-Hide action'
);
select pg_temp.assert_true(
  public.get_my_community_notifications() ->> 'unread_count' = '0',
  'Hide must suppress prior direct-interaction notifications while separated'
);
select public.hide_community_comment_author(
  current_setting('test.phase5a.test_reply')
);
select set_config(
  'test.phase5a.brad_to_test_hide',
  (
    select entry ->> 'hide_intent_id'
    from jsonb_array_elements(public.get_my_hidden_fans()) entry
    where entry ->> 'fanatical_name' = 'Phase5TestFan'
  ),
  true
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_my_hidden_fans()) = 1
    and public.get_my_hidden_fans() #>> '{0,also_hides_you}' = 'true',
  'the both-directions Hide state must retain two independently owned rows'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select count(*) = 2
      and bool_and(entry ->> 'status' = 'active')
      and bool_and(entry ->> 'body' in ('Brad team root', 'Test direct reply'))
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' in (
      current_setting('test.phase5a.brad_root'),
      current_setting('test.phase5a.test_reply')
    )
  ),
  'an unaffected third fan must retain both ordinary comments'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.unhide_community_intent(
  current_setting('test.phase5a.test_to_brad_hide')
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_my_hidden_fans()) = 0
    and public.get_member_profile_by_fanatical_name('BradRenamed') is null,
  'the Brad-to-Test-only state must remain separated after Test removes only their row'
);
select public.set_my_fanatical_name('');
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_my_hidden_fans()
    @> jsonb_build_array(jsonb_build_object(
      'hide_intent_id', current_setting('test.phase5a.brad_to_test_hide')
    ))
    and public.get_my_hidden_fans()::text not like '%fanatical_name%',
  'a released target name must not strand or disclose the owner Hide intent'
);
select public.unhide_community_intent(
  current_setting('test.phase5a.brad_to_test_hide')
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_my_hidden_fans()) = 0,
  'removing the final owner intent must restore the none state'
);
reset role;
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.set_my_fanatical_name('Phase5TestFan');
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('BradRenamed') is not null,
  'ending separation must restore current-name profile access'
);
select pg_temp.assert_true(
  (
    select entry ->> 'body' = 'Comment deleted'
      and entry ->> 'status' = 'deleted'
      and entry ->> 'author_hidden' = 'false'
      and entry ->> 'fanatical_name' = 'BradRenamed'
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.delete_root')
  ),
  'ending Hide separation must restore current tombstone attribution without restoring its body'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.set_my_profile_privacy('private', '{}'::jsonb);
reset role;
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('BradRenamed')
    @> '{"visibility":"private","is_private":true}'::jsonb
    and not (
      public.get_member_profile_by_fanatical_name('BradRenamed')
        ? 'display_name'
    ),
  'Private profile must return attribution/private state and omit member fields'
);
reset role;

-- Dismiss creates no fan notice. Moderator tombstones preserve descendants and
-- durable counts, append history, create a separate notice, and cannot be
-- applied twice when a second report remains pending for the same node.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select set_config(
  'test.phase5a.dismiss_comment',
  public.post_existing_community_discussion_comment(
    current_setting('test.phase5a.team_discussion'),
    'Test dismiss-only moderation target'
  ) ->> 'comment_id',
  true
);
select set_config(
  'test.phase5a.tombstone_comment',
  public.post_existing_community_discussion_comment(
    current_setting('test.phase5a.team_discussion'),
    'Test moderator tombstone target'
  ) ->> 'comment_id',
  true
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select public.report_community_comment(
  current_setting('test.phase5a.dismiss_comment'),
  'spam',
  'Dismiss-only proof'
);
select public.report_community_comment(
  current_setting('test.phase5a.tombstone_comment'),
  'harassment',
  'First removal proof'
);
select set_config(
  'test.phase5a.tombstone_reply',
  public.reply_to_community_comment(
    current_setting('test.phase5a.team_discussion'),
    current_setting('test.phase5a.tombstone_comment'),
    'Unaffected reply below moderated parent'
  ) ->> 'comment_id',
  true
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.edit_my_community_comment(
  current_setting('test.phase5a.dismiss_comment'),
  'Test changed the dismiss target after it was reported'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.report_community_comment(
  current_setting('test.phase5a.tombstone_comment'),
  'hate',
  'Second removal proof'
);
reset role;

select set_config(
  'test.phase5a.dismiss_report',
  (
    select report.report_id
    from public.community_reports report
    join public.community_comments comment on comment.id = report.comment_id
    where comment.comment_id = current_setting('test.phase5a.dismiss_comment')
  ),
  true
);
select set_config(
  'test.phase5a.tombstone_report_one',
  (
    select report.report_id
    from public.community_reports report
    join public.community_comments comment on comment.id = report.comment_id
    where comment.comment_id = current_setting('test.phase5a.tombstone_comment')
    order by report.created_at, report.id
    limit 1
  ),
  true
);
select set_config(
  'test.phase5a.tombstone_report_two',
  (
    select report.report_id
    from public.community_reports report
    join public.community_comments comment on comment.id = report.comment_id
    where comment.comment_id = current_setting('test.phase5a.tombstone_comment')
    order by report.created_at desc, report.id desc
    limit 1
  ),
  true
);
select set_config(
  'test.phase5a.pre_moderation_count',
  (
    select discussion.comment_count::text
    from public.community_discussions discussion
    where discussion.discussion_id = current_setting('test.phase5a.team_discussion')
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1
    from jsonb_array_elements(public.get_community_moderation_queue()) entry
    where entry ->> 'report_id' = current_setting('test.phase5a.dismiss_report')
      and entry ->> 'comment_body' = 'Test dismiss-only moderation target'
      and entry ->> 'comment_status' = 'active'
      and entry ->> 'reported_version_number' = '1'
      and entry ->> 'reported_edited' = 'false'
  ),
  'the moderation queue must retain the exact immutable comment version that was reported'
);
select public.admin_moderate_community_report(
  current_setting('test.phase5a.dismiss_report'),
  'dismiss',
  'No community action was warranted.'
);
select public.admin_moderate_community_report(
  current_setting('test.phase5a.tombstone_report_one'),
  'tombstone',
  'The reported content violated community rules.'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_moderate_community_report(%L,%L,%L)',
    current_setting('test.phase5a.tombstone_report_two'),
    'tombstone',
    'A second removal must fail'
  ),
  'Only an active comment can be removed',
  'a pending duplicate report cannot tombstone an already moderated node'
);
select public.admin_moderate_community_report(
  current_setting('test.phase5a.tombstone_report_two'),
  'dismiss',
  'The content was already removed through another report.'
);
reset role;

select pg_temp.assert_true(
  (
    select parent.status = 'moderated'
      and parent.body is null
      and child.status = 'active'
      and child.body = 'Unaffected reply below moderated parent'
    from public.community_comments parent
    join public.community_comments child
      on child.parent_comment_id = parent.id
    where parent.comment_id = current_setting('test.phase5a.tombstone_comment')
      and child.comment_id = current_setting('test.phase5a.tombstone_reply')
  )
    and exists (
      select 1
      from public.community_comment_versions version
      join public.community_comments comment on comment.id = version.comment_id
      where comment.comment_id = current_setting('test.phase5a.tombstone_comment')
        and version.change_kind = 'moderator_tombstoned'
    )
    and (
      select discussion.comment_count::text
      from public.community_discussions discussion
      where discussion.discussion_id = current_setting('test.phase5a.team_discussion')
    ) = current_setting('test.phase5a.pre_moderation_count'),
  'moderator tombstone must preserve replies, history, and the durable node count'
);
select pg_temp.assert_true(
  (select count(*) = 1
   from public.community_moderation_notices notice
   where notice.user_id = '85000000-0000-0000-0000-000000000002'
     and notice.notice_type = 'comment_removed')
    and not exists (
      select 1
      from public.community_moderation_notices notice
      join public.community_moderation_actions action
        on action.id = notice.moderation_action_id
      where action.action_type = 'dismiss'
    )
    and (select count(*) = 2
         from public.community_reports report
         join public.community_comments comment on comment.id = report.comment_id
         where comment.comment_id = current_setting('test.phase5a.tombstone_comment')
           and report.status in ('actioned', 'dismissed')),
  'only the actual removal must create one separate moderation notice'
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.tombstone_comment')
      and entry ->> 'status' = 'moderated'
      and entry ->> 'body' = 'Content removed'
      and entry ->> 'author_hidden' = 'false'
      and entry ->> 'fanatical_name' = 'Phase5TestFan'
  ),
  'moderator tombstones must preserve current author attribution for visible readers'
);
reset role;

-- Report/Hide are independent. Catalog wildcard cannot moderate. Exact staff
-- permission applies deterministic 7,7,14,14 database-time restrictions.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'),
  'team',
  'hockey-000027',
  'Test report target'
);
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'), 'team', 'hockey-000027',
  'Test report target two'
);
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'), 'team', 'hockey-000027',
  'Test report target three'
);
select public.post_news_discussion_comment(
  current_setting('test.phase5a.team_item'), 'team', 'hockey-000027',
  'Test report target four'
);
reset role;
select set_config(
  'test.phase5a.report_comment',
  (select comment_id from public.community_comments
   where body = 'Test report target'),
  true
);
select set_config('test.phase5a.report_comment_two',
  (select comment_id from public.community_comments where body = 'Test report target two'), true);
select set_config('test.phase5a.report_comment_three',
  (select comment_id from public.community_comments where body = 'Test report target three'), true);
select set_config('test.phase5a.report_comment_four',
  (select comment_id from public.community_comments where body = 'Test report target four'), true);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select set_config(
  'test.phase5a.idempotent_report',
  public.report_community_comment(
    current_setting('test.phase5a.report_comment'), 'spam', 'First report'
  ) ->> 'report_id',
  true
);
select pg_temp.assert_true(
  public.report_community_comment(
    current_setting('test.phase5a.report_comment'), 'harassment', 'Duplicate report'
  ) @> jsonb_build_object(
    'report_id', current_setting('test.phase5a.idempotent_report'),
    'already_reported', true
  ),
  'the governed report boundary must return the original report for a duplicate reporter/comment report'
);
reset role;
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.community_reports report
    join public.community_comments comment on comment.id = report.comment_id
    where report.reporting_user_id = '85000000-0000-0000-0000-000000000001'
      and comment.comment_id = current_setting('test.phase5a.report_comment')
  ),
  'the governed report boundary must create only one durable reporter/comment report'
);
set local role authenticated;
select public.report_community_comment(
  current_setting('test.phase5a.report_comment_two'), 'harassment', 'Second report'
);
select public.report_community_comment(
  current_setting('test.phase5a.report_comment_three'), 'hate', 'Third report'
);
select public.report_community_comment(
  current_setting('test.phase5a.report_comment_four'), 'threats', 'Fourth report'
);
reset role;

select set_config(
  'test.phase5a.first_report',
  (
    select report.report_id from public.community_reports report
    order by report.created_at, report.id limit 1
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  public.has_catalog_capability('anything'),
  'fixture must actually possess the catalog wildcard being tested'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_moderate_community_report(%L,%L,%L)',
    current_setting('test.phase5a.first_report'),
    'restrict',
    'Catalog wildcard must not work'
  ),
  'community moderation permission',
  'catalog wildcard must not grant community moderation'
);
reset role;

-- Before suspension, an otherwise-eligible fan retains the complete Phase 5A
-- participation lifecycle: post, reply, edit, and irreversible delete.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select set_config(
  'test.phase5a.suspension_edit_comment',
  public.post_existing_community_discussion_comment(
    current_setting('test.phase5a.team_discussion'),
    'Suspension edit target'
  ) ->> 'comment_id',
  true
);
select set_config(
  'test.phase5a.suspension_delete_comment',
  public.post_existing_community_discussion_comment(
    current_setting('test.phase5a.team_discussion'),
    'Suspension delete target'
  ) ->> 'comment_id',
  true
);
select set_config(
  'test.phase5a.unrestricted_delete_comment',
  public.post_existing_community_discussion_comment(
    current_setting('test.phase5a.team_discussion'),
    'Unrestricted delete proof'
  ) ->> 'comment_id',
  true
);
select public.reply_to_community_comment(
  current_setting('test.phase5a.team_discussion'),
  current_setting('test.phase5a.suspension_edit_comment'),
  'Unrestricted reply proof'
);
select public.edit_my_community_comment(
  current_setting('test.phase5a.suspension_edit_comment'),
  'Suspension edit target updated before restriction'
);
select public.delete_my_community_comment(
  current_setting('test.phase5a.unrestricted_delete_comment')
);
reset role;

select pg_temp.assert_true(
  (select body = 'Suspension edit target updated before restriction'
     and status = 'active'
   from public.community_comments
   where comment_id = current_setting('test.phase5a.suspension_edit_comment'))
  and (select status = 'deleted' and body is null
       from public.community_comments
       where comment_id = current_setting('test.phase5a.unrestricted_delete_comment')),
  'an unrestricted fan must be able to post, reply, edit, and delete when otherwise eligible'
);

-- This old owner comment proves that a later lift restores the ordinary
-- seven-day database-time rule rather than creating a special moderation lock.
insert into public.community_comments(
  id, comment_id, discussion_id, author_user_id, body, created_at
)
select
  '85200000-0000-0000-0000-000000000002',
  'community-comment-85200000000000000000000000000002',
  discussion.id,
  '85000000-0000-0000-0000-000000000002',
  'Old Test Fan suspension proof',
  statement_timestamp() - interval '8 days'
from public.community_discussions discussion
where discussion.discussion_id = current_setting('test.phase5a.team_discussion');
insert into public.community_comment_versions(
  comment_id, version_number, change_kind, body, changed_by_user_id, changed_at
)
values (
  '85200000-0000-0000-0000-000000000002', 1, 'created',
  'Old Test Fan suspension proof',
  '85000000-0000-0000-0000-000000000002',
  statement_timestamp() - interval '8 days'
);
update public.community_discussions
set comment_count = comment_count + 1
where discussion_id = current_setting('test.phase5a.team_discussion');

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
do $$
declare
  queue_entry jsonb;
begin
  for queue_entry in
    select value
    from jsonb_array_elements(public.get_community_moderation_queue()) item(value)
  loop
    perform public.admin_moderate_community_report(
      queue_entry ->> 'report_id',
      'restrict',
      'Phase 5A deterministic restriction proof'
    );
  end loop;
end;
$$;
reset role;

select pg_temp.assert_true(
  (
    select array_agg(
      extract(epoch from restriction.ends_at - restriction.starts_at)
      / 86400 order by restriction.ordinal
    ) = array[7, 7, 14, 14]::numeric[]
    from public.community_posting_restrictions restriction
    where restriction.user_id = '85000000-0000-0000-0000-000000000002'
  ),
  'restriction history must permanently drive the 7,7,14,14 cadence'
);
select pg_temp.assert_true(
  (select count(*) = 4 from public.community_moderation_actions
   where action_type = 'restrict')
    and (select count(*) = 4 from public.community_moderation_notices
         where notice_type = 'posting_restricted')
    and (select count(*) = 0 from public.community_notifications
      where notification_type like 'moderation%'),
  'moderation history/notices must be append-only and separate from social inbox'
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format(
    'select public.post_existing_community_discussion_comment(%L,%L)',
    current_setting('test.phase5a.team_discussion'),
    'Suspended post in original discussion'
  ),
  'suspended until',
  'a Community suspension must block a new comment in the original discussion'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.post_news_discussion_comment(%L,%L,%L,%L)',
    current_setting('test.phase5a.sport_item'),
    'sport',
    'hockey',
    'Suspended post in another context'
  ),
  'suspended until',
  'the same Community suspension must block posting in a different discussion/context'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.reply_to_community_comment(%L,%L,%L)',
    current_setting('test.phase5a.team_discussion'),
    current_setting('test.phase5a.suspension_edit_comment'),
    'Suspended reply'
  ),
  'suspended until',
  'a Community suspension must block replies everywhere'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.edit_my_community_comment(%L,%L)',
    current_setting('test.phase5a.report_comment'),
    'Suspended edit'
  ),
  'suspended until',
  'a Community suspension must block an otherwise-eligible owner edit'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.delete_my_community_comment(%L)',
    current_setting('test.phase5a.suspension_delete_comment')
  ),
  'suspended until',
  'a Community suspension must block an otherwise-eligible owner delete'
);
select pg_temp.assert_true(
  public.get_community_discussion(
    current_setting('test.phase5a.team_discussion')
  ) ->> 'posting_restricted_until' is not null
  and exists (
    select 1
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.report_comment')
      and entry ->> 'body' = 'Test report target'
      and entry ->> 'can_reply' = 'false'
      and entry ->> 'can_edit' = 'false'
      and entry ->> 'can_delete' = 'false'
  ),
  'a suspended fan must retain readable Community content with every participation capability denied'
);
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('BradRenamed') is not null,
  'restricted fan must still read profiles and ordinary app data'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select public.post_news_discussion_comment(
  current_setting('test.phase5a.sport_item'),
  'sport',
  'hockey',
  'Another unrestricted fan remains unaffected'
);
reset role;

select set_config(
  'test.phase5a.pre_lift_social_notification_count',
  (
    select count(*)::text
    from public.community_notifications notification
    where notification.user_id = '85000000-0000-0000-0000-000000000002'
  ),
  true
);

select set_config(
  'test.phase5a.active_restriction',
  (
    select restriction.restriction_id
    from public.community_posting_restrictions restriction
    where restriction.user_id = '85000000-0000-0000-0000-000000000002'
      and restriction.starts_at <= statement_timestamp()
      and restriction.ends_at > statement_timestamp()
    order by restriction.starts_at, restriction.id
    limit 1
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_lift_community_posting_restriction(%L,%L)',
    current_setting('test.phase5a.active_restriction'),
    'Ordinary fan must not work'
  ),
  'community moderation permission',
  'an ordinary fan must not lift a posting restriction'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_lift_community_posting_restriction(%L,%L)',
    current_setting('test.phase5a.active_restriction'),
    'Catalog wildcard must not work'
  ),
  'community moderation permission',
  'catalog wildcard authority must not lift a posting restriction'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  jsonb_array_length(public.get_active_community_posting_restrictions()) = 1,
  'exact-permission staff must be able to read the currently active restriction'
);
select public.admin_lift_community_posting_restriction(
  current_setting('test.phase5a.active_restriction'),
  'Correction accepted; restore Community participation immediately.'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_active_community_posting_restrictions()) = 0,
  'a lift event must end the effective active restriction immediately'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_lift_community_posting_restriction(%L,%L)',
    current_setting('test.phase5a.active_restriction'),
    'Retry must not append another lift or restoration notice'
  ),
  'active posting restriction was not found',
  'a completed lift retry must not duplicate its restoration notice'
);
reset role;

select pg_temp.assert_true(
  (select count(*) = 4 from public.community_posting_restrictions
   where user_id = '85000000-0000-0000-0000-000000000002')
    and (select count(*) = 1 from public.community_posting_restriction_lifts)
    and (select count(*) = 4 from public.community_moderation_actions
         where action_type = 'restrict')
    and exists (
      select 1
      from public.community_reports report
      join public.community_comments comment on comment.id = report.comment_id
      where comment.comment_id = current_setting('test.phase5a.report_comment')
        and report.reported_body = 'Test report target'
    ),
  'lifting must preserve report/moderation evidence and append one reversal without changing restriction history'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
      and bool_and(notice.user_id = restriction.user_id)
      and bool_and(notice.moderation_action_id is null)
    from public.community_moderation_notices notice
    join public.community_posting_restriction_lifts lift
      on lift.id = notice.restriction_lift_id
    join public.community_posting_restrictions restriction
      on restriction.id = lift.restriction_id
    where restriction.restriction_id = current_setting('test.phase5a.active_restriction')
      and notice.notice_type = 'posting_restored'
  ),
  'a successful lift must create exactly one fan-owned restoration moderation notice'
);
select pg_temp.assert_true(
  (
    select count(*)
    from public.community_notifications notification
    where notification.user_id = '85000000-0000-0000-0000-000000000002'
  ) = current_setting('test.phase5a.pre_lift_social_notification_count')::bigint,
  'a restriction lift must not create or change a social notification'
);
select pg_temp.assert_statement_rejected(
  format(
    'update public.community_posting_restrictions set reason = %L where restriction_id = %L',
    'Mutation attempt',
    current_setting('test.phase5a.active_restriction')
  ),
  'append-only',
  'original restriction history must remain immutable after a lift'
);
select pg_temp.assert_statement_rejected(
  $$update public.community_posting_restriction_lifts
      set reason = 'Mutation attempt'$$,
  'append-only',
  'restriction lift events must be immutable'
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1
    from jsonb_array_elements(
      public.get_my_community_moderation_notices() -> 'notices'
    ) notice(value)
    where notice.value ->> 'type' = 'posting_restored'
      and notice.value ->> 'message' =
        'Your Community suspension was lifted. You may participate again under the normal Community rules.'
  ),
  'the affected fan must receive the restoration notice through the separate moderation-notice reader'
);
select public.post_existing_community_discussion_comment(
  current_setting('test.phase5a.team_discussion'),
  'Lifted fan can post immediately'
);
select public.reply_to_community_comment(
  current_setting('test.phase5a.team_discussion'),
  current_setting('test.phase5a.suspension_edit_comment'),
  'Lifted fan can reply immediately'
);
select public.edit_my_community_comment(
  current_setting('test.phase5a.report_comment'),
  'Lifted fan can edit the reported comment under ordinary rules'
);
select public.delete_my_community_comment(
  current_setting('test.phase5a.suspension_delete_comment')
);
select pg_temp.assert_statement_rejected(
  $$select public.edit_my_community_comment(
    'community-comment-85200000000000000000000000000002',
    'Still too late after lift'
  )$$,
  'seven-day',
  'post-lift edit eligibility must return to the ordinary seven-day database-time rule'
);
select pg_temp.assert_true(
  exists (
    select 1
    from jsonb_array_elements(
      public.get_community_discussion(
        current_setting('test.phase5a.team_discussion')
      ) -> 'comments'
    ) entry
    where entry ->> 'comment_id' = current_setting('test.phase5a.report_comment')
      and entry ->> 'body' =
        'Lifted fan can edit the reported comment under ordinary rules'
      and entry ->> 'can_reply' = 'true'
      and entry ->> 'can_edit' = 'true'
      and entry ->> 'can_delete' = 'true'
  ),
  'a lift must immediately restore ordinary post/reply/edit/delete capability without a comment lock'
);
reset role;
select pg_temp.assert_true(
  (
    select status = 'deleted' and body is null
    from public.community_comments
    where comment_id = current_setting('test.phase5a.suspension_delete_comment')
  ),
  'a lift must restore ordinary owner delete eligibility without a moderation-specific lock'
);

-- Shared Request target, per-fan evidence, conservative dedupe, idempotent
-- terminal notification, current followability, and no auto-Follow.
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.submit_news_follow_request('name', '  Local Demo Desk  ');
select public.submit_news_follow_request('name', 'local   demo desk');
reset role;
select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select public.submit_news_follow_request('name', 'LOCAL DEMO DESK');
select public.submit_news_follow_request(
  'url', 'https://request.example.invalid/path?item=one'
);
select public.submit_news_follow_request(
  'url', 'https://request.example.invalid/path?item=two'
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) = 3
      and count(*) filter (where input_kind = 'name') = 1
      and count(*) filter (where input_kind = 'url') = 2
    from public.news_follow_request_targets
    where normalized_input in (
      'local demo desk',
      'https://request.example.invalid/path?item=one',
      'https://request.example.invalid/path?item=two'
    )
  ),
  'name whitespace/case dedupe must share one target while distinct URL queries remain distinct'
);
select pg_temp.assert_true(
  (
    select count(*) = 4
    from public.user_news_follow_requests request
    join public.news_follow_request_targets target
      on target.id = request.request_target_id
    where target.normalized_input in (
      'local demo desk',
      'https://request.example.invalid/path?item=one',
      'https://request.example.invalid/path?item=two'
    )
  ),
  'same fan must not duplicate a relationship and raw per-fan evidence must persist'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.user_news_follow_requests requester
    join public.news_follow_request_targets target
      on target.id = requester.request_target_id
    where requester.user_id = '85000000-0000-0000-0000-000000000001'
      and target.input_kind = 'name'
      and requester.raw_input = '  Local Demo Desk  '
  ),
  'the first requester raw spelling and whitespace must remain exact evidence'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.user_news_identity_follows
   where user_id in (
     '85000000-0000-0000-0000-000000000001',
     '85000000-0000-0000-0000-000000000002'
   )
     and target_type = 'organization'),
  'submitting a Request must never auto-Follow'
);

select set_config(
  'test.phase5a.name_request_target',
  (
    select target.request_target_id
    from public.news_follow_request_targets target
    where target.input_kind = 'name'
      and target.normalized_input = 'local demo desk'
  ),
  true
);
select set_config(
  'test.phase5a.url_request_target',
  (
    select target.request_target_id
    from public.news_follow_request_targets target
    where target.normalized_input =
      'https://request.example.invalid/path?item=one'
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.admin_resolve_news_follow_request(
  current_setting('test.phase5a.name_request_target'),
  'available',
  'organization',
  current_setting('test.phase5a.followable_organization'),
  'The existing governed organization is currently followable.'
);
select public.admin_resolve_news_follow_request(
  current_setting('test.phase5a.name_request_target'),
  'available',
  'organization',
  current_setting('test.phase5a.followable_organization'),
  'Idempotent replay.'
);
select public.admin_resolve_news_follow_request(
  current_setting('test.phase5a.url_request_target'),
  'unable', null, null,
  'The submitted URL cannot be added.'
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) = 3
    from public.community_notifications notification
    join public.user_news_follow_requests requester
      on requester.id = notification.requester_relation_id
    join public.news_follow_request_targets target
      on target.id = requester.request_target_id
    where notification.notification_type in (
      'request_available', 'request_unable'
    )
      and target.normalized_input in (
        'local demo desk',
        'https://request.example.invalid/path?item=one'
      )
  ),
  'two Available requesters and one Unable requester must each receive exactly one final notification'
);
select pg_temp.assert_true(
  (select count(*) = 2
   from public.news_follow_request_resolution_decisions decision
   join public.news_follow_request_targets target
     on target.id = decision.request_target_id
   where target.normalized_input in (
     'local demo desk',
     'https://request.example.invalid/path?item=one'
   )),
  'idempotent terminal replay must not append a second decision'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.user_news_identity_follows
   where user_id in (
     '85000000-0000-0000-0000-000000000001',
     '85000000-0000-0000-0000-000000000002'
   )
     and target_type = 'organization'),
  'Request resolution must never auto-Follow'
);

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select entry ->> 'state' = 'Available'
      and entry ->> 'can_follow' = 'true'
    from jsonb_array_elements(public.get_my_news_follow_requests()) entry
    where entry ->> 'raw_input' = 'LOCAL DEMO DESK'
  )
    and exists (
      select 1
      from jsonb_array_elements(public.get_my_news_follow_requests()) entry
      where entry ->> 'state' = 'Unable to add'
    ),
  'owner Requests read must expose final state and live Follow actionability'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.admin_set_news_identity_followability(
  'organization',
  current_setting('test.phase5a.followable_organization'),
  false,
  'Transactional Phase 5A proof of current actionability.'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select entry ->> 'state' = 'Available'
      and entry ->> 'can_follow' = 'false'
    from jsonb_array_elements(public.get_my_news_follow_requests()) entry
    where entry ->> 'raw_input' = 'LOCAL DEMO DESK'
  ),
  'terminal Available remains historical while current unfollowability removes Follow'
);
reset role;

select pg_temp.assert_true(
  (select count(*) = 64 from private.news_domain_mutation_registry())
    and (select count(*) = 10 from private.community_domain_mutation_registry()),
  'all mutable Phase 5A News and Community tables must remain mechanically registered'
);
select private.assert_news_domain_mutation_registry();
select private.assert_community_domain_mutation_registry();

rollback;
