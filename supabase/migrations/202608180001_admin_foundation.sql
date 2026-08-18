-- FANatical authenticated staff/admin foundation. This table is intentionally
-- managed only through trusted database/service-role operations. Browser
-- clients may read only their own active assignment through RLS.

create table if not exists public.staff_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'staff', 'venue_admin', 'content_admin', 'moderator')),
  permissions text[] not null default array[]::text[],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.staff_roles is
  'Trusted FANatical staff authorization assignments. Never writable from a browser client.';
comment on column public.staff_roles.permissions is
  'Optional granular permissions for future admin tools; role remains the primary authorization tier.';

drop trigger if exists staff_roles_set_updated_at on public.staff_roles;
create trigger staff_roles_set_updated_at
before update on public.staff_roles
for each row execute function public.set_updated_at();

alter table public.staff_roles enable row level security;

create policy "Staff read their own active assignment"
on public.staff_roles for select to authenticated
using (auth.uid() = user_id and is_active);

revoke all on table public.staff_roles from public, anon, authenticated;
grant select on table public.staff_roles to authenticated;

create or replace function public.has_staff_access(
  required_roles text[] default null,
  required_permission text default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff_roles assignment
    where assignment.user_id = auth.uid()
      and assignment.is_active
      and (required_roles is null or assignment.role = any(required_roles))
      and (required_permission is null or required_permission = any(assignment.permissions))
  );
$$;

comment on function public.has_staff_access(text[], text) is
  'Backend authorization predicate for future admin RLS policies and RPC functions.';

revoke all on function public.has_staff_access(text[], text) from public, anon;
grant execute on function public.has_staff_access(text[], text) to authenticated;
