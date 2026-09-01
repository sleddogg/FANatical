-- Phase 5A Add-to-Feed Requests. Request resolution is intentionally separate
-- from News identity-decision actions and never auto-Follows.

-- Extend the existing News registry before creating request-domain tables.
alter function private.news_domain_mutation_registry()
rename to news_domain_mutation_registry_through_phase4;

create or replace function private.news_domain_mutation_registry()
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
  select * from private.news_domain_mutation_registry_through_phase4()
  union all
  select *
  from (values
    ('public', 'news_follow_request_targets', 'governed', array['public.submit_news_follow_request(text,text)','public.admin_resolve_news_follow_request(text,text,text,text,text)'], 'Shared Request targets are created by fan intake and transition once through request-domain staff resolution.'),
    ('public', 'news_follow_request_resolution_decisions', 'governed', array['public.admin_resolve_news_follow_request(text,text,text,text,text)'], 'Every terminal Request target transition has an append-only request-domain decision; this is not a News identity decision action.'),
    ('public', 'user_news_follow_requests', 'governed', array['public.submit_news_follow_request(text,text)'], 'Each fan owns one immutable requester/evidence relationship to a shared target.')
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$$;

revoke all on function private.news_domain_mutation_registry_through_phase4()
from public, anon, authenticated;
revoke all on function private.news_domain_mutation_registry()
from public, anon, authenticated;

create table public.news_follow_request_targets (
  id uuid primary key default gen_random_uuid(),
  request_target_id text not null unique default (
    'news-request-target-' || replace(gen_random_uuid()::text, '-', '')
  ) check (request_target_id ~ '^news-request-target-[0-9a-f]{32}$'),
  input_kind text not null check (input_kind in ('url', 'name')),
  normalized_input text not null check (length(normalized_input) > 0),
  display_input text not null check (length(btrim(display_input)) > 0),
  resolution_state text not null default 'pending'
    check (resolution_state in ('pending', 'available', 'unable')),
  resolved_target_type text check (
    resolved_target_type is null
    or resolved_target_type in ('author', 'organization', 'show')
  ),
  resolved_person_id uuid references public.catalog_people(id),
  resolved_organizational_contributor_id uuid
    references public.news_organizational_contributors(id),
  resolved_show_id uuid references public.podcast_shows(id),
  staff_reason text,
  created_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  resolved_by_user_id uuid references auth.users(id) on delete restrict,
  unique (input_kind, normalized_input),
  check (
    (
      resolution_state = 'pending'
      and resolved_target_type is null
      and num_nonnulls(
        resolved_person_id,
        resolved_organizational_contributor_id,
        resolved_show_id
      ) = 0
      and staff_reason is null
      and resolved_at is null
      and resolved_by_user_id is null
    )
    or (
      resolution_state = 'available'
      and staff_reason is not null
      and length(btrim(staff_reason)) > 0
      and resolved_at is not null
      and resolved_by_user_id is not null
      and num_nonnulls(
        resolved_person_id,
        resolved_organizational_contributor_id,
        resolved_show_id
      ) = 1
      and (
        (resolved_target_type = 'author' and resolved_person_id is not null)
        or (
          resolved_target_type = 'organization'
          and resolved_organizational_contributor_id is not null
        )
        or (resolved_target_type = 'show' and resolved_show_id is not null)
      )
    )
    or (
      resolution_state = 'unable'
      and resolved_target_type is null
      and num_nonnulls(
        resolved_person_id,
        resolved_organizational_contributor_id,
        resolved_show_id
      ) = 0
      and staff_reason is not null
      and length(btrim(staff_reason)) > 0
      and resolved_at is not null
      and resolved_by_user_id is not null
    )
  )
);

create index news_follow_request_targets_state_created_idx
on public.news_follow_request_targets(resolution_state, created_at, id);
create index news_follow_request_targets_person_fk_idx
on public.news_follow_request_targets(resolved_person_id)
where resolved_person_id is not null;
create index news_follow_request_targets_organization_fk_idx
on public.news_follow_request_targets(resolved_organizational_contributor_id)
where resolved_organizational_contributor_id is not null;
create index news_follow_request_targets_show_fk_idx
on public.news_follow_request_targets(resolved_show_id)
where resolved_show_id is not null;

create table public.news_follow_request_resolution_decisions (
  id uuid primary key default gen_random_uuid(),
  request_target_id uuid not null unique
    references public.news_follow_request_targets(id) on delete restrict,
  outcome text not null check (outcome in ('available', 'unable')),
  resolved_target_type text check (
    resolved_target_type is null
    or resolved_target_type in ('author', 'organization', 'show')
  ),
  resolved_person_id uuid references public.catalog_people(id),
  resolved_organizational_contributor_id uuid
    references public.news_organizational_contributors(id),
  resolved_show_id uuid references public.podcast_shows(id),
  reason text not null check (length(btrim(reason)) > 0),
  decided_by_user_id uuid not null references auth.users(id) on delete restrict,
  decided_at timestamptz not null default statement_timestamp(),
  check (
    (
      outcome = 'available'
      and num_nonnulls(
        resolved_person_id,
        resolved_organizational_contributor_id,
        resolved_show_id
      ) = 1
      and (
        (resolved_target_type = 'author' and resolved_person_id is not null)
        or (
          resolved_target_type = 'organization'
          and resolved_organizational_contributor_id is not null
        )
        or (resolved_target_type = 'show' and resolved_show_id is not null)
      )
    )
    or (
      outcome = 'unable'
      and resolved_target_type is null
      and num_nonnulls(
        resolved_person_id,
        resolved_organizational_contributor_id,
        resolved_show_id
      ) = 0
    )
  )
);

create index news_follow_request_decisions_staff_idx
on public.news_follow_request_resolution_decisions(
  decided_by_user_id,
  decided_at desc
);

create table public.user_news_follow_requests (
  id uuid primary key default gen_random_uuid(),
  request_id text not null unique default (
    'user-news-request-' || replace(gen_random_uuid()::text, '-', '')
  ) check (request_id ~ '^user-news-request-[0-9a-f]{32}$'),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  request_target_id uuid not null
    references public.news_follow_request_targets(id) on delete restrict,
  input_kind text not null check (input_kind in ('url', 'name')),
  raw_input text not null check (length(btrim(raw_input)) > 0),
  created_at timestamptz not null default statement_timestamp(),
  unique (user_id, request_target_id)
);

create index user_news_follow_requests_target_idx
on public.user_news_follow_requests(request_target_id, created_at, id);
create index user_news_follow_requests_user_created_idx
on public.user_news_follow_requests(user_id, created_at desc, id);

alter table public.community_notifications
  add constraint community_notifications_requester_relation_fk
  foreign key (requester_relation_id)
  references public.user_news_follow_requests(id) on delete restrict;

alter table public.news_follow_request_targets enable row level security;
alter table public.news_follow_request_resolution_decisions enable row level security;
alter table public.user_news_follow_requests enable row level security;

revoke all on table public.news_follow_request_targets,
  public.news_follow_request_resolution_decisions,
  public.user_news_follow_requests
from public, anon, authenticated;

create or replace function private.protect_news_request_history_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% Request history is append-only', tg_table_name;
end;
$$;

revoke all on function private.protect_news_request_history_row()
from public, anon, authenticated;

create trigger protect_news_request_resolution_decisions
before update or delete on public.news_follow_request_resolution_decisions
for each row execute function private.protect_news_request_history_row();
create trigger protect_user_news_follow_requests
before update or delete on public.user_news_follow_requests
for each row execute function private.protect_news_request_history_row();

create or replace function private.enforce_news_request_target_resolution()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(
    new.id, new.request_target_id, new.input_kind, new.normalized_input,
    new.display_input, new.created_at
  ) is distinct from row(
    old.id, old.request_target_id, old.input_kind, old.normalized_input,
    old.display_input, old.created_at
  )
    or old.resolution_state <> 'pending'
    or new.resolution_state not in ('available', 'unable')
    or not public.has_staff_access(
      array['admin', 'staff', 'content_admin']::text[],
      null
    ) then
    raise exception 'Invalid News Request target transition';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_news_request_target_resolution()
from public, anon, authenticated;
create trigger enforce_news_request_target_resolution
before update on public.news_follow_request_targets
for each row execute function private.enforce_news_request_target_resolution();

create or replace function private.news_request_notification_metadata(
  request_record public.user_news_follow_requests,
  target_record public.news_follow_request_targets
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'request_id', request_record.request_id,
    'state', case target_record.resolution_state
      when 'available' then 'Available'
      when 'unable' then 'Unable to add'
      else 'Pending' end,
    'target_type', target_record.resolved_target_type,
    'target_id', case target_record.resolved_target_type
      when 'author' then (
        select profile.author_id
        from public.news_author_profiles profile
        where profile.person_id = private.try_resolve_news_canonical_person(
          target_record.resolved_person_id
        )
      )
      when 'organization' then (
        select contributor.contributor_id
        from public.news_organizational_contributors contributor
        where contributor.id =
          target_record.resolved_organizational_contributor_id
      )
      when 'show' then (
        select show_record.show_id
        from public.podcast_shows show_record
        where show_record.id = target_record.resolved_show_id
      )
    end,
    'reason', case when target_record.resolution_state = 'unable'
      then target_record.staff_reason else null end
  ));
$$;

revoke all on function private.news_request_notification_metadata(
  public.user_news_follow_requests,
  public.news_follow_request_targets
) from public, anon, authenticated;

create or replace function public.submit_news_follow_request(
  input_kind_value text,
  raw_input_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.submit_news_follow_request(text, text)
from public, anon, authenticated;
grant execute on function public.submit_news_follow_request(text, text)
to authenticated;

create or replace function public.admin_resolve_news_follow_request(
  request_target_public_id_value text,
  outcome_value text,
  follow_target_type_value text,
  follow_target_public_id_value text,
  reason_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
    array['admin', 'staff', 'content_admin']::text[],
    null
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
$$;

revoke all on function public.admin_resolve_news_follow_request(
  text, text, text, text, text
) from public, anon, authenticated;
grant execute on function public.admin_resolve_news_follow_request(
  text, text, text, text, text
) to authenticated;

create or replace function public.get_my_news_follow_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.get_my_news_follow_requests()
from public, anon, authenticated;
grant execute on function public.get_my_news_follow_requests()
to authenticated;

create or replace function public.get_news_follow_request_queue()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  queue_payload jsonb;
begin
  if not public.has_staff_access(
    array['admin', 'staff', 'content_admin']::text[],
    null
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
$$;

revoke all on function public.get_news_follow_request_queue()
from public, anon, authenticated;
grant execute on function public.get_news_follow_request_queue()
to authenticated;

comment on table public.news_follow_request_targets is
  'Shared conservative request candidates. Terminal request-domain outcomes never reopen and do not create News identity-decision actions.';
comment on table public.user_news_follow_requests is
  'Immutable per-fan raw request evidence and relationship to a shared target.';
comment on function public.get_my_news_follow_requests() is
  'Owner-safe Requests read. Follow is offered only when the resolved target is currently followable and is never automatic.';

select private.assert_news_domain_mutation_registry();
select private.assert_community_domain_mutation_registry();
