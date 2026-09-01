-- Phase 5A governed Community foundation for contextual News discussions.
-- Production FANbase prototype state is deliberately not imported.

-- Register every mutable community_* table before creating it. The assertion
-- runs after all named operations exist.
create or replace function private.community_domain_mutation_registry()
returns table (
  table_schema text,
  table_name text,
  mutation_mode text,
  canonical_operations text[],
  rationale text
)
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from (values
    ('public', 'community_discussions', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)'], 'A contextual News discussion is materialized with its first governed comment and its count advances for every governed root or reply.'),
    ('public', 'community_comments', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)','public.edit_my_community_comment(text,text)','public.delete_my_community_comment(text)','public.admin_moderate_community_report(text,text,text)'], 'Comments use owner/staff RPCs; no browser role mutates rows directly.'),
    ('public', 'community_comment_versions', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)','public.edit_my_community_comment(text,text)','public.delete_my_community_comment(text)','public.admin_moderate_community_report(text,text,text)'], 'Internal comment history is appended only with the corresponding governed comment mutation.'),
    ('public', 'community_hide_intents', 'governed', array['public.hide_community_user(text)','public.hide_community_comment_author(text)','public.unhide_community_user(text)','public.unhide_community_intent(text)'], 'Each fan creates or removes only their directed Hide intent; an opaque intent ID keeps owner-controlled removal possible after a name is released.'),
    ('public', 'community_reports', 'governed', array['public.report_community_comment(text,text,text)','public.admin_moderate_community_report(text,text,text)'], 'Fans submit reports and exact-permission staff resolve them through bounded operations.'),
    ('public', 'community_posting_restrictions', 'governed', array['public.admin_moderate_community_report(text,text,text)'], 'Database-timed community-only restrictions are appended by exact-permission staff moderation.'),
    ('public', 'community_moderation_actions', 'governed', array['public.admin_moderate_community_report(text,text,text)'], 'Moderation history is append-only.'),
    ('public', 'community_moderation_notices', 'governed', array['public.admin_moderate_community_report(text,text,text)','public.mark_my_community_moderation_notices_read(text[])'], 'Moderation notices are separate from the social inbox.'),
    ('public', 'community_notifications', 'governed', array['private.insert_community_notification(uuid,text,uuid,uuid,uuid,jsonb)','public.mark_my_community_notifications_read(text[])'], 'Typed social notifications are inserted idempotently by governed domain operations and marked read only by their owner.')
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$$;

revoke all on function private.community_domain_mutation_registry()
from public, anon, authenticated;

create or replace function private.assert_community_domain_mutation_registry()
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function private.assert_community_domain_mutation_registry()
from public, anon, authenticated;

create table public.community_discussions (
  id uuid primary key default gen_random_uuid(),
  discussion_id text not null unique default (
    'community-discussion-' || replace(gen_random_uuid()::text, '-', '')
  ) check (discussion_id ~ '^community-discussion-[0-9a-f]{32}$'),
  news_item_id uuid not null references public.news_items(id) on delete restrict,
  context_kind text not null check (
    context_kind in ('team', 'competition', 'sport')
  ),
  team_id uuid references public.catalog_teams(id) on delete restrict,
  competition_id uuid
    references public.catalog_competitions(id) on delete restrict,
  sport_id uuid references public.catalog_sports(id) on delete restrict,
  comment_count bigint not null default 0 check (comment_count >= 0),
  created_by_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  check (num_nonnulls(team_id, competition_id, sport_id) = 1),
  check (
    (context_kind = 'team' and team_id is not null)
    or (context_kind = 'competition' and competition_id is not null)
    or (context_kind = 'sport' and sport_id is not null)
  )
);

create unique index community_discussions_item_team_unique_idx
on public.community_discussions(news_item_id, team_id)
where context_kind = 'team';
create unique index community_discussions_item_competition_unique_idx
on public.community_discussions(news_item_id, competition_id)
where context_kind = 'competition';
create unique index community_discussions_item_sport_unique_idx
on public.community_discussions(news_item_id, sport_id)
where context_kind = 'sport';
create index community_discussions_news_item_idx
on public.community_discussions(news_item_id);
create index community_discussions_team_fk_idx
on public.community_discussions(team_id) where team_id is not null;
create index community_discussions_competition_fk_idx
on public.community_discussions(competition_id)
where competition_id is not null;
create index community_discussions_sport_fk_idx
on public.community_discussions(sport_id) where sport_id is not null;

create table public.community_comments (
  id uuid primary key default gen_random_uuid(),
  comment_id text not null unique default (
    'community-comment-' || replace(gen_random_uuid()::text, '-', '')
  ) check (comment_id ~ '^community-comment-[0-9a-f]{32}$'),
  discussion_id uuid not null
    references public.community_discussions(id) on delete restrict,
  author_user_id uuid not null references public.profiles(user_id) on delete restrict,
  parent_comment_id uuid,
  body text,
  status text not null default 'active'
    check (status in ('active', 'deleted', 'moderated')),
  created_at timestamptz not null default statement_timestamp(),
  edited_at timestamptz,
  tombstoned_at timestamptz,
  unique (id, discussion_id),
  check (
    (status = 'active' and body is not null and length(btrim(body)) > 0
      and tombstoned_at is null)
    or (status in ('deleted', 'moderated') and body is null
      and tombstoned_at is not null)
  ),
  check (edited_at is null or edited_at >= created_at),
  check (parent_comment_id is null or parent_comment_id <> id),
  foreign key (parent_comment_id, discussion_id)
    references public.community_comments(id, discussion_id) on delete restrict
);

create index community_comments_discussion_created_idx
on public.community_comments(discussion_id, created_at, id);
create index community_comments_parent_idx
on public.community_comments(parent_comment_id)
where parent_comment_id is not null;
create index community_comments_author_created_idx
on public.community_comments(author_user_id, created_at desc);

create table public.community_comment_versions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null
    references public.community_comments(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  change_kind text not null check (
    change_kind in (
      'created', 'edited', 'author_deleted', 'moderator_tombstoned'
    )
  ),
  body text,
  changed_by_user_id uuid not null references auth.users(id) on delete restrict,
  changed_at timestamptz not null default statement_timestamp(),
  unique (comment_id, version_number),
  check (
    (change_kind in ('created', 'edited') and body is not null)
    or (change_kind in ('author_deleted', 'moderator_tombstoned'))
  )
);

create index community_comment_versions_comment_idx
on public.community_comment_versions(comment_id, version_number);

create table public.community_hide_intents (
  hider_id uuid not null references public.profiles(user_id) on delete cascade,
  hidden_id uuid not null references public.profiles(user_id) on delete cascade,
  hide_intent_id text not null unique default (
    'community-hide-' || replace(gen_random_uuid()::text, '-', '')
  ) check (hide_intent_id ~ '^community-hide-[0-9a-f]{32}$'),
  created_at timestamptz not null default statement_timestamp(),
  primary key (hider_id, hidden_id),
  check (hider_id <> hidden_id)
);

create index community_hide_intents_hidden_idx
on public.community_hide_intents(hidden_id, hider_id);

create table public.community_reports (
  id uuid primary key default gen_random_uuid(),
  report_id text not null unique default (
    'community-report-' || replace(gen_random_uuid()::text, '-', '')
  ) check (report_id ~ '^community-report-[0-9a-f]{32}$'),
  comment_id uuid not null
    references public.community_comments(id) on delete restrict,
  reporting_user_id uuid not null
    references public.profiles(user_id) on delete restrict,
  reason text not null check (
    reason in ('spam', 'harassment', 'hate', 'threats')
  ),
  explanation text check (
    explanation is null or length(btrim(explanation)) > 0
  ),
  reported_body text not null check (length(btrim(reported_body)) > 0),
  reported_edited_at timestamptz,
  reported_version_number integer not null
    check (reported_version_number > 0),
  status text not null default 'pending'
    check (status in ('pending', 'dismissed', 'actioned')),
  created_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz
);

create index community_reports_status_created_idx
on public.community_reports(status, created_at, id);
create index community_reports_comment_idx
on public.community_reports(comment_id);
create index community_reports_reporting_user_idx
on public.community_reports(reporting_user_id, created_at desc);

create table public.community_posting_restrictions (
  id uuid primary key default gen_random_uuid(),
  restriction_id text not null unique default (
    'community-restriction-' || replace(gen_random_uuid()::text, '-', '')
  ) check (restriction_id ~ '^community-restriction-[0-9a-f]{32}$'),
  user_id uuid not null references public.profiles(user_id) on delete restrict,
  ordinal integer not null check (ordinal > 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  originating_report_id uuid
    references public.community_reports(id) on delete restrict,
  applied_by_staff_user_id uuid not null
    references auth.users(id) on delete restrict,
  reason text not null check (length(btrim(reason)) > 0),
  created_at timestamptz not null default statement_timestamp(),
  unique (user_id, ordinal),
  check (ends_at > starts_at)
);

create index community_posting_restrictions_user_ends_idx
on public.community_posting_restrictions(user_id, ends_at desc);

create table public.community_moderation_actions (
  id uuid primary key default gen_random_uuid(),
  action_id text not null unique default (
    'community-moderation-' || replace(gen_random_uuid()::text, '-', '')
  ) check (action_id ~ '^community-moderation-[0-9a-f]{32}$'),
  report_id uuid not null
    references public.community_reports(id) on delete restrict,
  comment_id uuid not null
    references public.community_comments(id) on delete restrict,
  target_user_id uuid not null
    references public.profiles(user_id) on delete restrict,
  action_type text not null check (
    action_type in ('dismiss', 'tombstone', 'restrict')
  ),
  restriction_id uuid
    references public.community_posting_restrictions(id) on delete restrict,
  staff_user_id uuid not null references auth.users(id) on delete restrict,
  reason text not null check (length(btrim(reason)) > 0),
  created_at timestamptz not null default statement_timestamp(),
  check (
    (action_type = 'restrict' and restriction_id is not null)
    or (action_type <> 'restrict' and restriction_id is null)
  )
);

create index community_moderation_actions_report_idx
on public.community_moderation_actions(report_id, created_at);
create index community_moderation_actions_target_idx
on public.community_moderation_actions(target_user_id, created_at desc);

create table public.community_moderation_notices (
  id uuid primary key default gen_random_uuid(),
  notice_id text not null unique default (
    'community-notice-' || replace(gen_random_uuid()::text, '-', '')
  ) check (notice_id ~ '^community-notice-[0-9a-f]{32}$'),
  user_id uuid not null references public.profiles(user_id) on delete restrict,
  moderation_action_id uuid not null
    references public.community_moderation_actions(id) on delete restrict,
  notice_type text not null check (
    notice_type in ('comment_removed', 'posting_restricted')
  ),
  message text not null check (length(btrim(message)) > 0),
  created_at timestamptz not null default statement_timestamp(),
  read_at timestamptz,
  unique (moderation_action_id, notice_type)
);

create index community_moderation_notices_user_unread_idx
on public.community_moderation_notices(user_id, created_at desc)
where read_at is null;

create table public.community_notifications (
  id uuid primary key default gen_random_uuid(),
  notification_id text not null unique default (
    'community-notification-' || replace(gen_random_uuid()::text, '-', '')
  ) check (notification_id ~ '^community-notification-[0-9a-f]{32}$'),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  notification_type text not null check (
    notification_type in (
      'direct_reply', 'request_available', 'request_unable'
    )
  ),
  actor_user_id uuid references public.profiles(user_id) on delete restrict,
  reply_comment_id uuid
    references public.community_comments(id) on delete restrict,
  requester_relation_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default statement_timestamp(),
  read_at timestamptz,
  check (
    (
      notification_type = 'direct_reply'
      and actor_user_id is not null
      and reply_comment_id is not null
      and requester_relation_id is null
    )
    or (
      notification_type in ('request_available', 'request_unable')
      and actor_user_id is null
      and reply_comment_id is null
      and requester_relation_id is not null
    )
  )
);

create unique index community_notifications_direct_reply_unique_idx
on public.community_notifications(reply_comment_id)
where notification_type = 'direct_reply';
create unique index community_notifications_request_unique_idx
on public.community_notifications(requester_relation_id)
where notification_type in ('request_available', 'request_unable');
create index community_notifications_user_unread_idx
on public.community_notifications(user_id, created_at desc)
where read_at is null;

alter table public.community_discussions enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_comment_versions enable row level security;
alter table public.community_hide_intents enable row level security;
alter table public.community_reports enable row level security;
alter table public.community_posting_restrictions enable row level security;
alter table public.community_moderation_actions enable row level security;
alter table public.community_moderation_notices enable row level security;
alter table public.community_notifications enable row level security;

revoke all on table public.community_discussions,
  public.community_comments,
  public.community_comment_versions,
  public.community_hide_intents,
  public.community_reports,
  public.community_posting_restrictions,
  public.community_moderation_actions,
  public.community_moderation_notices,
  public.community_notifications
from public, anon, authenticated;

create or replace function private.protect_community_immutable_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% history is append-only', tg_table_name;
end;
$$;

revoke all on function private.protect_community_immutable_row()
from public, anon, authenticated;

create trigger protect_community_comment_versions
before update or delete on public.community_comment_versions
for each row execute function private.protect_community_immutable_row();
create trigger protect_community_posting_restrictions
before update or delete on public.community_posting_restrictions
for each row execute function private.protect_community_immutable_row();
create trigger protect_community_moderation_actions
before update or delete on public.community_moderation_actions
for each row execute function private.protect_community_immutable_row();

create or replace function private.enforce_community_discussion_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(
    new.id, new.discussion_id, new.news_item_id, new.context_kind,
    new.team_id, new.competition_id, new.sport_id,
    new.created_by_user_id, new.created_at
  ) is distinct from row(
    old.id, old.discussion_id, old.news_item_id, old.context_kind,
    old.team_id, old.competition_id, old.sport_id,
    old.created_by_user_id, old.created_at
  ) then
    raise exception 'Community discussion identity is immutable';
  end if;

  if new.comment_count <> old.comment_count + 1 then
    raise exception 'Community discussion count advances by one inserted node';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_community_discussion_update()
from public, anon, authenticated;
create trigger enforce_community_discussion_update
before update on public.community_discussions
for each row execute function private.enforce_community_discussion_update();

create or replace function private.enforce_community_comment_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(
    new.id, new.comment_id, new.discussion_id, new.author_user_id,
    new.parent_comment_id, new.created_at
  ) is distinct from row(
    old.id, old.comment_id, old.discussion_id, old.author_user_id,
    old.parent_comment_id, old.created_at
  ) then
    raise exception 'Community comment identity and topology are immutable';
  end if;

  if old.status <> 'active' then
    raise exception 'A tombstoned comment cannot be restored or changed';
  end if;

  if new.status = 'active' then
    if (select auth.uid()) is distinct from old.author_user_id then
      raise exception 'Only the comment author may edit it';
    end if;
    if statement_timestamp() > old.created_at + interval '7 days' then
      raise exception 'The seven-day comment edit window has ended';
    end if;
    if new.body is not distinct from old.body
      or new.edited_at is null
      or new.tombstoned_at is not null then
      raise exception 'Invalid community comment edit';
    end if;
  elsif new.status = 'deleted' then
    if (select auth.uid()) is distinct from old.author_user_id then
      raise exception 'Only the comment author may delete it';
    end if;
    if new.body is not null or new.tombstoned_at is null then
      raise exception 'Deleted comments must be tombstones';
    end if;
  elsif new.status = 'moderated' then
    if not public.has_staff_access(null, 'community_moderate') then
      raise exception 'Community moderation permission is required';
    end if;
    if new.body is not null or new.tombstoned_at is null then
      raise exception 'Moderated comments must be tombstones';
    end if;
  else
    raise exception 'Invalid community comment transition';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_community_comment_update()
from public, anon, authenticated;
create trigger enforce_community_comment_update
before update on public.community_comments
for each row execute function private.enforce_community_comment_update();

create or replace function private.enforce_community_report_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(
    new.id, new.report_id, new.comment_id, new.reporting_user_id,
    new.reason, new.explanation, new.reported_body,
    new.reported_edited_at, new.reported_version_number, new.created_at
  ) is distinct from row(
    old.id, old.report_id, old.comment_id, old.reporting_user_id,
    old.reason, old.explanation, old.reported_body,
    old.reported_edited_at, old.reported_version_number, old.created_at
  ) then
    raise exception 'Community report evidence is immutable';
  end if;
  if old.status <> 'pending'
    or new.status not in ('dismissed', 'actioned')
    or new.resolved_at is null
    or not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Invalid community report resolution';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_community_report_update()
from public, anon, authenticated;
create trigger enforce_community_report_update
before update on public.community_reports
for each row execute function private.enforce_community_report_update();

create or replace function private.enforce_community_read_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'read_at') is distinct from
     (to_jsonb(old) - 'read_at')
     or old.read_at is not null
     or new.read_at is null
     or new.user_id is distinct from (select auth.uid()) then
    raise exception 'Only the owner may mark an unread record read';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_community_read_transition()
from public, anon, authenticated;
create trigger enforce_community_moderation_notice_read
before update on public.community_moderation_notices
for each row execute function private.enforce_community_read_transition();
create trigger enforce_community_notification_read
before update on public.community_notifications
for each row execute function private.enforce_community_read_transition();

create or replace function private.prevent_community_hide_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Hide intent rows are inserted or deleted, never reassigned';
end;
$$;

revoke all on function private.prevent_community_hide_update()
from public, anon, authenticated;
create trigger prevent_community_hide_update
before update on public.community_hide_intents
for each row execute function private.prevent_community_hide_update();

create or replace function private.lock_community_user_pair(
  first_user_id uuid,
  second_user_id uuid
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'fanatical:community-pair:'
      || least(first_user_id::text, second_user_id::text)
      || ':'
      || greatest(first_user_id::text, second_user_id::text),
      0
    )
  );
$$;

revoke all on function private.lock_community_user_pair(uuid, uuid)
from public, anon, authenticated;

create or replace function private.community_users_are_separated(
  first_user_id uuid,
  second_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function private.community_users_are_separated(uuid, uuid)
from public, anon, authenticated;

-- Competition and Sport discussions are available to ordinary signed-in fans.
-- Team discussion bodies and mutations retain the existing FANbase rule that
-- the fan must follow that Team. A News classification alone grants no Team
-- FANbase access; the anonymous teaser remains count-only.
create or replace function private.community_context_is_accessible(
  fan_user_id uuid,
  context_kind_value text,
  context_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select context_kind_value <> 'team'
    or exists (
      select 1
      from public.user_followed_teams followed
      join public.catalog_teams context_team
        on context_team.id = context_uuid
      where followed.user_id = fan_user_id
        and (
          followed.team_id = context_team.team_id
          or (
            not exists (
              select 1
              from public.catalog_teams canonical_match
              where canonical_match.team_id = followed.team_id
            )
            and exists (
              select 1
              from public.catalog_team_identifiers identifier_match
              where identifier_match.identifier = followed.team_id
                and identifier_match.team_id = context_uuid
            )
            and 1 = (
              select count(distinct identifier_candidate.team_id)
              from public.catalog_team_identifiers identifier_candidate
              where identifier_candidate.identifier = followed.team_id
            )
          )
        )
    );
$$;

revoke all on function private.community_context_is_accessible(uuid, text, uuid)
from public, anon, authenticated;

create or replace function private.assert_community_fan(
  fan_user_id uuid,
  require_name boolean default true
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  fanatical_name_value text;
begin
  if fan_user_id is null or fan_user_id is distinct from (select auth.uid()) then
    raise exception 'Authentication as the acting fan is required';
  end if;

  select profile.handle
  into fanatical_name_value
  from public.profiles profile
  join private.fan_profile_population fan_profile
    on fan_profile.user_id = profile.user_id
  where profile.user_id = fan_user_id;

  if not found then
    raise exception 'An ordinary fan profile is required';
  end if;
  if require_name and fanatical_name_value = '' then
    raise exception 'Claim a Fanatical Name before posting';
  end if;
end;
$$;

revoke all on function private.assert_community_fan(uuid, boolean)
from public, anon, authenticated;

create or replace function private.community_active_suspension_end(
  fan_user_id uuid
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(restriction.ends_at)
  from public.community_posting_restrictions restriction
  where restriction.user_id = fan_user_id
    and restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp();
$$;

revoke all on function private.community_active_suspension_end(uuid)
from public, anon, authenticated;

create or replace function private.assert_community_participation_allowed(
  fan_user_id uuid,
  require_fanatical_name boolean
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  suspended_until timestamptz;
begin
  perform private.assert_community_fan(
    fan_user_id,
    require_fanatical_name
  );

  suspended_until := private.community_active_suspension_end(fan_user_id);

  if suspended_until is not null then
    raise exception 'Community participation is suspended until %', suspended_until;
  end if;
end;
$$;

revoke all on function private.assert_community_participation_allowed(uuid, boolean)
from public, anon, authenticated;

create or replace function private.assert_community_posting_allowed(
  fan_user_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_community_participation_allowed(fan_user_id, true);
end;
$$;

revoke all on function private.assert_community_posting_allowed(uuid)
from public, anon, authenticated;

create or replace function private.resolve_news_discussion_context(
  news_item_public_id_value text,
  origin_context_kind_value text default null,
  origin_context_public_id_value text default null
)
returns table (
  news_item_uuid uuid,
  news_item_public_id text,
  context_kind text,
  context_uuid uuid,
  context_public_id text,
  context_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  item_uuid uuid;
  context_record record;
  normalized_kind text := lower(nullif(btrim(origin_context_kind_value), ''));
  competition_count integer;
  sport_count integer;
begin
  select item.id
  into item_uuid
  from public.news_items item
  join public.news_item_versions item_version
    on item_version.news_item_id = item.id
   and item_version.is_current
   and item_version.publication_state = 'published'
   and item_version.publication_time <= statement_timestamp()
  where item.news_item_id = news_item_public_id_value;

  if item_uuid is null then
    return;
  end if;

  if normalized_kind is not null then
    if normalized_kind not in ('team', 'competition', 'sport')
      or nullif(btrim(origin_context_public_id_value), '') is null then
      return;
    end if;

    if normalized_kind = 'team' then
      select team.id, team.team_id as public_id, identity.display_name
      into context_record
      from public.news_item_classifications classification
      join public.news_item_classification_versions version
        on version.classification_id = classification.id
       and version.is_current
       and version.target_type = 'team'
      join public.catalog_teams team on team.id = version.team_id
      left join public.team_identity_versions identity
        on identity.team_id = team.id and identity.is_current
      where classification.news_item_id = item_uuid
        and team.id = public.resolve_catalog_team_id(
          origin_context_public_id_value
        )
      limit 1;
    elsif normalized_kind = 'competition' then
      select competition.id, competition.competition_id as public_id,
        identity.display_name
      into context_record
      from public.news_item_classifications classification
      join public.news_item_classification_versions version
        on version.classification_id = classification.id
       and version.is_current
       and version.target_type = 'competition'
      join public.catalog_competitions competition
        on competition.id = version.competition_id
      left join public.competition_identity_versions identity
        on identity.competition_id = competition.id and identity.is_current
      where classification.news_item_id = item_uuid
        and competition.competition_id = origin_context_public_id_value
      limit 1;
    else
      select sport.id, sport.sport_id as public_id, sport.display_name
      into context_record
      from public.news_item_classifications classification
      join public.news_item_classification_versions version
        on version.classification_id = classification.id
       and version.is_current
       and version.target_type = 'sport'
      join public.catalog_sports sport on sport.id = version.sport_id
      where classification.news_item_id = item_uuid
        and sport.sport_id = origin_context_public_id_value
      limit 1;
    end if;

    if context_record.id is null then
      return;
    end if;

    return query select
      item_uuid,
      news_item_public_id_value,
      normalized_kind,
      context_record.id,
      context_record.public_id,
      coalesce(context_record.display_name, context_record.public_id);
    return;
  end if;

  select count(distinct version.competition_id)
  into competition_count
  from public.news_item_classifications classification
  join public.news_item_classification_versions version
    on version.classification_id = classification.id
   and version.is_current
   and version.target_type = 'competition'
  where classification.news_item_id = item_uuid;

  if competition_count = 1 then
    select competition.id, competition.competition_id as public_id,
      identity.display_name
    into context_record
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id
     and version.is_current
     and version.target_type = 'competition'
    join public.catalog_competitions competition
      on competition.id = version.competition_id
    left join public.competition_identity_versions identity
      on identity.competition_id = competition.id and identity.is_current
    where classification.news_item_id = item_uuid
    limit 1;

    return query select
      item_uuid,
      news_item_public_id_value,
      'competition'::text,
      context_record.id,
      context_record.public_id,
      coalesce(context_record.display_name, context_record.public_id);
    return;
  end if;

  select count(distinct version.sport_id)
  into sport_count
  from public.news_item_classifications classification
  join public.news_item_classification_versions version
    on version.classification_id = classification.id
   and version.is_current
   and version.target_type = 'sport'
  where classification.news_item_id = item_uuid;

  if sport_count = 1 then
    select sport.id, sport.sport_id as public_id, sport.display_name
    into context_record
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id
     and version.is_current
     and version.target_type = 'sport'
    join public.catalog_sports sport on sport.id = version.sport_id
    where classification.news_item_id = item_uuid
    limit 1;

    return query select
      item_uuid,
      news_item_public_id_value,
      'sport'::text,
      context_record.id,
      context_record.public_id,
      context_record.display_name;
  end if;
end;
$$;

revoke all on function private.resolve_news_discussion_context(text, text, text)
from public, anon, authenticated;

create or replace function public.get_news_discussion_teaser(
  news_item_public_id_value text,
  origin_context_kind_value text default null,
  origin_context_public_id_value text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
    'context_id', resolved.context_public_id,
    'context_name', resolved.context_display_name,
    'discussion_id', discussion_record.discussion_id,
    'comment_count', coalesce(discussion_record.comment_count, 0)
  );
end;
$$;

revoke all on function public.get_news_discussion_teaser(text, text, text)
from public, anon, authenticated;
grant execute on function public.get_news_discussion_teaser(text, text, text)
to anon, authenticated;

create or replace function private.get_or_create_news_discussion(
  news_item_public_id_value text,
  origin_context_kind_value text,
  origin_context_public_id_value text,
  creator_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function private.get_or_create_news_discussion(
  text, text, text, uuid
) from public, anon, authenticated;

create or replace function private.community_discussion_context_is_current(
  discussion_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.community_discussions discussion
    join public.news_item_classifications classification
      on classification.news_item_id = discussion.news_item_id
    join public.news_item_classification_versions version
      on version.classification_id = classification.id
     and version.is_current
    where discussion.id = discussion_uuid
      and (
        (discussion.context_kind = 'team'
          and version.target_type = 'team'
          and version.team_id = discussion.team_id)
        or (discussion.context_kind = 'competition'
          and version.target_type = 'competition'
          and version.competition_id = discussion.competition_id)
        or (discussion.context_kind = 'sport'
          and version.target_type = 'sport'
          and version.sport_id = discussion.sport_id)
      )
  );
$$;

revoke all on function private.community_discussion_context_is_current(uuid)
from public, anon, authenticated;

create or replace function private.insert_community_notification(
  recipient_user_id uuid,
  notification_type_value text,
  actor_user_id_value uuid,
  reply_comment_id_value uuid,
  requester_relation_id_value uuid,
  metadata_value jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function private.insert_community_notification(
  uuid, text, uuid, uuid, uuid, jsonb
) from public, anon, authenticated;

create or replace function private.insert_community_comment(
  discussion_uuid uuid,
  parent_comment_uuid uuid,
  body_value text,
  author_user_id_value uuid
)
returns table (comment_uuid uuid, comment_public_id text)
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function private.insert_community_comment(uuid, uuid, text, uuid)
from public, anon, authenticated;

create or replace function public.post_news_discussion_comment(
  news_item_public_id_value text,
  context_kind_value text,
  context_public_id_value text,
  body_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.post_news_discussion_comment(text, text, text, text)
from public, anon, authenticated;
grant execute on function public.post_news_discussion_comment(text, text, text, text)
to authenticated;

-- A stable discussion link can accept another root while its exact
-- Item/context classification remains current. Corrected-away discussions are
-- preserved for reading and owner lifecycle actions, but not new interaction.
create or replace function public.post_existing_community_discussion_comment(
  discussion_public_id_value text,
  body_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.post_existing_community_discussion_comment(text, text)
from public, anon, authenticated;
grant execute on function public.post_existing_community_discussion_comment(text, text)
to authenticated;

create or replace function public.reply_to_community_comment(
  discussion_public_id_value text,
  parent_comment_public_id_value text,
  body_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.reply_to_community_comment(text, text, text)
from public, anon, authenticated;
grant execute on function public.reply_to_community_comment(text, text, text)
to authenticated;

create or replace function public.edit_my_community_comment(
  comment_public_id_value text,
  body_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.edit_my_community_comment(text, text)
from public, anon, authenticated;
grant execute on function public.edit_my_community_comment(text, text)
to authenticated;

create or replace function public.delete_my_community_comment(
  comment_public_id_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.delete_my_community_comment(text)
from public, anon, authenticated;
grant execute on function public.delete_my_community_comment(text)
to authenticated;

create or replace function public.get_community_discussion(
  discussion_public_id_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

  select max(restriction.ends_at)
  into restricted_until
  from public.community_posting_restrictions restriction
  where restriction.user_id = viewer_id
    and restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp();

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
          when private.community_users_are_separated(
            viewer_id,
            comment.author_user_id
          ) then 'Content unavailable'
          else comment.body
        end,
        'status', case
          when comment.status = 'deleted' then 'deleted'
          when comment.status = 'moderated' then 'moderated'
          when private.community_users_are_separated(
            viewer_id,
            comment.author_user_id
          ) then 'unavailable'
          else 'active'
        end,
        'fanatical_name', case
          when comment.status <> 'active'
            or private.community_users_are_separated(
              viewer_id,
              comment.author_user_id
            ) then null
          else author_profile.handle
        end,
        'avatar', case
          when comment.status <> 'active'
            or private.community_users_are_separated(
              viewer_id,
              comment.author_user_id
            ) then null
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
          and not private.community_users_are_separated(
            viewer_id,
            comment.author_user_id
          ),
        'can_edit', comment.status = 'active'
          and comment.author_user_id = viewer_id
          and statement_timestamp() <= comment.created_at + interval '7 days',
        'can_delete', comment.status = 'active'
          and comment.author_user_id = viewer_id,
        'can_report', comment.status = 'active'
          and comment.author_user_id <> viewer_id
          and not private.community_users_are_separated(
            viewer_id,
            comment.author_user_id
          ),
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
  where comment.discussion_id = discussion_record.id;

  return jsonb_build_object(
    'discussion_id', discussion_record.discussion_id,
    'news_item_id', discussion_record.news_item_id,
    'context_kind', discussion_record.context_kind,
    'context_id', discussion_record.context_public_id,
    'context_name', discussion_record.context_display_name,
    'comment_count', discussion_record.comment_count,
    'context_is_current', discussion_record.context_is_current,
    'viewer_has_fanatical_name', viewer_handle <> '',
    'posting_restricted_until', restricted_until,
    'comments', comments_payload
  );
end;
$$;

revoke all on function public.get_community_discussion(text)
from public, anon, authenticated;
grant execute on function public.get_community_discussion(text)
to authenticated;

create or replace function public.hide_community_user(
  fanatical_name_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.hide_community_user(text)
from public, anon, authenticated;
grant execute on function public.hide_community_user(text) to authenticated;

-- A comment ID is the only fan-facing durable reference needed to hide its
-- author. This remains usable if that author releases their Fanatical Name
-- between the discussion read and the Hide action.
create or replace function public.hide_community_comment_author(
  comment_public_id_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.hide_community_comment_author(text)
from public, anon, authenticated;
grant execute on function public.hide_community_comment_author(text)
to authenticated;

create or replace function public.unhide_community_user(
  fanatical_name_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.unhide_community_user(text)
from public, anon, authenticated;
grant execute on function public.unhide_community_user(text) to authenticated;

create or replace function public.unhide_community_intent(
  hide_intent_public_id_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.unhide_community_intent(text)
from public, anon, authenticated;
grant execute on function public.unhide_community_intent(text)
to authenticated;

create or replace function public.get_my_hidden_fans()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.get_my_hidden_fans()
from public, anon, authenticated;
grant execute on function public.get_my_hidden_fans() to authenticated;

-- Apply reciprocal Hide to full profile viewing and avatar attribution without
-- changing the Private-profile attribution payload itself.
create or replace function private.can_view_profile(profile_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1 from private.fan_profile_population viewer
      where viewer.user_id = (select auth.uid())
    )
    and exists (
      select 1
      from public.profiles profile
      join private.fan_profile_population fan_profile
        on fan_profile.user_id = profile.user_id
      where profile.user_id = profile_user_id
        and (
          profile.user_id = (select auth.uid())
          or profile.visibility = 'members_visible'
        )
        and not private.community_users_are_separated(
          (select auth.uid()),
          profile.user_id
        )
    );
$$;

revoke all on function private.can_view_profile(uuid)
from public, anon, authenticated;
grant execute on function private.can_view_profile(uuid) to authenticated;

create or replace function private.profile_avatar_path_is_attributable(
  object_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1 from private.fan_profile_population viewer
      where viewer.user_id = (select auth.uid())
    )
    and exists (
      select 1
      from public.profiles profile
      join private.fan_profile_population fan_profile
        on fan_profile.user_id = profile.user_id
      join public.profile_photos photo
        on photo.id = profile.active_profile_photo_id
       and photo.user_id = profile.user_id
      where photo.display_path = object_name
        and private.profile_media_path_belongs_to_user(
          profile.user_id,
          object_name
        )
        and private.profile_avatar_path_is_fan_safe(
          profile.user_id,
          object_name
        )
        and not private.community_users_are_separated(
          (select auth.uid()),
          profile.user_id
        )
    );
$$;

revoke all on function private.profile_avatar_path_is_attributable(text)
from public, anon, authenticated;

create or replace function public.get_member_profile_by_fanatical_name(
  fanatical_name_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_user_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required';
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
$$;

revoke all on function public.get_member_profile_by_fanatical_name(text)
from public, anon, authenticated;
grant execute on function public.get_member_profile_by_fanatical_name(text)
to authenticated;

create or replace function public.report_community_comment(
  comment_public_id_value text,
  reason_value text,
  explanation_value text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  comment_record record;
  inserted_report_id text;
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
  returning report_id into inserted_report_id;

  return jsonb_build_object('report_id', inserted_report_id);
end;
$$;

revoke all on function public.report_community_comment(text, text, text)
from public, anon, authenticated;
grant execute on function public.report_community_comment(text, text, text)
to authenticated;

create or replace function public.get_community_moderation_queue()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.get_community_moderation_queue()
from public, anon, authenticated;
grant execute on function public.get_community_moderation_queue()
to authenticated;

create or replace function public.admin_moderate_community_report(
  report_public_id_value text,
  action_value text,
  reason_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
        coalesce(max(restriction.ends_at), statement_timestamp())
      )
    into restriction_ordinal, restriction_start
    from public.community_posting_restrictions restriction
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
$$;

revoke all on function public.admin_moderate_community_report(text, text, text)
from public, anon, authenticated;
grant execute on function public.admin_moderate_community_report(text, text, text)
to authenticated;

create or replace function public.get_my_community_moderation_notices()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.get_my_community_moderation_notices()
from public, anon, authenticated;
grant execute on function public.get_my_community_moderation_notices()
to authenticated;

create or replace function public.mark_my_community_moderation_notices_read(
  notice_public_ids text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.mark_my_community_moderation_notices_read(text[])
from public, anon, authenticated;
grant execute on function public.mark_my_community_moderation_notices_read(text[])
to authenticated;

create or replace function public.get_my_community_notifications()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.get_my_community_notifications()
from public, anon, authenticated;
grant execute on function public.get_my_community_notifications()
to authenticated;

create or replace function public.mark_my_community_notifications_read(
  notification_public_ids text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.mark_my_community_notifications_read(text[])
from public, anon, authenticated;
grant execute on function public.mark_my_community_notifications_read(text[])
to authenticated;

comment on function private.community_users_are_separated(uuid, uuid) is
  'Single reciprocal-Hide predicate: either directed owner intent separates both fans.';
comment on table public.community_comment_versions is
  'Append-only internal comment history. Phase 5A exposes no public revision viewer.';
comment on table public.community_notifications is
  'Small typed social inbox for direct replies and final Request outcomes only.';

select private.assert_community_domain_mutation_registry();
