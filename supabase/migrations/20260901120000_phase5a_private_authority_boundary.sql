-- Phase 5A durable authority correction.
--
-- The governed Community and News Request tables remain in public with RLS
-- enabled and no browser table privileges. PostgreSQL-owned SECURITY DEFINER
-- functions are the only browser-facing data path and must enforce their own
-- caller identity, capability, privacy, and separation rules.

do $migration$
declare
  target_table text;
  target_oid oid;
  target_owner text;
  target_has_rls boolean;
  target_tables constant text[] := array[
    'community_comment_versions',
    'community_comments',
    'community_discussions',
    'community_hide_intents',
    'community_moderation_actions',
    'community_moderation_notices',
    'community_notifications',
    'community_posting_restriction_lifts',
    'community_posting_restrictions',
    'community_reports',
    'news_follow_request_resolution_decisions',
    'news_follow_request_targets',
    'user_news_follow_requests'
  ];
begin
  if to_regrole('fanatical_phase5a_executor') is not null then
    raise exception
      'Rejected Phase 5A executor role exists; refusing to grant it authority';
  end if;

  foreach target_table in array target_tables loop
    target_oid := to_regclass(format('public.%I', target_table));
    if target_oid is null then
      raise exception 'Expected governed table public.% is missing', target_table;
    end if;

    select pg_get_userbyid(relation.relowner), relation.relrowsecurity
      into target_owner, target_has_rls
    from pg_catalog.pg_class relation
    where relation.oid = target_oid;

    if target_owner <> 'postgres' then
      raise exception
        'Expected public.% to remain postgres-owned, found %',
        target_table, target_owner;
    end if;

    if exists (
      select 1
      from pg_catalog.pg_policy policy
      where policy.polrelid = target_oid
    ) then
      raise exception
        'Expected RPC-only public.% to have no direct RLS policies',
        target_table;
    end if;

    execute format(
      'alter table public.%I enable row level security',
      target_table
    );
    execute format(
      'revoke all privileges on table public.%I from public, anon, authenticated',
      target_table
    );
  end loop;
end;
$migration$;

CREATE OR REPLACE FUNCTION private.current_fan_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select fan_profile.user_id
  from private.fan_profile_population fan_profile
  where fan_profile.user_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION private.assert_current_fan(require_name boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  fanatical_name_value text;
begin
  if owner_id is null then
    raise exception 'Authentication as the acting fan is required';
  end if;

  owner_id := private.current_fan_user_id();
  if owner_id is null then
    raise exception 'An ordinary fan profile is required';
  end if;

  select profile.handle
  into fanatical_name_value
  from public.profiles profile
  where profile.user_id = owner_id;

  if not found then
    raise exception 'An ordinary fan profile is required';
  end if;
  if require_name and fanatical_name_value = '' then
    raise exception 'Claim a Fanatical Name before posting';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION private.assert_community_domain_mutation_registry()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  failure_detail text;
begin
  select string_agg(
    format('%I.%I', domain_table.table_schema, domain_table.table_name),
    ', ' order by domain_table.table_name
  )
  into failure_detail
  from (
    select namespace.nspname::text as table_schema,
      relation.relname::text as table_name
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p')
      and relation.relname like 'community\_%' escape '\'
  ) domain_table
  left join private.community_domain_mutation_registry() registry
    on registry.table_schema = domain_table.table_schema
   and registry.table_name = domain_table.table_name
  where registry.table_name is null;

  if failure_detail is not null then
    raise exception 'Unregistered Community-domain tables: %', failure_detail;
  end if;

  select string_agg(
    format('%I.%I', registry.table_schema, registry.table_name),
    ', ' order by registry.table_name
  )
  into failure_detail
  from private.community_domain_mutation_registry() registry
  where to_regclass(
    format('%I.%I', registry.table_schema, registry.table_name)
  ) is null;

  if failure_detail is not null then
    raise exception 'Community registry references missing tables: %', failure_detail;
  end if;

  select string_agg(
    format('%I.%I', registry.table_schema, registry.table_name),
    ', ' order by registry.table_name
  )
  into failure_detail
  from private.community_domain_mutation_registry() registry
  where registry.mutation_mode not in ('governed', 'read_only')
     or length(btrim(registry.rationale)) = 0
     or (
       registry.mutation_mode = 'governed'
       and cardinality(registry.canonical_operations) = 0
     )
     or (
       registry.mutation_mode = 'read_only'
       and cardinality(registry.canonical_operations) <> 0
     );

  if failure_detail is not null then
    raise exception 'Invalid Community mutation registry entries: %', failure_detail;
  end if;

  select string_agg(
    format(
      '%I.%I -> %s',
      registry.table_schema,
      registry.table_name,
      operation.operation_name
    ),
    ', ' order by registry.table_name, operation.operation_name
  )
  into failure_detail
  from private.community_domain_mutation_registry() registry
  cross join lateral unnest(
    registry.canonical_operations
  ) operation(operation_name)
  where to_regprocedure(operation.operation_name) is null;

  if failure_detail is not null then
    raise exception 'Community registry references missing operations: %', failure_detail;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION private.assert_community_fan(fan_user_id uuid, require_name boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if fan_user_id is null or fan_user_id is distinct from (select auth.uid()) then
    raise exception 'Authentication as the acting fan is required';
  end if;
  perform private.assert_current_fan(require_name);
end;
$function$;

CREATE OR REPLACE FUNCTION private.community_active_suspension_end(fan_user_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select max(restriction.ends_at)
  from public.community_posting_restrictions restriction
  where restriction.user_id = fan_user_id
    and restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp()
    and not exists (
      select 1
      from public.community_posting_restriction_lifts lift
      where lift.restriction_id = restriction.id
        and lift.lifted_at <= statement_timestamp()
    );
$function$;

CREATE OR REPLACE FUNCTION private.community_discussion_context_is_current(discussion_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.community_discussions discussion
    where discussion.id = discussion_uuid
      and (
        (
          discussion.context_kind = 'team'
          and exists (
            select 1
            from public.news_item_classifications classification
            join public.news_item_classification_versions version
              on version.classification_id = classification.id
             and version.is_current
             and version.target_type = 'team'
             and version.team_id = discussion.team_id
            where classification.news_item_id = discussion.news_item_id
          )
        )
        or (
          discussion.context_kind = 'competition'
          and exists (
            select 1
            from public.news_item_classifications classification
            join public.news_item_classification_versions version
              on version.classification_id = classification.id
             and version.is_current
             and version.target_type = 'competition'
             and version.competition_id = discussion.competition_id
            where classification.news_item_id = discussion.news_item_id
          )
        )
        or (
          discussion.context_kind = 'sport'
          and private.news_item_has_effective_sport_context(
            discussion.news_item_id,
            discussion.sport_id
          )
        )
      )
  );
$function$;

CREATE OR REPLACE FUNCTION private.community_domain_mutation_registry()
 RETURNS TABLE(table_schema text, table_name text, mutation_mode text, canonical_operations text[], rationale text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select *
  from (values
    ('public', 'community_discussions', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)'], 'A contextual News discussion is materialized with its first governed comment and its count advances for every governed root or reply.'),
    ('public', 'community_comments', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)','public.edit_my_community_comment(text,text)','public.delete_my_community_comment(text)','public.admin_moderate_community_report(text,text,text)'], 'Comments use owner/staff RPCs; no browser role mutates rows directly.'),
    ('public', 'community_comment_versions', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)','public.edit_my_community_comment(text,text)','public.delete_my_community_comment(text)','public.admin_moderate_community_report(text,text,text)'], 'Internal comment history is appended only with the corresponding governed comment mutation.'),
    ('public', 'community_hide_intents', 'governed', array['public.hide_community_user(text)','public.hide_community_comment_author(text)','public.unhide_community_user(text)','public.unhide_community_intent(text)'], 'Each fan creates or removes only their directed Hide intent; an opaque intent ID keeps owner-controlled removal possible after a name is released.'),
    ('public', 'community_reports', 'governed', array['public.report_community_comment(text,text,text)','public.admin_moderate_community_report(text,text,text)'], 'Fans submit at most one report per durable comment and exact-permission staff resolve reports through bounded operations.'),
    ('public', 'community_posting_restrictions', 'governed', array['public.admin_moderate_community_report(text,text,text)'], 'Database-timed community-only restrictions are appended by exact-permission staff moderation.'),
    ('public', 'community_posting_restriction_lifts', 'governed', array['public.admin_lift_community_posting_restriction(text,text)'], 'Exact-permission staff may append one immediate reversal without mutating or deleting the original restriction.'),
    ('public', 'community_moderation_actions', 'governed', array['public.admin_moderate_community_report(text,text,text)'], 'Report moderation history is append-only.'),
    ('public', 'community_moderation_notices', 'governed', array['public.admin_moderate_community_report(text,text,text)','public.admin_lift_community_posting_restriction(text,text)','public.mark_my_community_moderation_notices_read(text[])'], 'Moderation notices are separate from the social inbox, including exactly-once posting-restoration notices.'),
    ('public', 'community_notifications', 'governed', array['private.insert_community_notification(uuid,text,uuid,uuid,uuid,jsonb)','public.mark_my_community_notifications_read(text[])'], 'Typed social notifications are inserted idempotently by governed domain operations and marked read only by their owner.')
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$function$;

CREATE OR REPLACE FUNCTION private.community_users_are_separated(first_user_id uuid, second_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when first_user_id is null or second_user_id is null
      or first_user_id = second_user_id then false
    else exists (
      select 1
      from public.community_hide_intents intent
      where (intent.hider_id = first_user_id
          and intent.hidden_id = second_user_id)
         or (intent.hider_id = second_user_id
          and intent.hidden_id = first_user_id)
    )
  end;
$function$;

CREATE OR REPLACE FUNCTION private.get_or_create_news_discussion(news_item_public_id_value text, origin_context_kind_value text, origin_context_public_id_value text, creator_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  resolved record;
  discussion_uuid uuid;
begin
  select * into resolved
  from private.resolve_news_discussion_context(
    news_item_public_id_value,
    origin_context_kind_value,
    origin_context_public_id_value
  );

  if resolved.news_item_uuid is null then
    raise exception 'Discussion is unavailable for this News context';
  end if;

  if not private.community_context_is_accessible(
    creator_user_id,
    resolved.context_kind,
    resolved.context_uuid
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'fanatical:news-discussion:'
      || resolved.news_item_uuid::text
      || ':' || resolved.context_kind
      || ':' || resolved.context_uuid::text,
      0
    )
  );

  select discussion.id
  into discussion_uuid
  from public.community_discussions discussion
  where discussion.news_item_id = resolved.news_item_uuid
    and discussion.context_kind = resolved.context_kind
    and coalesce(
      discussion.team_id,
      discussion.competition_id,
      discussion.sport_id
    ) = resolved.context_uuid;

  if discussion_uuid is null then
    insert into public.community_discussions (
      news_item_id,
      context_kind,
      team_id,
      competition_id,
      sport_id,
      created_by_user_id
    ) values (
      resolved.news_item_uuid,
      resolved.context_kind,
      case when resolved.context_kind = 'team'
        then resolved.context_uuid else null end,
      case when resolved.context_kind = 'competition'
        then resolved.context_uuid else null end,
      case when resolved.context_kind = 'sport'
        then resolved.context_uuid else null end,
      creator_user_id
    )
    returning id into discussion_uuid;
  end if;

  return discussion_uuid;
end;
$function$;

CREATE OR REPLACE FUNCTION private.insert_community_comment(discussion_uuid uuid, parent_comment_uuid uuid, body_value text, author_user_id_value uuid)
 RETURNS TABLE(comment_uuid uuid, comment_public_id text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  parent_record record;
  inserted_record record;
  normalized_body text := btrim(coalesce(body_value, ''));
  discussion_public_id text;
  discussion_context_kind text;
  discussion_context_uuid uuid;
begin
  perform private.assert_community_posting_allowed(author_user_id_value);

  if normalized_body = '' then
    raise exception 'Comment text is required';
  end if;

  select discussion.discussion_id,
    discussion.context_kind,
    coalesce(discussion.team_id, discussion.competition_id, discussion.sport_id)
  into discussion_public_id, discussion_context_kind, discussion_context_uuid
  from public.community_discussions discussion
  join public.news_item_versions item_version
    on item_version.news_item_id = discussion.news_item_id
   and item_version.is_current
   and item_version.publication_state = 'published'
   and item_version.publication_time <= statement_timestamp()
  where discussion.id = discussion_uuid;

  if discussion_public_id is null then
    raise exception 'Discussion is not currently writable';
  end if;

  if not private.community_discussion_context_is_current(discussion_uuid) then
    raise exception 'Discussion context is no longer current';
  end if;

  if not private.community_context_is_accessible(
    author_user_id_value,
    discussion_context_kind,
    discussion_context_uuid
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  if parent_comment_uuid is not null then
    select parent.id, parent.author_user_id, parent.status
    into parent_record
    from public.community_comments parent
    where parent.id = parent_comment_uuid
      and parent.discussion_id = discussion_uuid;

    if parent_record.id is null or parent_record.status <> 'active' then
      raise exception 'Reply target is unavailable';
    end if;

    perform private.lock_community_user_pair(
      author_user_id_value,
      parent_record.author_user_id
    );
    if private.community_users_are_separated(
      author_user_id_value,
      parent_record.author_user_id
    ) then
      raise exception 'Direct replies are unavailable between hidden fans';
    end if;
  end if;

  insert into public.community_comments (
    discussion_id,
    author_user_id,
    parent_comment_id,
    body
  ) values (
    discussion_uuid,
    author_user_id_value,
    parent_comment_uuid,
    normalized_body
  )
  returning id, comment_id into inserted_record;

  insert into public.community_comment_versions (
    comment_id,
    version_number,
    change_kind,
    body,
    changed_by_user_id
  ) values (
    inserted_record.id,
    1,
    'created',
    normalized_body,
    author_user_id_value
  );

  update public.community_discussions
  set comment_count = comment_count + 1
  where id = discussion_uuid;

  if parent_comment_uuid is not null then
    perform private.insert_community_notification(
      parent_record.author_user_id,
      'direct_reply',
      author_user_id_value,
      inserted_record.id,
      null,
      jsonb_build_object(
        'discussion_id', discussion_public_id,
        'comment_id', inserted_record.comment_id
      )
    );
  end if;

  return query select inserted_record.id, inserted_record.comment_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.insert_community_notification(recipient_user_id uuid, notification_type_value text, actor_user_id_value uuid, reply_comment_id_value uuid, requester_relation_id_value uuid, metadata_value jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  notification_uuid uuid;
begin
  if not exists (
    select 1
    from private.fan_profile_population fan_profile
    where fan_profile.user_id = recipient_user_id
  ) then
    return null;
  end if;

  if notification_type_value = 'direct_reply' then
    if actor_user_id_value is null
      or reply_comment_id_value is null
      or recipient_user_id = actor_user_id_value
      or private.community_users_are_separated(
        recipient_user_id,
        actor_user_id_value
      ) then
      return null;
    end if;
  elsif notification_type_value not in (
    'request_available', 'request_unable'
  ) or requester_relation_id_value is null then
    raise exception 'Invalid community notification source';
  end if;

  insert into public.community_notifications (
    user_id,
    notification_type,
    actor_user_id,
    reply_comment_id,
    requester_relation_id,
    metadata
  ) values (
    recipient_user_id,
    notification_type_value,
    actor_user_id_value,
    reply_comment_id_value,
    requester_relation_id_value,
    coalesce(metadata_value, '{}'::jsonb)
  )
  on conflict do nothing
  returning id into notification_uuid;

  if notification_uuid is null then
    select notification.id
    into notification_uuid
    from public.community_notifications notification
    where (
      notification_type_value = 'direct_reply'
      and notification.notification_type = 'direct_reply'
      and notification.reply_comment_id = reply_comment_id_value
    ) or (
      notification_type_value in ('request_available', 'request_unable')
      and notification.requester_relation_id = requester_relation_id_value
    )
    limit 1;
  end if;

  return notification_uuid;
end;
$function$;

CREATE OR REPLACE FUNCTION private.news_domain_mutation_registry()
 RETURNS TABLE(table_schema text, table_name text, mutation_mode text, canonical_operations text[], rationale text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select * from private.news_domain_mutation_registry_through_phase4()
  union all
  select *
  from (values
    ('public', 'news_follow_request_targets', 'governed', array['public.submit_news_follow_request(text,text)','public.admin_resolve_news_follow_request(text,text,text,text,text)'], 'Shared Request targets are created by fan intake and transition once through request-domain staff resolution.'),
    ('public', 'news_follow_request_resolution_decisions', 'governed', array['public.admin_resolve_news_follow_request(text,text,text,text,text)'], 'Every terminal Request target transition has an append-only request-domain decision; this is not a News identity decision action.'),
    ('public', 'user_news_follow_requests', 'governed', array['public.submit_news_follow_request(text,text)'], 'Each fan owns one immutable requester/evidence relationship to a shared target.')
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$function$;

CREATE OR REPLACE FUNCTION public.admin_lift_community_posting_restriction(restriction_public_id_value text, reason_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  staff_user_id uuid := auth.uid();
  normalized_reason text := btrim(coalesce(reason_value, ''));
  restriction_record record;
  inserted_lift_uuid uuid;
  inserted_lift_id text;
  lifted_at_value timestamptz;
begin
  if not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Community moderation permission is required';
  end if;
  if normalized_reason = '' then
    raise exception 'A lift reason is required';
  end if;

  select restriction.id,
    restriction.user_id,
    restriction.restriction_id
  into restriction_record
  from public.community_posting_restrictions restriction
  where restriction.restriction_id = restriction_public_id_value
    and restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp()
    and not exists (
      select 1
      from public.community_posting_restriction_lifts lift
      where lift.restriction_id = restriction.id
    )
  for update of restriction;

  if restriction_record.id is null then
    raise exception 'An active posting restriction was not found';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'fanatical:community-restriction:'
      || restriction_record.user_id::text,
      0
    )
  );

  insert into public.community_posting_restriction_lifts (
    restriction_id,
    lifted_by_staff_user_id,
    reason
  ) values (
    restriction_record.id,
    staff_user_id,
    normalized_reason
  )
  returning id, lift_id, lifted_at
  into inserted_lift_uuid, inserted_lift_id, lifted_at_value;

  insert into public.community_moderation_notices (
    user_id,
    moderation_action_id,
    restriction_lift_id,
    notice_type,
    message
  ) values (
    restriction_record.user_id,
    null,
    inserted_lift_uuid,
    'posting_restored',
    'Your Community suspension was lifted. You may participate again under the normal Community rules.'
  )
  on conflict (restriction_lift_id) do nothing;

  return jsonb_build_object(
    'lift_id', inserted_lift_id,
    'restriction_id', restriction_record.restriction_id,
    'lifted_at', lifted_at_value
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_moderate_community_report(report_public_id_value text, action_value text, reason_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  staff_user_id uuid := auth.uid();
  normalized_action text := lower(btrim(coalesce(action_value, '')));
  normalized_reason text := btrim(coalesce(reason_value, ''));
  report_record record;
  comment_record record;
  restriction_uuid uuid;
  restriction_public_id text;
  restriction_ordinal integer;
  restriction_start timestamptz;
  restriction_end timestamptz;
  moderation_action_uuid uuid;
  moderation_action_public_id text;
  next_version integer;
begin
  if not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Community moderation permission is required';
  end if;
  if normalized_action not in ('dismiss', 'tombstone', 'restrict') then
    raise exception 'Moderation action must be dismiss, tombstone, or restrict';
  end if;
  if normalized_reason = '' then
    raise exception 'A moderation reason is required';
  end if;

  select report.*
  into report_record
  from public.community_reports report
  where report.report_id = report_public_id_value
  for update;

  if report_record.id is null or report_record.status <> 'pending' then
    raise exception 'Pending community report was not found';
  end if;

  select comment.*
  into comment_record
  from public.community_comments comment
  where comment.id = report_record.comment_id
  for update;

  if normalized_action = 'tombstone' and comment_record.status <> 'active' then
    raise exception 'Only an active comment can be removed';
  end if;

  if normalized_action = 'tombstone' then
    select coalesce(max(version.version_number), 0) + 1
    into next_version
    from public.community_comment_versions version
    where version.comment_id = comment_record.id;

    update public.community_comments
    set body = null,
        status = 'moderated',
        tombstoned_at = statement_timestamp()
    where id = comment_record.id;

    insert into public.community_comment_versions (
      comment_id,
      version_number,
      change_kind,
      body,
      changed_by_user_id
    ) values (
      comment_record.id,
      next_version,
      'moderator_tombstoned',
      null,
      staff_user_id
    );
  elsif normalized_action = 'restrict' then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'fanatical:community-restriction:'
        || comment_record.author_user_id::text,
        0
      )
    );

    select coalesce(max(restriction.ordinal), 0) + 1,
      greatest(
        statement_timestamp(),
        coalesce(
          max(restriction.ends_at) filter (where lift.id is null),
          statement_timestamp()
        )
      )
    into restriction_ordinal, restriction_start
    from public.community_posting_restrictions restriction
    left join public.community_posting_restriction_lifts lift
      on lift.restriction_id = restriction.id
    where restriction.user_id = comment_record.author_user_id;

    restriction_end := restriction_start + case
      when restriction_ordinal <= 2 then interval '7 days'
      else interval '14 days'
    end;

    insert into public.community_posting_restrictions (
      user_id,
      ordinal,
      starts_at,
      ends_at,
      originating_report_id,
      applied_by_staff_user_id,
      reason
    ) values (
      comment_record.author_user_id,
      restriction_ordinal,
      restriction_start,
      restriction_end,
      report_record.id,
      staff_user_id,
      normalized_reason
    )
    returning id, restriction_id
    into restriction_uuid, restriction_public_id;
  end if;

  insert into public.community_moderation_actions (
    report_id,
    comment_id,
    target_user_id,
    action_type,
    restriction_id,
    staff_user_id,
    reason
  ) values (
    report_record.id,
    comment_record.id,
    comment_record.author_user_id,
    normalized_action,
    restriction_uuid,
    staff_user_id,
    normalized_reason
  )
  returning id, action_id
  into moderation_action_uuid, moderation_action_public_id;

  update public.community_reports
  set status = case when normalized_action = 'dismiss'
        then 'dismissed' else 'actioned' end,
      resolved_at = statement_timestamp()
  where id = report_record.id;

  if normalized_action = 'tombstone' then
    insert into public.community_moderation_notices (
      user_id,
      moderation_action_id,
      notice_type,
      message
    ) values (
      comment_record.author_user_id,
      moderation_action_uuid,
      'comment_removed',
      'A community moderator removed one of your comments.'
    );
  elsif normalized_action = 'restrict' then
    insert into public.community_moderation_notices (
      user_id,
      moderation_action_id,
      notice_type,
      message
    ) values (
      comment_record.author_user_id,
      moderation_action_uuid,
      'posting_restricted',
      pg_catalog.format(
        'Community participation is suspended until %s. You may continue reading Community content.',
        restriction_end
      )
    );
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'action_id', moderation_action_public_id,
    'action', normalized_action,
    'restriction_id', restriction_public_id,
    'restricted_until', restriction_end
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_resolve_news_follow_request(request_target_public_id_value text, outcome_value text, follow_target_type_value text, follow_target_public_id_value text, reason_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  staff_user_id uuid := auth.uid();
  normalized_outcome text := lower(btrim(coalesce(outcome_value, '')));
  normalized_target_type text := lower(
    nullif(btrim(follow_target_type_value), '')
  );
  normalized_target_public_id text := nullif(
    btrim(follow_target_public_id_value),
    ''
  );
  normalized_reason text := btrim(coalesce(reason_value, ''));
  target_record public.news_follow_request_targets%rowtype;
  followable_record record;
  resolved_person_uuid uuid;
  resolved_organization_uuid uuid;
  resolved_show_uuid uuid;
  requester_record public.user_news_follow_requests%rowtype;
begin
  if not public.has_staff_access(
    null,
    'news_request_resolve'
  ) then
    raise exception 'News Request resolution staff access is required';
  end if;
  if normalized_outcome not in ('available', 'unable') then
    raise exception 'Request outcome must be Available or Unable to add';
  end if;
  if normalized_reason = '' then
    raise exception 'A short staff reason is required';
  end if;

  select target.*
  into target_record
  from public.news_follow_request_targets target
  where target.request_target_id = request_target_public_id_value
  for update;

  if target_record.id is null then
    raise exception 'News Request target was not found';
  end if;
  if target_record.resolution_state <> 'pending' then
    if target_record.resolution_state = normalized_outcome then
      return jsonb_build_object(
        'request_target_id', target_record.request_target_id,
        'state', case target_record.resolution_state
          when 'available' then 'Available' else 'Unable to add' end
      );
    end if;
    raise exception 'A terminal News Request cannot be reopened or changed';
  end if;

  if normalized_outcome = 'available' then
    if normalized_target_type not in ('author', 'organization', 'show')
      or normalized_target_public_id is null then
      raise exception 'Available requires a currently followable target';
    end if;

    select followable.*
    into followable_record
    from private.current_news_followable_identities() followable
    where followable.target_type = normalized_target_type
      and followable.target_id = normalized_target_public_id;

    if followable_record.target_id is null then
      raise exception 'Available requires a currently followable target';
    end if;
    resolved_person_uuid := followable_record.person_id;
    resolved_organization_uuid :=
      followable_record.organizational_contributor_id;
    resolved_show_uuid := followable_record.show_id;
  else
    if normalized_target_type is not null
      or normalized_target_public_id is not null then
      raise exception 'Unable to add cannot link a follow target';
    end if;
  end if;

  insert into public.news_follow_request_resolution_decisions (
    request_target_id,
    outcome,
    resolved_target_type,
    resolved_person_id,
    resolved_organizational_contributor_id,
    resolved_show_id,
    reason,
    decided_by_user_id
  ) values (
    target_record.id,
    normalized_outcome,
    case when normalized_outcome = 'available'
      then normalized_target_type else null end,
    resolved_person_uuid,
    resolved_organization_uuid,
    resolved_show_uuid,
    normalized_reason,
    staff_user_id
  );

  update public.news_follow_request_targets
  set resolution_state = normalized_outcome,
      resolved_target_type = case when normalized_outcome = 'available'
        then normalized_target_type else null end,
      resolved_person_id = resolved_person_uuid,
      resolved_organizational_contributor_id = resolved_organization_uuid,
      resolved_show_id = resolved_show_uuid,
      staff_reason = normalized_reason,
      resolved_at = statement_timestamp(),
      resolved_by_user_id = staff_user_id
  where id = target_record.id
  returning * into target_record;

  for requester_record in
    select request.*
    from public.user_news_follow_requests request
    where request.request_target_id = target_record.id
    order by request.created_at, request.id
  loop
    perform private.insert_community_notification(
      requester_record.user_id,
      case normalized_outcome
        when 'available' then 'request_available'
        else 'request_unable' end,
      null,
      null,
      requester_record.id,
      private.news_request_notification_metadata(
        requester_record,
        target_record
      )
    );
  end loop;

  return jsonb_build_object(
    'request_target_id', target_record.request_target_id,
    'state', case normalized_outcome
      when 'available' then 'Available' else 'Unable to add' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.delete_my_community_comment(comment_public_id_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  comment_record record;
  next_version integer;
begin
  perform private.assert_community_participation_allowed(owner_id, false);

  select comment.*
  into comment_record
  from public.community_comments comment
  where comment.comment_id = comment_public_id_value
  for update;

  if comment_record.id is null
    or comment_record.author_user_id is distinct from owner_id then
    raise exception 'Comment was not found for this author';
  end if;

  if not exists (
    select 1
    from public.community_discussions discussion
    where discussion.id = comment_record.discussion_id
      and private.community_context_is_accessible(
        owner_id,
        discussion.context_kind,
        coalesce(discussion.team_id, discussion.competition_id, discussion.sport_id)
      )
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  select coalesce(max(version.version_number), 0) + 1
  into next_version
  from public.community_comment_versions version
  where version.comment_id = comment_record.id;

  update public.community_comments
  set body = null,
      status = 'deleted',
      tombstoned_at = statement_timestamp()
  where id = comment_record.id;

  insert into public.community_comment_versions (
    comment_id,
    version_number,
    change_kind,
    body,
    changed_by_user_id
  ) values (
    comment_record.id,
    next_version,
    'author_deleted',
    null,
    owner_id
  );

  return jsonb_build_object('comment_id', comment_public_id_value);
end;
$function$;

CREATE OR REPLACE FUNCTION public.edit_my_community_comment(comment_public_id_value text, body_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  comment_record record;
  normalized_body text := btrim(coalesce(body_value, ''));
  next_version integer;
begin
  perform private.assert_community_participation_allowed(owner_id, false);
  if normalized_body = '' then
    raise exception 'Comment text is required';
  end if;

  select comment.*
  into comment_record
  from public.community_comments comment
  where comment.comment_id = comment_public_id_value
  for update;

  if comment_record.id is null
    or comment_record.author_user_id is distinct from owner_id then
    raise exception 'Comment was not found for this author';
  end if;

  if not exists (
    select 1
    from public.community_discussions discussion
    where discussion.id = comment_record.discussion_id
      and private.community_context_is_accessible(
        owner_id,
        discussion.context_kind,
        coalesce(discussion.team_id, discussion.competition_id, discussion.sport_id)
      )
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  select coalesce(max(version.version_number), 0) + 1
  into next_version
  from public.community_comment_versions version
  where version.comment_id = comment_record.id;

  update public.community_comments
  set body = normalized_body,
      edited_at = statement_timestamp()
  where id = comment_record.id;

  insert into public.community_comment_versions (
    comment_id,
    version_number,
    change_kind,
    body,
    changed_by_user_id
  ) values (
    comment_record.id,
    next_version,
    'edited',
    normalized_body,
    owner_id
  );

  return jsonb_build_object('comment_id', comment_public_id_value);
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_active_community_posting_restrictions()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  restrictions_payload jsonb;
begin
  if not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Community moderation permission is required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'restriction_id', restriction.restriction_id,
        'fanatical_name', profile.handle,
        'ordinal', restriction.ordinal,
        'starts_at', restriction.starts_at,
        'ends_at', restriction.ends_at,
        'reason', restriction.reason,
        'created_at', restriction.created_at
      ) order by restriction.ends_at, restriction.id
    ),
    '[]'::jsonb
  )
  into restrictions_payload
  from public.community_posting_restrictions restriction
  join public.profiles profile on profile.user_id = restriction.user_id
  where restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp()
    and not exists (
      select 1
      from public.community_posting_restriction_lifts lift
      where lift.restriction_id = restriction.id
        and lift.lifted_at <= statement_timestamp()
    );

  return restrictions_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_community_discussion(discussion_public_id_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  viewer_id uuid := auth.uid();
  discussion_record record;
  comments_payload jsonb;
  restricted_until timestamptz;
  viewer_handle text;
begin
  perform private.assert_community_fan(viewer_id, false);

  select
    discussion.id,
    discussion.discussion_id,
    discussion.context_kind,
    coalesce(discussion.team_id, discussion.competition_id, discussion.sport_id)
      as context_uuid,
    discussion.comment_count,
    private.community_discussion_context_is_current(discussion.id)
      as context_is_current,
    item.id as news_item_uuid,
    item.news_item_id,
    coalesce(team.team_id, competition.competition_id, sport.sport_id)
      as context_public_id,
    coalesce(
      team_identity.display_name,
      competition_identity.display_name,
      sport.display_name,
      team.team_id,
      competition.competition_id,
      sport.sport_id
    ) as context_display_name
  into discussion_record
  from public.community_discussions discussion
  join public.news_items item on item.id = discussion.news_item_id
  left join public.catalog_teams team on team.id = discussion.team_id
  left join public.team_identity_versions team_identity
    on team_identity.team_id = team.id and team_identity.is_current
  left join public.catalog_competitions competition
    on competition.id = discussion.competition_id
  left join public.competition_identity_versions competition_identity
    on competition_identity.competition_id = competition.id
   and competition_identity.is_current
  left join public.catalog_sports sport on sport.id = discussion.sport_id
  where discussion.discussion_id = discussion_public_id_value;

  if discussion_record.id is null then
    return null;
  end if;

  if not private.community_context_is_accessible(
    viewer_id,
    discussion_record.context_kind,
    discussion_record.context_uuid
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  select profile.handle
  into viewer_handle
  from public.profiles profile
  where profile.user_id = viewer_id;

  restricted_until := private.community_active_suspension_end(viewer_id);

  with recursive descendants(root_id, descendant_id) as (
    select comment.id, comment.id
    from public.community_comments comment
    where comment.discussion_id = discussion_record.id
    union all
    select descendants.root_id, child.id
    from descendants
    join public.community_comments child
      on child.parent_comment_id = descendants.descendant_id
     and child.discussion_id = discussion_record.id
  ), descendant_counts as (
    select root_id, count(*) - 1 as reply_count
    from descendants
    group by root_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'comment_id', comment.comment_id,
        'parent_comment_id', parent.comment_id,
        'body', case
          when comment.status = 'deleted' then 'Comment deleted'
          when comment.status = 'moderated' then 'Content removed'
          when visibility.users_are_separated then 'Content unavailable'
          else comment.body
        end,
        'status', case
          when comment.status = 'deleted' then 'deleted'
          when comment.status = 'moderated' then 'moderated'
          when visibility.users_are_separated then 'unavailable'
          else 'active'
        end,
        'author_hidden', visibility.users_are_separated,
        'fanatical_name', case
          when visibility.users_are_separated then null
          else author_profile.handle
        end,
        'avatar', case
          when visibility.users_are_separated then null
          else (
            select jsonb_build_object(
              'display_path', photo.display_path,
              'width', photo.source_width,
              'height', photo.source_height,
              'focal_x', photo.focal_x,
              'focal_y', photo.focal_y,
              'zoom', photo.zoom
            )
            from public.profile_photos photo
            where photo.id = author_profile.active_profile_photo_id
              and photo.user_id = author_profile.user_id
              and private.profile_avatar_path_is_fan_safe(
                photo.user_id,
                photo.display_path
              )
          )
        end,
        'created_at', comment.created_at,
        'edited', comment.edited_at is not null,
        'reply_count', coalesce(descendant_counts.reply_count, 0),
        'can_reply', comment.status = 'active'
          and discussion_record.context_is_current
          and viewer_handle <> ''
          and restricted_until is null
          and not visibility.users_are_separated,
        'can_edit', comment.status = 'active'
          and comment.author_user_id = viewer_id
          and restricted_until is null
          and statement_timestamp() <= comment.created_at + interval '7 days',
        'can_delete', comment.status = 'active'
          and comment.author_user_id = viewer_id
          and restricted_until is null,
        'viewer_has_reported', report_state.viewer_has_reported,
        'can_report', comment.status = 'active'
          and comment.author_user_id <> viewer_id
          and not visibility.users_are_separated
          and not report_state.viewer_has_reported,
        'can_hide', comment.status = 'active'
          and comment.author_user_id <> viewer_id
          and not exists (
            select 1
            from public.community_hide_intents intent
            where intent.hider_id = viewer_id
              and intent.hidden_id = comment.author_user_id
          ),
        'my_hide_intent_id', (
          select intent.hide_intent_id
          from public.community_hide_intents intent
          where intent.hider_id = viewer_id
            and intent.hidden_id = comment.author_user_id
        ),
        'can_unhide', exists (
          select 1
          from public.community_hide_intents intent
          where intent.hider_id = viewer_id
            and intent.hidden_id = comment.author_user_id
        )
      ) order by comment.created_at, comment.id
    ),
    '[]'::jsonb
  )
  into comments_payload
  from public.community_comments comment
  left join public.community_comments parent
    on parent.id = comment.parent_comment_id
  join public.profiles author_profile
    on author_profile.user_id = comment.author_user_id
  left join descendant_counts on descendant_counts.root_id = comment.id
  cross join lateral (
    select private.community_users_are_separated(
      viewer_id,
      comment.author_user_id
    ) as users_are_separated
  ) visibility
  cross join lateral (
    select exists (
      select 1
      from public.community_reports report
      where report.comment_id = comment.id
        and report.reporting_user_id = viewer_id
    ) as viewer_has_reported
  ) report_state
  where comment.discussion_id = discussion_record.id;

  return jsonb_build_object(
    'discussion_id', discussion_record.discussion_id,
    'news_item_id', discussion_record.news_item_id,
    'context_kind', discussion_record.context_kind,
    'context_display_kind', private.community_context_display_kind(
      discussion_record.context_kind,
      discussion_record.context_uuid
    ),
    'context_id', discussion_record.context_public_id,
    'context_name', discussion_record.context_display_name,
    'comment_count', discussion_record.comment_count,
    'context_is_current', discussion_record.context_is_current,
    'viewer_has_fanatical_name', viewer_handle <> '',
    'posting_restricted_until', restricted_until,
    'article', private.news_discussion_article_payload(
      discussion_record.news_item_uuid
    ),
    'comments', comments_payload
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_community_moderation_queue()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  reports_payload jsonb;
begin
  if not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Community moderation permission is required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'report_id', report.report_id,
        'reason', report.reason,
        'explanation', report.explanation,
        'reported_at', report.created_at,
        'comment_id', comment.comment_id,
        'comment_body', report.reported_body,
        'comment_status', comment.status,
        'reported_version_number', report.reported_version_number,
        'reported_edited', report.reported_edited_at is not null,
        'author_fanatical_name', author_profile.handle,
        'reporter_fanatical_name', reporter_profile.handle,
        'prior_restriction_count', (
          select count(*)
          from public.community_posting_restrictions restriction
          where restriction.user_id = comment.author_user_id
        )
      ) order by report.created_at, report.id
    ),
    '[]'::jsonb
  )
  into reports_payload
  from public.community_reports report
  join public.community_comments comment on comment.id = report.comment_id
  join public.profiles author_profile
    on author_profile.user_id = comment.author_user_id
  join public.profiles reporter_profile
    on reporter_profile.user_id = report.reporting_user_id
  where report.status = 'pending';

  return reports_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_member_profile_by_fanatical_name(fanatical_name_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  target_user_id uuid;
begin
  if private.current_fan_user_id() is null then
    return null;
  end if;

  select profile.user_id
  into target_user_id
  from public.profiles profile
  join private.fan_profile_population fan_profile
    on fan_profile.user_id = profile.user_id
  where profile.handle <> ''
    and lower(profile.handle) = lower(btrim(fanatical_name_value));

  if target_user_id is null
    or private.community_users_are_separated(
      (select auth.uid()),
      target_user_id
    ) then
    return null;
  end if;

  return private.profile_payload_for_viewer(target_user_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_community_moderation_notices()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  notices_payload jsonb;
begin
  perform private.assert_community_fan(owner_id, false);

  select jsonb_build_object(
    'unread_count', count(*) filter (where notice.read_at is null),
    'notices', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'notice_id', notice.notice_id,
          'type', notice.notice_type,
          'message', notice.message,
          'created_at', notice.created_at,
          'read', notice.read_at is not null
        ) order by notice.created_at desc, notice.id desc
      ),
      '[]'::jsonb
    )
  )
  into notices_payload
  from public.community_moderation_notices notice
  where notice.user_id = owner_id;

  return notices_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_community_notifications()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  notifications_payload jsonb;
begin
  perform private.assert_community_fan(owner_id, false);

  select jsonb_build_object(
    'unread_count', count(*) filter (where visible.read_at is null),
    'notifications', coalesce(
      jsonb_agg(
        jsonb_strip_nulls(jsonb_build_object(
          'notification_id', visible.notification_id,
          'type', visible.notification_type,
          'actor_fanatical_name', visible.actor_fanatical_name,
          'metadata', visible.metadata,
          'created_at', visible.created_at,
          'read', visible.read_at is not null
        )) order by visible.created_at desc, visible.id desc
      ),
      '[]'::jsonb
    )
  )
  into notifications_payload
  from (
    select
      notification.id,
      notification.notification_id,
      notification.notification_type,
      notification.metadata,
      notification.created_at,
      notification.read_at,
      actor_profile.handle as actor_fanatical_name
    from public.community_notifications notification
    left join public.profiles actor_profile
      on actor_profile.user_id = notification.actor_user_id
    where notification.user_id = owner_id
      and (
        notification.notification_type <> 'direct_reply'
        or not private.community_users_are_separated(
          owner_id,
          notification.actor_user_id
        )
      )
  ) visible;

  return notifications_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_hidden_fans()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  result_payload jsonb;
begin
  perform private.assert_community_fan(owner_id, false);

  select coalesce(
    jsonb_agg(
      jsonb_strip_nulls(jsonb_build_object(
        'hide_intent_id', intent.hide_intent_id,
        'fanatical_name', nullif(profile.handle, ''),
        'hidden_since', intent.created_at,
        'also_hides_you', reverse_intent.hider_id is not null
      )) order by lower(nullif(profile.handle, '')) nulls last,
        intent.created_at, intent.hide_intent_id
    ),
    '[]'::jsonb
  )
  into result_payload
  from public.community_hide_intents intent
  join public.profiles profile on profile.user_id = intent.hidden_id
  left join public.community_hide_intents reverse_intent
    on reverse_intent.hider_id = intent.hidden_id
   and reverse_intent.hidden_id = owner_id
  where intent.hider_id = owner_id;

  return result_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_news_follow_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  requests_payload jsonb;
begin
  perform private.assert_community_fan(owner_id, false);

  select coalesce(
    jsonb_agg(
      jsonb_strip_nulls(jsonb_build_object(
        'request_id', request.request_id,
        'input_kind', request.input_kind,
        'raw_input', request.raw_input,
        'state', case target.resolution_state
          when 'available' then 'Available'
          when 'unable' then 'Unable to add'
          else 'Pending' end,
        'reason', case when target.resolution_state = 'unable'
          then target.staff_reason else null end,
        'requested_at', request.created_at,
        'resolved_at', target.resolved_at,
        'follow_target_type', case when followable.target_id is not null
          then followable.target_type else null end,
        'follow_target_id', followable.target_id,
        'follow_target_name', followable.display_name,
        'can_follow', followable.target_id is not null,
        'is_following', coalesce(follow_state.is_following, false)
      )) order by request.created_at desc, request.id desc
    ),
    '[]'::jsonb
  )
  into requests_payload
  from public.user_news_follow_requests request
  join public.news_follow_request_targets target
    on target.id = request.request_target_id
  left join lateral (
    select current_followable.*
    from private.current_news_followable_identities() current_followable
    where target.resolution_state = 'available'
      and (
        (target.resolved_target_type = 'author'
          and current_followable.target_type = 'author'
          and current_followable.person_id =
            private.try_resolve_news_canonical_person(
              target.resolved_person_id
            ))
        or (target.resolved_target_type = 'organization'
          and current_followable.target_type = 'organization'
          and current_followable.organizational_contributor_id =
            target.resolved_organizational_contributor_id)
        or (target.resolved_target_type = 'show'
          and current_followable.target_type = 'show'
          and current_followable.show_id = target.resolved_show_id)
      )
    limit 1
  ) followable on true
  left join lateral (
    select exists (
      select 1
      from public.user_news_identity_follows follow_record
      where follow_record.user_id = owner_id
        and follow_record.is_current
        and (
          (target.resolved_target_type = 'author'
            and follow_record.target_type = 'author'
            and private.try_resolve_news_canonical_person(
              follow_record.person_id
            ) = private.try_resolve_news_canonical_person(
              target.resolved_person_id
            ))
          or (target.resolved_target_type = 'organization'
            and follow_record.target_type = 'organization'
            and follow_record.organizational_contributor_id =
              target.resolved_organizational_contributor_id)
          or (target.resolved_target_type = 'show'
            and follow_record.target_type = 'show'
            and follow_record.show_id = target.resolved_show_id)
        )
    ) as is_following
  ) follow_state on true
  where request.user_id = owner_id;

  return requests_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_news_discussion_teaser(news_item_public_id_value text, origin_context_kind_value text DEFAULT NULL::text, origin_context_public_id_value text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  resolved record;
  discussion_record record;
begin
  select * into resolved
  from private.resolve_news_discussion_context(
    news_item_public_id_value,
    origin_context_kind_value,
    origin_context_public_id_value
  );

  if resolved.news_item_uuid is null then
    return jsonb_build_object(
      'available', false,
      'requires_auth', (select auth.uid()) is null,
      'viewer_can_access', case when (select auth.uid()) is null
        then null else false end,
      'comment_count', 0
    );
  end if;

  select discussion.discussion_id, discussion.comment_count
  into discussion_record
  from public.community_discussions discussion
  where discussion.news_item_id = resolved.news_item_uuid
    and discussion.context_kind = resolved.context_kind
    and coalesce(
      discussion.team_id,
      discussion.competition_id,
      discussion.sport_id
    ) = resolved.context_uuid;

  return jsonb_build_object(
    'available', true,
    'requires_auth', (select auth.uid()) is null,
    'viewer_can_access', case when (select auth.uid()) is null then null
      else exists (
        select 1
        from private.fan_profile_population fan_profile
        where fan_profile.user_id = (select auth.uid())
      ) and private.community_context_is_accessible(
          (select auth.uid()),
          resolved.context_kind,
          resolved.context_uuid
        ) end,
    'news_item_id', resolved.news_item_public_id,
    'context_kind', resolved.context_kind,
    'context_display_kind', private.community_context_display_kind(
      resolved.context_kind,
      resolved.context_uuid
    ),
    'context_id', resolved.context_public_id,
    'context_name', resolved.context_display_name,
    'discussion_id', discussion_record.discussion_id,
    'comment_count', coalesce(discussion_record.comment_count, 0),
    'article', private.news_discussion_article_payload(
      resolved.news_item_uuid
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_news_follow_request_queue()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  queue_payload jsonb;
begin
  if not public.has_staff_access(
    null,
    'news_request_resolve'
  ) then
    raise exception 'News Request resolution staff access is required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'request_target_id', target.request_target_id,
        'input_kind', target.input_kind,
        'display_input', target.display_input,
        'requester_count', (
          select count(*)
          from public.user_news_follow_requests request
          where request.request_target_id = target.id
        ),
        'created_at', target.created_at
      ) order by target.created_at, target.id
    ),
    '[]'::jsonb
  )
  into queue_payload
  from public.news_follow_request_targets target
  where target.resolution_state = 'pending';

  return queue_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_team_news_discussions(team_public_id_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  viewer_id uuid := auth.uid();
  team_record record;
  discussions_payload jsonb;
begin
  perform private.assert_community_fan(viewer_id, false);

  select team.id,
    team.team_id,
    coalesce(identity.display_name, team.team_id) as display_name
  into team_record
  from public.catalog_teams team
  left join public.team_identity_versions identity
    on identity.team_id = team.id and identity.is_current
  where team.id = public.resolve_catalog_team_id(team_public_id_value);

  if team_record.id is null then
    raise exception 'Team was not found';
  end if;

  if not private.community_context_is_accessible(
    viewer_id,
    'team',
    team_record.id
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'discussion_id', discussion.discussion_id,
        'news_item_id', ready.news_item_id,
        'context_kind', 'team',
        'context_id', team_record.team_id,
        'context_name', team_record.display_name,
        'comment_count', discussion.comment_count,
        'created_at', discussion.created_at,
        'article', private.news_discussion_article_payload(
          discussion.news_item_id
        )
      ) order by ready.publication_time desc, ready.news_item_id
    ),
    '[]'::jsonb
  )
  into discussions_payload
  from public.community_discussions discussion
  join public.news_ready_item_read_model ready
    on ready.id = discussion.news_item_id
   and ready.publication_state = 'published'
   and ready.publication_time <= statement_timestamp()
   and ready.destination_url_kind in ('canonical', 'alternate')
  where discussion.context_kind = 'team'
    and discussion.team_id = team_record.id
    and private.community_discussion_context_is_current(discussion.id);

  return discussions_payload;
end;
$function$;

CREATE OR REPLACE FUNCTION public.hide_community_comment_author(comment_public_id_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  target_user_id uuid;
  target_name text;
  comment_status text;
  context_kind_value text;
  context_uuid uuid;
begin
  perform private.assert_community_fan(owner_id, false);

  select comment.author_user_id,
    profile.handle,
    comment.status,
    discussion.context_kind,
    coalesce(
      discussion.team_id,
      discussion.competition_id,
      discussion.sport_id
    )
  into target_user_id, target_name, comment_status,
    context_kind_value, context_uuid
  from public.community_comments comment
  join public.community_discussions discussion
    on discussion.id = comment.discussion_id
  join public.profiles profile
    on profile.user_id = comment.author_user_id
  where comment.comment_id = comment_public_id_value;

  if target_user_id is null or comment_status <> 'active' then
    raise exception 'Comment author is unavailable';
  end if;
  if not private.community_context_is_accessible(
    owner_id,
    context_kind_value,
    context_uuid
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;
  if target_user_id = owner_id then
    raise exception 'A fan cannot hide themselves';
  end if;

  perform private.lock_community_user_pair(owner_id, target_user_id);
  insert into public.community_hide_intents(hider_id, hidden_id)
  values (owner_id, target_user_id)
  on conflict do nothing;

  return jsonb_strip_nulls(jsonb_build_object(
    'fanatical_name', nullif(target_name, ''),
    'hidden', true
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.hide_community_user(fanatical_name_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  target_user_id uuid;
  target_name text;
begin
  perform private.assert_community_fan(owner_id, false);

  select profile.user_id, profile.handle
  into target_user_id, target_name
  from public.profiles profile
  join private.fan_profile_population fan_profile
    on fan_profile.user_id = profile.user_id
  where profile.handle <> ''
    and lower(profile.handle) = lower(btrim(fanatical_name_value));

  if target_user_id is null then
    raise exception 'Fanatical Name was not found';
  end if;
  if target_user_id = owner_id then
    raise exception 'A fan cannot hide themselves';
  end if;

  perform private.lock_community_user_pair(owner_id, target_user_id);
  insert into public.community_hide_intents(hider_id, hidden_id)
  values (owner_id, target_user_id)
  on conflict do nothing;

  return jsonb_build_object(
    'fanatical_name', target_name,
    'hidden', true
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.mark_my_community_moderation_notices_read(notice_public_ids text[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  changed_count integer;
begin
  perform private.assert_community_fan(owner_id, false);

  update public.community_moderation_notices notice
  set read_at = statement_timestamp()
  where notice.user_id = owner_id
    and notice.read_at is null
    and notice.notice_id = any(coalesce(notice_public_ids, array[]::text[]));
  get diagnostics changed_count = row_count;
  return changed_count;
end;
$function$;

CREATE OR REPLACE FUNCTION public.mark_my_community_notifications_read(notification_public_ids text[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  changed_count integer;
begin
  perform private.assert_community_fan(owner_id, false);

  update public.community_notifications notification
  set read_at = statement_timestamp()
  where notification.user_id = owner_id
    and notification.read_at is null
    and notification.notification_id = any(
      coalesce(notification_public_ids, array[]::text[])
    )
    and (
      notification.notification_type <> 'direct_reply'
      or not private.community_users_are_separated(
        owner_id,
        notification.actor_user_id
      )
    );
  get diagnostics changed_count = row_count;
  return changed_count;
end;
$function$;

CREATE OR REPLACE FUNCTION public.post_existing_community_discussion_comment(discussion_public_id_value text, body_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  discussion_uuid uuid;
  inserted record;
begin
  perform private.assert_community_posting_allowed(owner_id);

  select discussion.id
  into discussion_uuid
  from public.community_discussions discussion
  where discussion.discussion_id = discussion_public_id_value;

  if discussion_uuid is null then
    raise exception 'Discussion was not found';
  end if;

  select * into inserted
  from private.insert_community_comment(
    discussion_uuid,
    null,
    body_value,
    owner_id
  );

  return jsonb_build_object(
    'discussion_id', discussion_public_id_value,
    'comment_id', inserted.comment_public_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.post_news_discussion_comment(news_item_public_id_value text, context_kind_value text, context_public_id_value text, body_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  discussion_uuid uuid;
  discussion_public_id text;
  inserted record;
begin
  perform private.assert_community_posting_allowed(owner_id);

  discussion_uuid := private.get_or_create_news_discussion(
    news_item_public_id_value,
    context_kind_value,
    context_public_id_value,
    owner_id
  );

  select discussion.discussion_id
  into discussion_public_id
  from public.community_discussions discussion
  where discussion.id = discussion_uuid;

  select * into inserted
  from private.insert_community_comment(
    discussion_uuid,
    null,
    body_value,
    owner_id
  );

  return jsonb_build_object(
    'discussion_id', discussion_public_id,
    'comment_id', inserted.comment_public_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.reply_to_community_comment(discussion_public_id_value text, parent_comment_public_id_value text, body_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  discussion_uuid uuid;
  parent_comment_uuid uuid;
  inserted record;
begin
  perform private.assert_community_posting_allowed(owner_id);

  select discussion.id
  into discussion_uuid
  from public.community_discussions discussion
  where discussion.discussion_id = discussion_public_id_value;
  if discussion_uuid is null then
    raise exception 'Discussion was not found';
  end if;

  select comment.id
  into parent_comment_uuid
  from public.community_comments comment
  where comment.comment_id = parent_comment_public_id_value
    and comment.discussion_id = discussion_uuid;
  if parent_comment_uuid is null then
    raise exception 'Reply target was not found';
  end if;

  select * into inserted
  from private.insert_community_comment(
    discussion_uuid,
    parent_comment_uuid,
    body_value,
    owner_id
  );

  return jsonb_build_object(
    'discussion_id', discussion_public_id_value,
    'comment_id', inserted.comment_public_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.report_community_comment(comment_public_id_value text, reason_value text, explanation_value text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  comment_record record;
  inserted_report_id text;
  existing_report_id text;
  reported_version_number_value integer;
  normalized_reason text := lower(btrim(coalesce(reason_value, '')));
  normalized_explanation text := nullif(btrim(explanation_value), '');
begin
  perform private.assert_community_fan(owner_id, false);

  if normalized_reason not in ('spam', 'harassment', 'hate', 'threats') then
    raise exception 'Report reason must be Spam, Harassment, Hate, or Threats';
  end if;

  select comment.id,
    comment.author_user_id,
    comment.status,
    comment.body,
    comment.edited_at,
    discussion.context_kind,
    coalesce(
      discussion.team_id,
      discussion.competition_id,
      discussion.sport_id
    ) as context_uuid
  into comment_record
  from public.community_comments comment
  join public.community_discussions discussion
    on discussion.id = comment.discussion_id
  where comment.comment_id = comment_public_id_value
  for share of comment;

  select max(version.version_number)
  into reported_version_number_value
  from public.community_comment_versions version
  where version.comment_id = comment_record.id;

  if comment_record.id is null or comment_record.status <> 'active' then
    raise exception 'Comment is unavailable for reporting';
  end if;
  if comment_record.author_user_id = owner_id then
    raise exception 'A fan cannot report their own comment';
  end if;
  if not private.community_context_is_accessible(
    owner_id,
    comment_record.context_kind,
    comment_record.context_uuid
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;
  if private.community_users_are_separated(
    owner_id,
    comment_record.author_user_id
  ) then
    raise exception 'Content unavailable between hidden fans cannot be reported';
  end if;

  insert into public.community_reports (
    comment_id,
    reporting_user_id,
    reason,
    explanation,
    reported_body,
    reported_edited_at,
    reported_version_number
  ) values (
    comment_record.id,
    owner_id,
    normalized_reason,
    normalized_explanation,
    comment_record.body,
    comment_record.edited_at,
    reported_version_number_value
  )
  on conflict (reporting_user_id, comment_id) do nothing
  returning report_id into inserted_report_id;

  if inserted_report_id is null then
    select report.report_id
    into existing_report_id
    from public.community_reports report
    where report.reporting_user_id = owner_id
      and report.comment_id = comment_record.id;
  end if;

  return jsonb_build_object(
    'report_id', coalesce(inserted_report_id, existing_report_id),
    'already_reported', inserted_report_id is null
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.save_my_profile(profile_data jsonb, identity_data jsonb, sports_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  requested_visibility text;
  requested_handle text := coalesce(profile_data ->> 'handle', '');
  requested_field_visibility jsonb;
  existing_legacy_fanatical_name text;
  violated_constraint_name text;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;
  perform private.assert_current_fan(false);

  select profile.visibility, profile.personal_field_visibility,
    profile.fanatical_name
  into requested_visibility, requested_field_visibility,
    existing_legacy_fanatical_name
  from public.profiles profile
  where profile.user_id = owner_id;

  requested_visibility := coalesce(
    nullif(profile_data ->> 'visibility', ''),
    requested_visibility,
    'private'
  );
  if requested_visibility = 'public' then
    requested_visibility := 'private';
  end if;
  if requested_visibility not in ('private', 'members_visible') then
    raise exception 'Profile visibility must be Private or Members-visible';
  end if;

  requested_field_visibility := coalesce(
    profile_data -> 'personal_field_visibility',
    requested_field_visibility,
    '{}'::jsonb
  );
  if not private.profile_personal_field_visibility_is_valid(
    requested_field_visibility
  ) then
    raise exception 'Personal field visibility is invalid';
  end if;

  begin
    insert into public.profiles (
      user_id, display_name, handle, fanatical_name, given_name, nickname,
      tagline, birthplace, jersey_number, height, weight,
      featured_fan_photo_category, visibility, personal_field_visibility
    ) values (
      owner_id,
      coalesce(profile_data ->> 'display_name', ''),
      requested_handle,
      case when profile_data ? 'fanatical_name'
        then nullif(profile_data ->> 'fanatical_name', '')
        else existing_legacy_fanatical_name end,
      nullif(profile_data ->> 'given_name', ''),
      nullif(profile_data ->> 'nickname', ''),
      nullif(profile_data ->> 'tagline', ''),
      nullif(profile_data ->> 'birthplace', ''),
      nullif(profile_data ->> 'jersey_number', ''),
      nullif(profile_data ->> 'height', ''),
      nullif(profile_data ->> 'weight', ''),
      coalesce(profile_data ->> 'featured_fan_photo_category', 'Fan Cave'),
      requested_visibility,
      requested_field_visibility
    )
    on conflict (user_id) do update set
      display_name = excluded.display_name,
      handle = excluded.handle,
      fanatical_name = excluded.fanatical_name,
      given_name = excluded.given_name,
      nickname = excluded.nickname,
      tagline = excluded.tagline,
      birthplace = excluded.birthplace,
      jersey_number = excluded.jersey_number,
      height = excluded.height,
      weight = excluded.weight,
      featured_fan_photo_category = excluded.featured_fan_photo_category,
      visibility = excluded.visibility,
      personal_field_visibility = excluded.personal_field_visibility;
  exception
    when unique_violation then
      get stacked diagnostics violated_constraint_name = CONSTRAINT_NAME;
      if violated_constraint_name = 'profiles_handle_normalized_unique_idx' then
        raise exception using
          errcode = '23505',
          message = 'Fanatical Name is already claimed';
      end if;
      raise;
  end;

  insert into public.fan_identities (
    user_id, fan_since, favorite_players, game_day_ritual, superstition,
    additional_identity
  ) values (
    owner_id,
    nullif(identity_data ->> 'fan_since', ''),
    nullif(identity_data ->> 'favorite_players', ''),
    nullif(identity_data ->> 'game_day_ritual', ''),
    nullif(identity_data ->> 'superstition', ''),
    coalesce(identity_data -> 'additional_identity', '{}'::jsonb)
  )
  on conflict (user_id) do update set
    fan_since = excluded.fan_since,
    favorite_players = excluded.favorite_players,
    game_day_ritual = excluded.game_day_ritual,
    superstition = excluded.superstition,
    additional_identity = excluded.additional_identity;

  delete from public.sports_played where user_id = owner_id;
  insert into public.sports_played (
    user_id, client_key, sport, position, level, years, highlight, sort_order
  )
  select
    owner_id,
    item.value ->> 'client_key',
    coalesce(item.value ->> 'sport', ''),
    nullif(item.value ->> 'position', ''),
    nullif(item.value ->> 'level', ''),
    nullif(item.value ->> 'years', ''),
    nullif(item.value ->> 'highlight', ''),
    item.ordinality - 1
  from jsonb_array_elements(coalesce(sports_data, '[]'::jsonb))
    with ordinality as item(value, ordinality);
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_my_fanatical_name(fanatical_name_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  requested_name text := btrim(coalesce(fanatical_name_value, ''));
  violated_constraint_name text;
begin
  perform private.assert_current_fan(false);

  begin
    update public.profiles
    set handle = requested_name
    where user_id = owner_id;
  exception
    when unique_violation then
      get stacked diagnostics violated_constraint_name = CONSTRAINT_NAME;
      if violated_constraint_name = 'profiles_handle_normalized_unique_idx' then
        raise exception using
          errcode = '23505',
          message = 'Fanatical Name is already claimed';
      end if;
      raise;
  end;

  if not found then
    raise exception 'Fan profile was not found';
  end if;

  return jsonb_build_object('fanatical_name', requested_name);
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_my_profile_privacy(visibility_value text, personal_field_visibility_value jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
begin
  perform private.assert_current_fan(false);
  if visibility_value not in ('private', 'members_visible') then
    raise exception 'Profile visibility must be Private or Members-visible';
  end if;
  if not private.profile_personal_field_visibility_is_valid(
    personal_field_visibility_value
  ) then
    raise exception 'Personal field visibility is invalid';
  end if;

  update public.profiles
  set visibility = visibility_value,
      personal_field_visibility = personal_field_visibility_value
  where user_id = owner_id;

  if not found then
    raise exception 'Fan profile was not found';
  end if;

  return jsonb_build_object(
    'visibility', visibility_value,
    'personal_field_visibility', personal_field_visibility_value
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.submit_news_follow_request(input_kind_value text, raw_input_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  normalized_kind text := lower(btrim(coalesce(input_kind_value, '')));
  raw_evidence text := raw_input_value;
  preserved_input text := btrim(coalesce(raw_input_value, ''));
  normalized_input_value text;
  target_record public.news_follow_request_targets%rowtype;
  requester_record public.user_news_follow_requests%rowtype;
begin
  perform private.assert_community_fan(owner_id, false);

  if normalized_kind not in ('url', 'name') then
    raise exception 'Request input must be a URL or name';
  end if;
  if preserved_input = '' then
    raise exception 'Request evidence is required';
  end if;

  if normalized_kind = 'url' then
    if preserved_input !~* '^https?://[^[:space:]]+$' then
      raise exception 'Request URL must be a public HTTP or HTTPS URL';
    end if;
    -- Exact trimmed URL is deliberately conservative: unlike source URL
    -- normalization, it does not discard a query that might identify a page.
    normalized_input_value := preserved_input;
  else
    normalized_input_value := lower(
      regexp_replace(preserved_input, '\s+', ' ', 'g')
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'fanatical:news-request:' || normalized_kind
      || ':' || normalized_input_value,
      0
    )
  );

  insert into public.news_follow_request_targets (
    input_kind,
    normalized_input,
    display_input
  ) values (
    normalized_kind,
    normalized_input_value,
    preserved_input
  )
  on conflict (input_kind, normalized_input) do nothing;

  select target.*
  into target_record
  from public.news_follow_request_targets target
  where target.input_kind = normalized_kind
    and target.normalized_input = normalized_input_value
  for update;

  insert into public.user_news_follow_requests (
    user_id,
    request_target_id,
    input_kind,
    raw_input
  ) values (
    owner_id,
    target_record.id,
    normalized_kind,
    raw_evidence
  )
  on conflict (user_id, request_target_id) do nothing;

  select request.*
  into requester_record
  from public.user_news_follow_requests request
  where request.user_id = owner_id
    and request.request_target_id = target_record.id;

  if target_record.resolution_state in ('available', 'unable') then
    perform private.insert_community_notification(
      owner_id,
      case target_record.resolution_state
        when 'available' then 'request_available'
        else 'request_unable' end,
      null,
      null,
      requester_record.id,
      private.news_request_notification_metadata(
        requester_record,
        target_record
      )
    );
  end if;

  return jsonb_build_object(
    'request_id', requester_record.request_id,
    'state', case target_record.resolution_state
      when 'available' then 'Available'
      when 'unable' then 'Unable to add'
      else 'Pending' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.unhide_community_intent(hide_intent_public_id_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  target_user_id uuid;
  target_name text;
begin
  perform private.assert_community_fan(owner_id, false);

  select intent.hidden_id, profile.handle
  into target_user_id, target_name
  from public.community_hide_intents intent
  join public.profiles profile on profile.user_id = intent.hidden_id
  where intent.hider_id = owner_id
    and intent.hide_intent_id = hide_intent_public_id_value;

  if target_user_id is null then
    raise exception 'Hide intent was not found';
  end if;

  perform private.lock_community_user_pair(owner_id, target_user_id);
  delete from public.community_hide_intents intent
  where intent.hider_id = owner_id
    and intent.hidden_id = target_user_id
    and intent.hide_intent_id = hide_intent_public_id_value;

  return jsonb_strip_nulls(jsonb_build_object(
    'fanatical_name', nullif(target_name, ''),
    'hidden', false
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.unhide_community_user(fanatical_name_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  owner_id uuid := auth.uid();
  target_user_id uuid;
  target_name text;
begin
  perform private.assert_community_fan(owner_id, false);

  select profile.user_id, profile.handle
  into target_user_id, target_name
  from public.profiles profile
  join private.fan_profile_population fan_profile
    on fan_profile.user_id = profile.user_id
  where profile.handle <> ''
    and lower(profile.handle) = lower(btrim(fanatical_name_value));

  if target_user_id is null then
    raise exception 'Fanatical Name was not found';
  end if;

  perform private.lock_community_user_pair(owner_id, target_user_id);
  delete from public.community_hide_intents intent
  where intent.hider_id = owner_id
    and intent.hidden_id = target_user_id;

  return jsonb_build_object(
    'fanatical_name', target_name,
    'hidden', false
  );
end;
$function$;

CREATE OR REPLACE FUNCTION private.assert_news_domain_mutation_registry()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  failure_detail text;
begin
  select string_agg(
    format('%I.%I', domain_table.table_schema, domain_table.table_name),
    ', ' order by domain_table.table_schema, domain_table.table_name
  )
  into failure_detail
  from (
    select namespace.nspname::text as table_schema,
      relation.relname::text as table_name
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p')
      and (
        relation.relname like 'news\_%' escape '\'
        or relation.relname like 'podcast\_%' escape '\'
        or relation.relname like 'user\_news\_%' escape '\'
        or relation.relname in (
          'catalog_people', 'person_identity_versions',
          'person_alias_versions', 'person_identifiers'
        )
      )
  ) domain_table
  left join private.news_domain_mutation_registry() registry
    on registry.table_schema = domain_table.table_schema
   and registry.table_name = domain_table.table_name
  where registry.table_name is null;

  if failure_detail is not null then
    raise exception 'Unregistered News-domain tables: %', failure_detail;
  end if;

  select string_agg(
    format('%I.%I', registry.table_schema, registry.table_name),
    ', ' order by registry.table_schema, registry.table_name
  )
  into failure_detail
  from private.news_domain_mutation_registry() registry
  where to_regclass(
    format('%I.%I', registry.table_schema, registry.table_name)
  ) is null;

  if failure_detail is not null then
    raise exception 'News mutation registry references missing tables: %',
      failure_detail;
  end if;

  select string_agg(
    format('%I.%I', registry.table_schema, registry.table_name),
    ', ' order by registry.table_schema, registry.table_name
  )
  into failure_detail
  from private.news_domain_mutation_registry() registry
  where registry.mutation_mode not in ('governed', 'read_only')
     or length(btrim(registry.rationale)) = 0
     or (
       registry.mutation_mode = 'governed'
       and cardinality(registry.canonical_operations) = 0
     )
     or (
       registry.mutation_mode = 'read_only'
       and cardinality(registry.canonical_operations) <> 0
     );

  if failure_detail is not null then
    raise exception 'Invalid News mutation registry entries: %',
      failure_detail;
  end if;

  select string_agg(
    format(
      '%I.%I -> %s',
      registry.table_schema,
      registry.table_name,
      operation.operation_name
    ),
    ', ' order by registry.table_schema, registry.table_name,
      operation.operation_name
  )
  into failure_detail
  from private.news_domain_mutation_registry() registry
  cross join lateral unnest(
    registry.canonical_operations
  ) operation(operation_name)
  where to_regprocedure(operation.operation_name) is null;

  if failure_detail is not null then
    raise exception
      'News mutation registry references missing canonical operations: %',
      failure_detail;
  end if;
end;
$function$;



revoke all on function private.assert_community_domain_mutation_registry() from public, anon, authenticated, service_role;


revoke all on function private.assert_community_fan(fan_user_id uuid, require_name boolean) from public, anon, authenticated, service_role;


revoke all on function private.assert_community_participation_allowed(fan_user_id uuid, require_fanatical_name boolean) from public, anon, authenticated, service_role;


revoke all on function private.assert_community_posting_allowed(fan_user_id uuid) from public, anon, authenticated, service_role;


revoke all on function private.can_view_profile(profile_user_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.can_view_profile(profile_user_id uuid) to authenticated;

revoke all on function private.community_active_suspension_end(fan_user_id uuid) from public, anon, authenticated, service_role;


revoke all on function private.community_context_display_kind(context_kind_value text, context_uuid_value uuid) from public, anon, authenticated, service_role;


revoke all on function private.community_context_is_accessible(fan_user_id uuid, context_kind_value text, context_uuid uuid) from public, anon, authenticated, service_role;


revoke all on function private.community_discussion_context_is_current(discussion_uuid uuid) from public, anon, authenticated, service_role;


revoke all on function private.community_domain_mutation_registry() from public, anon, authenticated, service_role;


revoke all on function private.community_users_are_separated(first_user_id uuid, second_user_id uuid) from public, anon, authenticated, service_role;


revoke all on function private.get_or_create_news_discussion(news_item_public_id_value text, origin_context_kind_value text, origin_context_public_id_value text, creator_user_id uuid) from public, anon, authenticated, service_role;


revoke all on function private.insert_community_comment(discussion_uuid uuid, parent_comment_uuid uuid, body_value text, author_user_id_value uuid) from public, anon, authenticated, service_role;


revoke all on function private.insert_community_notification(recipient_user_id uuid, notification_type_value text, actor_user_id_value uuid, reply_comment_id_value uuid, requester_relation_id_value uuid, metadata_value jsonb) from public, anon, authenticated, service_role;


revoke all on function private.lock_community_user_pair(first_user_id uuid, second_user_id uuid) from public, anon, authenticated, service_role;


revoke all on function private.news_discussion_article_payload(news_item_uuid uuid) from public, anon, authenticated, service_role;


revoke all on function private.news_domain_mutation_registry() from public, anon, authenticated, service_role;


revoke all on function private.news_item_has_effective_sport_context(news_item_uuid uuid, sport_uuid uuid) from public, anon, authenticated, service_role;


revoke all on function private.news_request_notification_metadata(request_record public.user_news_follow_requests, target_record public.news_follow_request_targets) from public, anon, authenticated, service_role;


revoke all on function private.profile_avatar_path_is_attributable(object_name text) from public, anon, authenticated, service_role;


revoke all on function private.profile_avatar_path_is_fan_safe(profile_user_id uuid, object_name text) from public, anon, authenticated, service_role;


revoke all on function private.profile_media_path_belongs_to_user(profile_user_id uuid, object_name text) from public, anon, authenticated, service_role;
grant execute on function private.profile_media_path_belongs_to_user(profile_user_id uuid, object_name text) to authenticated;
grant execute on function private.profile_media_path_belongs_to_user(profile_user_id uuid, object_name text) to service_role;

revoke all on function private.profile_media_path_is_visible(object_name text) from public, anon, authenticated, service_role;
grant execute on function private.profile_media_path_is_visible(object_name text) to anon;
grant execute on function private.profile_media_path_is_visible(object_name text) to authenticated;

revoke all on function private.profile_payload_for_viewer(profile_user_id uuid) from public, anon, authenticated, service_role;


revoke all on function private.resolve_news_discussion_context(news_item_public_id_value text, origin_context_kind_value text, origin_context_public_id_value text) from public, anon, authenticated, service_role;


revoke all on function private.validate_profile_handle(handle_value text) from public, anon, authenticated, service_role;


revoke all on function public.admin_lift_community_posting_restriction(restriction_public_id_value text, reason_value text) from public, anon, authenticated, service_role;
grant execute on function public.admin_lift_community_posting_restriction(restriction_public_id_value text, reason_value text) to authenticated;
grant execute on function public.admin_lift_community_posting_restriction(restriction_public_id_value text, reason_value text) to service_role;

revoke all on function public.admin_moderate_community_report(report_public_id_value text, action_value text, reason_value text) from public, anon, authenticated, service_role;
grant execute on function public.admin_moderate_community_report(report_public_id_value text, action_value text, reason_value text) to authenticated;
grant execute on function public.admin_moderate_community_report(report_public_id_value text, action_value text, reason_value text) to service_role;

revoke all on function public.admin_resolve_news_follow_request(request_target_public_id_value text, outcome_value text, follow_target_type_value text, follow_target_public_id_value text, reason_value text) from public, anon, authenticated, service_role;
grant execute on function public.admin_resolve_news_follow_request(request_target_public_id_value text, outcome_value text, follow_target_type_value text, follow_target_public_id_value text, reason_value text) to authenticated;
grant execute on function public.admin_resolve_news_follow_request(request_target_public_id_value text, outcome_value text, follow_target_type_value text, follow_target_public_id_value text, reason_value text) to service_role;

revoke all on function public.delete_my_community_comment(comment_public_id_value text) from public, anon, authenticated, service_role;
grant execute on function public.delete_my_community_comment(comment_public_id_value text) to authenticated;
grant execute on function public.delete_my_community_comment(comment_public_id_value text) to service_role;

revoke all on function public.edit_my_community_comment(comment_public_id_value text, body_value text) from public, anon, authenticated, service_role;
grant execute on function public.edit_my_community_comment(comment_public_id_value text, body_value text) to authenticated;
grant execute on function public.edit_my_community_comment(comment_public_id_value text, body_value text) to service_role;

revoke all on function public.get_active_community_posting_restrictions() from public, anon, authenticated, service_role;
grant execute on function public.get_active_community_posting_restrictions() to authenticated;
grant execute on function public.get_active_community_posting_restrictions() to service_role;

revoke all on function public.get_community_discussion(discussion_public_id_value text) from public, anon, authenticated, service_role;
grant execute on function public.get_community_discussion(discussion_public_id_value text) to authenticated;
grant execute on function public.get_community_discussion(discussion_public_id_value text) to service_role;

revoke all on function public.get_community_moderation_queue() from public, anon, authenticated, service_role;
grant execute on function public.get_community_moderation_queue() to authenticated;
grant execute on function public.get_community_moderation_queue() to service_role;

revoke all on function public.get_member_profile_by_fanatical_name(fanatical_name_value text) from public, anon, authenticated, service_role;
grant execute on function public.get_member_profile_by_fanatical_name(fanatical_name_value text) to authenticated;
grant execute on function public.get_member_profile_by_fanatical_name(fanatical_name_value text) to service_role;

revoke all on function public.get_my_community_moderation_notices() from public, anon, authenticated, service_role;
grant execute on function public.get_my_community_moderation_notices() to authenticated;
grant execute on function public.get_my_community_moderation_notices() to service_role;

revoke all on function public.get_my_community_notifications() from public, anon, authenticated, service_role;
grant execute on function public.get_my_community_notifications() to authenticated;
grant execute on function public.get_my_community_notifications() to service_role;

revoke all on function public.get_my_hidden_fans() from public, anon, authenticated, service_role;
grant execute on function public.get_my_hidden_fans() to authenticated;
grant execute on function public.get_my_hidden_fans() to service_role;

revoke all on function public.get_my_news_follow_requests() from public, anon, authenticated, service_role;
grant execute on function public.get_my_news_follow_requests() to authenticated;
grant execute on function public.get_my_news_follow_requests() to service_role;

revoke all on function public.get_news_discussion_teaser(news_item_public_id_value text, origin_context_kind_value text, origin_context_public_id_value text) from public, anon, authenticated, service_role;
grant execute on function public.get_news_discussion_teaser(news_item_public_id_value text, origin_context_kind_value text, origin_context_public_id_value text) to anon;
grant execute on function public.get_news_discussion_teaser(news_item_public_id_value text, origin_context_kind_value text, origin_context_public_id_value text) to authenticated;
grant execute on function public.get_news_discussion_teaser(news_item_public_id_value text, origin_context_kind_value text, origin_context_public_id_value text) to service_role;

revoke all on function public.get_news_follow_request_queue() from public, anon, authenticated, service_role;
grant execute on function public.get_news_follow_request_queue() to authenticated;
grant execute on function public.get_news_follow_request_queue() to service_role;

revoke all on function public.get_news_navigation() from public, anon, authenticated, service_role;
grant execute on function public.get_news_navigation() to anon;
grant execute on function public.get_news_navigation() to authenticated;
grant execute on function public.get_news_navigation() to service_role;

revoke all on function public.get_team_news_discussions(team_public_id_value text) from public, anon, authenticated, service_role;
grant execute on function public.get_team_news_discussions(team_public_id_value text) to authenticated;
grant execute on function public.get_team_news_discussions(team_public_id_value text) to service_role;

revoke all on function public.hide_community_comment_author(comment_public_id_value text) from public, anon, authenticated, service_role;
grant execute on function public.hide_community_comment_author(comment_public_id_value text) to authenticated;
grant execute on function public.hide_community_comment_author(comment_public_id_value text) to service_role;

revoke all on function public.hide_community_user(fanatical_name_value text) from public, anon, authenticated, service_role;
grant execute on function public.hide_community_user(fanatical_name_value text) to authenticated;
grant execute on function public.hide_community_user(fanatical_name_value text) to service_role;

revoke all on function public.mark_my_community_moderation_notices_read(notice_public_ids text[]) from public, anon, authenticated, service_role;
grant execute on function public.mark_my_community_moderation_notices_read(notice_public_ids text[]) to authenticated;
grant execute on function public.mark_my_community_moderation_notices_read(notice_public_ids text[]) to service_role;

revoke all on function public.mark_my_community_notifications_read(notification_public_ids text[]) from public, anon, authenticated, service_role;
grant execute on function public.mark_my_community_notifications_read(notification_public_ids text[]) to authenticated;
grant execute on function public.mark_my_community_notifications_read(notification_public_ids text[]) to service_role;

revoke all on function public.post_existing_community_discussion_comment(discussion_public_id_value text, body_value text) from public, anon, authenticated, service_role;
grant execute on function public.post_existing_community_discussion_comment(discussion_public_id_value text, body_value text) to authenticated;
grant execute on function public.post_existing_community_discussion_comment(discussion_public_id_value text, body_value text) to service_role;

revoke all on function public.post_news_discussion_comment(news_item_public_id_value text, context_kind_value text, context_public_id_value text, body_value text) from public, anon, authenticated, service_role;
grant execute on function public.post_news_discussion_comment(news_item_public_id_value text, context_kind_value text, context_public_id_value text, body_value text) to authenticated;
grant execute on function public.post_news_discussion_comment(news_item_public_id_value text, context_kind_value text, context_public_id_value text, body_value text) to service_role;

revoke all on function public.reply_to_community_comment(discussion_public_id_value text, parent_comment_public_id_value text, body_value text) from public, anon, authenticated, service_role;
grant execute on function public.reply_to_community_comment(discussion_public_id_value text, parent_comment_public_id_value text, body_value text) to authenticated;
grant execute on function public.reply_to_community_comment(discussion_public_id_value text, parent_comment_public_id_value text, body_value text) to service_role;

revoke all on function public.report_community_comment(comment_public_id_value text, reason_value text, explanation_value text) from public, anon, authenticated, service_role;
grant execute on function public.report_community_comment(comment_public_id_value text, reason_value text, explanation_value text) to authenticated;
grant execute on function public.report_community_comment(comment_public_id_value text, reason_value text, explanation_value text) to service_role;

revoke all on function public.set_my_fanatical_name(fanatical_name_value text) from public, anon, authenticated, service_role;
grant execute on function public.set_my_fanatical_name(fanatical_name_value text) to authenticated;
grant execute on function public.set_my_fanatical_name(fanatical_name_value text) to service_role;

revoke all on function public.set_my_profile_privacy(visibility_value text, personal_field_visibility_value jsonb) from public, anon, authenticated, service_role;
grant execute on function public.set_my_profile_privacy(visibility_value text, personal_field_visibility_value jsonb) to authenticated;
grant execute on function public.set_my_profile_privacy(visibility_value text, personal_field_visibility_value jsonb) to service_role;

revoke all on function public.submit_news_follow_request(input_kind_value text, raw_input_value text) from public, anon, authenticated, service_role;
grant execute on function public.submit_news_follow_request(input_kind_value text, raw_input_value text) to authenticated;
grant execute on function public.submit_news_follow_request(input_kind_value text, raw_input_value text) to service_role;

revoke all on function public.unhide_community_intent(hide_intent_public_id_value text) from public, anon, authenticated, service_role;
grant execute on function public.unhide_community_intent(hide_intent_public_id_value text) to authenticated;
grant execute on function public.unhide_community_intent(hide_intent_public_id_value text) to service_role;

revoke all on function public.unhide_community_user(fanatical_name_value text) from public, anon, authenticated, service_role;
grant execute on function public.unhide_community_user(fanatical_name_value text) to authenticated;
grant execute on function public.unhide_community_user(fanatical_name_value text) to service_role;

revoke all on function private.assert_news_domain_mutation_registry()
  from public, anon, authenticated, service_role;
revoke all on function private.current_fan_user_id()
  from public, anon, authenticated, service_role;
revoke all on function private.assert_current_fan(boolean)
  from public, anon, authenticated, service_role;
grant execute on function private.assert_current_fan(boolean)
  to authenticated, service_role;

comment on function private.current_fan_user_id() is
  'Internal soft-check for an authenticated ordinary fan; callers choose null-return or canonical rejection semantics.';
comment on function private.assert_current_fan(boolean) is
  'Rejects non-fan and operational identities before fan-facing writes or Community behavior.';
comment on function public.get_news_discussion_teaser(text, text, text) is
  'Anonymous-safe contextual count and published-article teaser; never returns comments or profile payloads.';

select private.assert_community_domain_mutation_registry();
select private.assert_news_domain_mutation_registry();
