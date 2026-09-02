\set ON_ERROR_STOP on
begin;

create or replace function pg_temp.assert_true(
  condition_value boolean,
  failure_message text
)
returns void
language plpgsql
as $function$
begin
  if coalesce(condition_value, false) is not true then
    raise exception '%', failure_message;
  end if;
end;
$function$;

create temporary table phase5a_governed_tables(
  table_name text primary key
) on commit drop;
insert into phase5a_governed_tables(table_name) values
  ('community_comment_versions'),
  ('community_comments'),
  ('community_discussions'),
  ('community_hide_intents'),
  ('community_moderation_actions'),
  ('community_moderation_notices'),
  ('community_notifications'),
  ('community_posting_restriction_lifts'),
  ('community_posting_restrictions'),
  ('community_reports'),
  ('news_follow_request_resolution_decisions'),
  ('news_follow_request_targets'),
  ('user_news_follow_requests');

select pg_temp.assert_true(
  not exists (
    select 1 from pg_catalog.pg_roles
    where rolname = 'fanatical_phase5a_executor'
  ),
  'the rejected Phase 5A executor/BYPASSRLS role must not exist'
);

select pg_temp.assert_true(
  (
    select count(*) = 13
    from phase5a_governed_tables expected
    join pg_catalog.pg_class relation
      on relation.relname = expected.table_name
     and relation.relkind in ('r', 'p')
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
     and namespace.nspname = 'public'
    where relation.relrowsecurity
      and pg_get_userbyid(relation.relowner) = 'postgres'
      and not exists (
        select 1 from pg_catalog.pg_policy policy
        where policy.polrelid = relation.oid
      )
  ),
  'all 13 governed tables must remain public, postgres-owned, RLS-enabled, and policy-free'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    join phase5a_governed_tables expected
      on expected.table_name = relation.relname
    where namespace.nspname = 'private'
      and relation.relkind in ('r', 'p')
  ),
  'no governed table may be moved into private'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
     and namespace.nspname = 'public'
    join phase5a_governed_tables expected
      on expected.table_name = relation.relname
    cross join lateral aclexplode(coalesce(
      relation.relacl, acldefault('r', relation.relowner)
    )) access_entry
    left join pg_catalog.pg_roles granted_role
      on granted_role.oid = access_entry.grantee
    where relation.relkind in ('r', 'p')
      and (
        access_entry.grantee = 0
        or granted_role.rolname in ('anon', 'authenticated')
        or (
          granted_role.rolname = 'service_role'
          and access_entry.privilege_type in (
            'SELECT', 'INSERT', 'UPDATE', 'DELETE'
          )
        )
      )
  ),
  'browser roles and service_role must have no direct governed row-data privilege'
);

create temporary table phase5a_expected_functions(
  signature text primary key,
  security_definer boolean not null
) on commit drop;
insert into phase5a_expected_functions(signature, security_definer) values
  ('private.assert_community_domain_mutation_registry()', true),
  ('private.assert_community_fan(uuid,boolean)', true),
  ('private.assert_community_participation_allowed(uuid,boolean)', true),
  ('private.assert_community_posting_allowed(uuid)', true),
  ('private.assert_current_fan(boolean)', true),
  ('private.assert_news_domain_mutation_registry()', true),
  ('private.can_view_profile(uuid)', true),
  ('private.community_active_suspension_end(uuid)', true),
  ('private.community_context_display_kind(text,uuid)', true),
  ('private.community_context_is_accessible(uuid,text,uuid)', true),
  ('private.community_discussion_context_is_current(uuid)', true),
  ('private.community_domain_mutation_registry()', true),
  ('private.community_users_are_separated(uuid,uuid)', true),
  ('private.current_fan_user_id()', true),
  ('private.get_or_create_news_discussion(text,text,text,uuid)', true),
  ('private.insert_community_comment(uuid,uuid,text,uuid)', true),
  ('private.insert_community_notification(uuid,text,uuid,uuid,uuid,jsonb)', true),
  ('private.lock_community_user_pair(uuid,uuid)', true),
  ('private.news_discussion_article_payload(uuid)', true),
  ('private.news_domain_mutation_registry()', true),
  ('private.news_item_has_effective_sport_context(uuid,uuid)', true),
  ('private.news_request_notification_metadata(public.user_news_follow_requests,public.news_follow_request_targets)', true),
  ('private.profile_avatar_path_is_attributable(text)', true),
  ('private.profile_avatar_path_is_fan_safe(uuid,text)', true),
  ('private.profile_media_path_belongs_to_user(uuid,text)', true),
  ('private.profile_media_path_is_visible(text)', true),
  ('private.profile_payload_for_viewer(uuid)', true),
  ('private.resolve_news_discussion_context(text,text,text)', true),
  ('private.validate_profile_handle(text)', true),
  ('public.admin_lift_community_posting_restriction(text,text)', true),
  ('public.admin_moderate_community_report(text,text,text)', true),
  ('public.admin_resolve_news_follow_request(text,text,text,text,text)', true),
  ('public.delete_my_community_comment(text)', true),
  ('public.edit_my_community_comment(text,text)', true),
  ('public.get_active_community_posting_restrictions()', true),
  ('public.get_community_discussion(text)', true),
  ('public.get_community_moderation_queue()', true),
  ('public.get_member_profile_by_fanatical_name(text)', true),
  ('public.get_my_community_moderation_notices()', true),
  ('public.get_my_community_notifications()', true),
  ('public.get_my_hidden_fans()', true),
  ('public.get_my_news_follow_requests()', true),
  ('public.get_news_discussion_teaser(text,text,text)', true),
  ('public.get_news_follow_request_queue()', true),
  ('public.get_news_navigation()', true),
  ('public.get_team_news_discussions(text)', true),
  ('public.hide_community_comment_author(text)', true),
  ('public.hide_community_user(text)', true),
  ('public.mark_my_community_moderation_notices_read(text[])', true),
  ('public.mark_my_community_notifications_read(text[])', true),
  ('public.post_existing_community_discussion_comment(text,text)', true),
  ('public.post_news_discussion_comment(text,text,text,text)', true),
  ('public.reply_to_community_comment(text,text,text)', true),
  ('public.report_community_comment(text,text,text)', true),
  ('public.set_my_fanatical_name(text)', true),
  ('public.set_my_profile_privacy(text,jsonb)', true),
  ('public.submit_news_follow_request(text,text)', true),
  ('public.unhide_community_intent(text)', true),
  ('public.unhide_community_user(text)', true),
  ('public.save_my_profile(jsonb,jsonb,jsonb)', false);

select pg_temp.assert_true(
  (
    select count(*) = 60
    from phase5a_expected_functions expected
    join pg_catalog.pg_proc function_record
      on function_record.oid = to_regprocedure(expected.signature)
    where pg_get_userbyid(function_record.proowner) = 'postgres'
      and function_record.prosecdef = expected.security_definer
      and coalesce(function_record.proconfig, '{}'::text[])
          @> array['search_path=""']::text[]
  ),
  'all affected functions must exist, remain postgres-owned, use the intended invoker/definer mode, and pin an empty search_path'
);

create temporary table phase5a_expected_execute_acl(
  signature text not null,
  grantee text not null,
  primary key(signature, grantee)
) on commit drop;
insert into phase5a_expected_execute_acl(signature, grantee)
select signature, grantee
from (
  values
    ('private.can_view_profile(uuid)', array['authenticated']::text[]),
    ('private.profile_media_path_belongs_to_user(uuid,text)', array['authenticated','service_role']::text[]),
    ('private.profile_media_path_is_visible(text)', array['anon','authenticated']::text[]),
    ('private.assert_current_fan(boolean)', array['authenticated','service_role']::text[]),
    ('public.save_my_profile(jsonb,jsonb,jsonb)', array['authenticated']::text[]),
    ('public.admin_lift_community_posting_restriction(text,text)', array['authenticated','service_role']::text[]),
    ('public.admin_moderate_community_report(text,text,text)', array['authenticated','service_role']::text[]),
    ('public.admin_resolve_news_follow_request(text,text,text,text,text)', array['authenticated','service_role']::text[]),
    ('public.delete_my_community_comment(text)', array['authenticated','service_role']::text[]),
    ('public.edit_my_community_comment(text,text)', array['authenticated','service_role']::text[]),
    ('public.get_active_community_posting_restrictions()', array['authenticated','service_role']::text[]),
    ('public.get_community_discussion(text)', array['authenticated','service_role']::text[]),
    ('public.get_community_moderation_queue()', array['authenticated','service_role']::text[]),
    ('public.get_member_profile_by_fanatical_name(text)', array['authenticated','service_role']::text[]),
    ('public.get_my_community_moderation_notices()', array['authenticated','service_role']::text[]),
    ('public.get_my_community_notifications()', array['authenticated','service_role']::text[]),
    ('public.get_my_hidden_fans()', array['authenticated','service_role']::text[]),
    ('public.get_my_news_follow_requests()', array['authenticated','service_role']::text[]),
    ('public.get_news_discussion_teaser(text,text,text)', array['anon','authenticated','service_role']::text[]),
    ('public.get_news_follow_request_queue()', array['authenticated','service_role']::text[]),
    ('public.get_news_navigation()', array['anon','authenticated','service_role']::text[]),
    ('public.get_team_news_discussions(text)', array['authenticated','service_role']::text[]),
    ('public.hide_community_comment_author(text)', array['authenticated','service_role']::text[]),
    ('public.hide_community_user(text)', array['authenticated','service_role']::text[]),
    ('public.mark_my_community_moderation_notices_read(text[])', array['authenticated','service_role']::text[]),
    ('public.mark_my_community_notifications_read(text[])', array['authenticated','service_role']::text[]),
    ('public.post_existing_community_discussion_comment(text,text)', array['authenticated','service_role']::text[]),
    ('public.post_news_discussion_comment(text,text,text,text)', array['authenticated','service_role']::text[]),
    ('public.reply_to_community_comment(text,text,text)', array['authenticated','service_role']::text[]),
    ('public.report_community_comment(text,text,text)', array['authenticated','service_role']::text[]),
    ('public.set_my_fanatical_name(text)', array['authenticated','service_role']::text[]),
    ('public.set_my_profile_privacy(text,jsonb)', array['authenticated','service_role']::text[]),
    ('public.submit_news_follow_request(text,text)', array['authenticated','service_role']::text[]),
    ('public.unhide_community_intent(text)', array['authenticated','service_role']::text[]),
    ('public.unhide_community_user(text)', array['authenticated','service_role']::text[])
) expected(signature, grantees)
cross join lateral unnest(expected.grantees) grantee;

select pg_temp.assert_true(
  not exists (
    with actual_acl as (
      select expected.signature,
        case when access_entry.grantee = 0
          then 'PUBLIC'
          else granted_role.rolname
        end as grantee
      from phase5a_expected_functions expected
      join pg_catalog.pg_proc function_record
        on function_record.oid = to_regprocedure(expected.signature)
      cross join lateral aclexplode(coalesce(
        function_record.proacl,
        acldefault('f', function_record.proowner)
      )) access_entry
      left join pg_catalog.pg_roles granted_role
        on granted_role.oid = access_entry.grantee
      where access_entry.privilege_type = 'EXECUTE'
        and (
          access_entry.grantee = 0
          or granted_role.rolname in (
            'anon', 'authenticated', 'service_role'
          )
        )
    )
    (select * from actual_acl
     except
     select signature, grantee from phase5a_expected_execute_acl)
    union all
    (select signature, grantee from phase5a_expected_execute_acl
     except
     select * from actual_acl)
  ),
  'affected function EXECUTE grants must match the exact anon/authenticated/service matrix with no PUBLIC access'
);

select pg_temp.assert_true(
  pg_get_functiondef(
    'private.assert_current_fan(boolean)'::regprocedure
  ) ~ 'current_fan_user_id'
  and pg_get_functiondef(
    'private.current_fan_user_id()'::regprocedure
  ) ~ 'auth[.]uid'
  and pg_get_functiondef(
    'private.current_fan_user_id()'::regprocedure
  ) ~ 'private[.]fan_profile_population',
  'the ordinary-fan guard must delegate to the caller-bound governed fan-population soft-check'
);

select pg_temp.assert_true(
  (
    select relation.relkind = 'v'
      and pg_get_userbyid(relation.relowner) = 'postgres'
      and not exists (
        select 1
        from aclexplode(coalesce(
          relation.relacl, acldefault('r', relation.relowner)
        )) access_entry
        left join pg_catalog.pg_roles granted_role
          on granted_role.oid = access_entry.grantee
        where access_entry.privilege_type = 'SELECT'
          and (
            access_entry.grantee = 0
            or granted_role.rolname in (
              'anon', 'authenticated', 'service_role'
            )
          )
      )
      and pg_get_viewdef(relation.oid, true) ~ 'catalog_actors'
      and pg_get_viewdef(relation.oid, true) ~ 'actor_type'
      and pg_get_viewdef(relation.oid, true) ~ '''agent'''
      and pg_get_viewdef(relation.oid, true) ~ '''service'''
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'private'
      and relation.relname = 'fan_profile_population'
  ),
  'the postgres-owned private fan population must deny browser/service reads and exclude agent/service catalog actors'
);

select pg_temp.assert_true(
  pg_get_functiondef(
    'public.get_member_profile_by_fanatical_name(text)'::regprocedure
  ) ~ 'current_fan_user_id'
  and pg_get_functiondef(
    'public.get_member_profile_by_fanatical_name(text)'::regprocedure
  ) !~ 'assert_current_fan',
  'privacy-sensitive member profile reads must soft-fail for operational and non-fan viewers'
);

select pg_temp.assert_true(
  pg_get_functiondef(
    'public.admin_resolve_news_follow_request(text,text,text,text,text)'::regprocedure
  ) ~ 'news_request_resolve'
  and pg_get_functiondef(
    'public.get_news_follow_request_queue()'::regprocedure
  ) ~ 'news_request_resolve'
  and pg_get_functiondef(
    'public.admin_moderate_community_report(text,text,text)'::regprocedure
  ) ~ 'community_moderate'
  and pg_get_functiondef(
    'public.admin_lift_community_posting_restriction(text,text)'::regprocedure
  ) ~ 'community_moderate'
  and pg_get_functiondef(
    'public.get_community_moderation_queue()'::regprocedure
  ) ~ 'community_moderate',
  'staff RPCs must enforce their exact named capability instead of a broad role'
);

select pg_temp.assert_true(
  pg_get_functiondef(
    'public.set_my_fanatical_name(text)'::regprocedure
  ) ~ 'assert_current_fan'
  and pg_get_functiondef(
    'public.set_my_profile_privacy(text,jsonb)'::regprocedure
  ) ~ 'assert_current_fan'
  and pg_get_functiondef(
    'public.save_my_profile(jsonb,jsonb,jsonb)'::regprocedure
  ) ~ 'assert_current_fan',
  'all profile writers must reject operational and non-fan identities'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_catalog.pg_proc function_record
    join pg_catalog.pg_namespace namespace
      on namespace.oid = function_record.pronamespace
    where namespace.nspname in ('public', 'private')
      and function_record.prokind = 'f'
      and pg_get_functiondef(function_record.oid) ~
        'private[.](community_comment_versions|community_comments|community_discussions|community_hide_intents|community_moderation_actions|community_moderation_notices|community_notifications|community_posting_restriction_lifts|community_posting_restrictions|community_reports|news_follow_request_resolution_decisions|news_follow_request_targets|user_news_follow_requests)'
  ),
  'no function may retain a stale private-schema reference to a governed table'
);

select private.assert_community_domain_mutation_registry();
select private.assert_news_domain_mutation_registry();

create temporary table phase5a_expected_indexes(
  index_name text primary key,
  table_name text not null,
  key_columns text[] not null,
  partial_not_null boolean not null default false
) on commit drop;
insert into phase5a_expected_indexes(
  index_name, table_name, key_columns, partial_not_null
) values
  ('community_comment_versions_changed_by_idx', 'community_comment_versions', array['changed_by_user_id'], false),
  ('community_comments_parent_idx', 'community_comments', array['parent_comment_id','discussion_id'], true),
  ('community_discussions_created_by_idx', 'community_discussions', array['created_by_user_id'], false),
  ('community_moderation_actions_comment_idx', 'community_moderation_actions', array['comment_id'], false),
  ('community_moderation_actions_restriction_idx', 'community_moderation_actions', array['restriction_id'], false),
  ('community_moderation_actions_staff_idx', 'community_moderation_actions', array['staff_user_id'], false),
  ('community_notifications_actor_idx', 'community_notifications', array['actor_user_id'], false),
  ('community_restriction_lifts_staff_idx', 'community_posting_restriction_lifts', array['lifted_by_staff_user_id'], false),
  ('community_restrictions_applied_by_idx', 'community_posting_restrictions', array['applied_by_staff_user_id'], false),
  ('community_restrictions_origin_report_idx', 'community_posting_restrictions', array['originating_report_id'], false),
  ('news_request_decisions_org_idx', 'news_follow_request_resolution_decisions', array['resolved_organizational_contributor_id'], false),
  ('news_request_decisions_person_idx', 'news_follow_request_resolution_decisions', array['resolved_person_id'], false),
  ('news_request_decisions_show_idx', 'news_follow_request_resolution_decisions', array['resolved_show_id'], false),
  ('news_request_targets_resolved_by_idx', 'news_follow_request_targets', array['resolved_by_user_id'], false);

select pg_temp.assert_true(
  (
    select count(*) = 14
    from phase5a_expected_indexes expected
    join pg_catalog.pg_class index_relation
      on index_relation.relname = expected.index_name
     and index_relation.relkind = 'i'
    join pg_catalog.pg_namespace index_namespace
      on index_namespace.oid = index_relation.relnamespace
     and index_namespace.nspname = 'public'
    join pg_catalog.pg_index index_record
      on index_record.indexrelid = index_relation.oid
    join pg_catalog.pg_class table_relation
      on table_relation.oid = index_record.indrelid
     and table_relation.relname = expected.table_name
    where index_record.indisvalid
      and index_record.indisready
      and (
        select array_agg(
          attribute.attname::text order by key_position.ordinality
        )
        from unnest(index_record.indkey::smallint[])
          with ordinality key_position(attnum, ordinality)
        join pg_catalog.pg_attribute attribute
          on attribute.attrelid = table_relation.oid
         and attribute.attnum = key_position.attnum
        where key_position.ordinality <= index_record.indnkeyatts
      ) = expected.key_columns
      and (
        (expected.partial_not_null and
          pg_get_expr(index_record.indpred, index_record.indrelid)
            ~ 'parent_comment_id IS NOT NULL')
        or (not expected.partial_not_null and index_record.indpred is null)
      )
  ),
  'all 14 FK indexes must exist once with the exact table, key-column order, validity, and predicate'
);

rollback;
