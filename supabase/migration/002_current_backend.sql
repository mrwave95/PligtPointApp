-- ============================================================
-- PligtPointApp
-- Current backend after 001_initial_schema.sql
--
-- IMPORTANT:
-- This file documents/recreates backend changes that were
-- already applied MANUALLY to the current Supabase project.
--
-- DO NOT run this file against the current live project.
--
-- Use it only when reconstructing a new database after first
-- applying 001_initial_schema.sql, or as architecture/reference
-- documentation.
-- ============================================================


-- ============================================================
-- 1. PROFILES
-- ============================================================

alter table public.profiles
add column if not exists color text;

alter table public.profiles
drop constraint if exists profiles_color_check;

alter table public.profiles
add constraint profiles_color_check
check (
  color is null
  or color ~ '^#[0-9A-Fa-f]{6}$'
);


alter table public.profiles
add column if not exists is_admin boolean
not null
default false;


comment on column public.profiles.is_admin is
'True only for household administrators. Browser clients must not be able to modify this value directly.';



-- ============================================================
-- 2. EXPANDED CHORE MODEL
--
-- active:
--   Administrator enable/disable switch.
--
-- completion_limit:
--   Number of household completions allowed in one cycle.
--   NULL means unlimited/repeatable.
--
-- cooldown_days:
--   Whole elapsed 24-hour periods before a completed cycle
--   becomes available again.
--   NULL means no automatic recurrence.
--
-- available_from:
--   Start of the current/next cycle and earliest time the chore
--   may currently be completed.
--
-- Supported combinations:
--
-- One-off:
--   completion_limit = 1
--   cooldown_days = NULL
--
-- Elapsed recurrence:
--   completion_limit = 1
--   cooldown_days = N
--
-- Counter + elapsed:
--   completion_limit = N
--   cooldown_days = N
--
-- Unlimited repeatable:
--   completion_limit = NULL
--   cooldown_days = NULL
-- ============================================================

alter table public.chores
add column if not exists description text;


alter table public.chores
add column if not exists completion_limit integer
default 1;


alter table public.chores
add column if not exists cooldown_days integer;


alter table public.chores
add column if not exists available_from timestamptz
not null
default now();


alter table public.chores
add column if not exists updated_at timestamptz
not null
default now();


-- Remove obsolete intermediate minute-based cooldown storage
-- if reconstructing from an intermediate schema.

alter table public.chores
drop constraint if exists chores_cooldown_minutes_check;

alter table public.chores
drop constraint if exists chores_cooldown_requires_limit_check;

alter table public.chores
drop column if exists cooldown_minutes;


-- Data integrity.

alter table public.chores
drop constraint if exists chores_estimated_minutes_check;

alter table public.chores
add constraint chores_estimated_minutes_check
check (
  estimated_minutes is null
  or estimated_minutes > 0
);


alter table public.chores
drop constraint if exists chores_completion_limit_check;

alter table public.chores
add constraint chores_completion_limit_check
check (
  completion_limit is null
  or completion_limit > 0
);


alter table public.chores
drop constraint if exists chores_cooldown_days_check;

alter table public.chores
add constraint chores_cooldown_days_check
check (
  cooldown_days is null
  or cooldown_days > 0
);


alter table public.chores
drop constraint if exists chores_cooldown_days_requires_limit_check;

alter table public.chores
add constraint chores_cooldown_days_requires_limit_check
check (
  cooldown_days is null
  or completion_limit is not null
);


comment on column public.chores.active is
'Administrator switch. False means the chore is disabled entirely.';

comment on column public.chores.completion_limit is
'Maximum household completions in the current cycle. NULL means unlimited.';

comment on column public.chores.cooldown_days is
'Whole elapsed 24-hour periods before a completed cycle becomes available again. NULL means manual reset/no automatic recurrence.';

comment on column public.chores.available_from is
'Beginning of the current or next chore cycle and earliest time the chore is available.';



-- ============================================================
-- 3. REDEMPTIONS
--
-- Cashing in points does NOT reduce lifetime leaderboard score.
--
-- Lifetime score:
--   SUM(completions.points_awarded)
--
-- Available/spendable balance:
--   earned - redeemed
-- ============================================================

create table if not exists public.redemptions (
  id bigint generated always as identity
    primary key,

  user_id uuid not null
    references auth.users(id),

  points_redeemed integer not null
    check (points_redeemed > 0),

  redeemed_at timestamptz not null
    default now()
);



-- ============================================================
-- 4. TAGS
-- ============================================================

create table if not exists public.tags (
  id bigint generated always as identity
    primary key,

  name text not null unique,

  color text,

  created_at timestamptz not null
    default now(),

  constraint tags_name_not_blank
    check (length(trim(name)) > 0),

  constraint tags_color_check
    check (
      color is null
      or color ~ '^#[0-9A-Fa-f]{6}$'
    )
);


create table if not exists public.chore_tags (
  chore_id bigint not null
    references public.chores(id)
    on delete cascade,

  tag_id bigint not null
    references public.tags(id)
    on delete cascade,

  primary key (chore_id, tag_id)
);


-- Prevent Kitchen / kitchen / KITCHEN from becoming separate
-- tags through the normal admin API.

create unique index if not exists tags_name_lower_unique
on public.tags (lower(name));



-- ============================================================
-- 5. COMPLETION INDEX
-- ============================================================

create index if not exists completions_chore_completed_at_idx
on public.completions (chore_id, completed_at);



-- ============================================================
-- 6. ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles
enable row level security;

alter table public.chores
enable row level security;

alter table public.completions
enable row level security;

alter table public.redemptions
enable row level security;

alter table public.tags
enable row level security;

alter table public.chore_tags
enable row level security;



-- ============================================================
-- 7. TABLE PRIVILEGES
--
-- Browser/API clients receive READ access only.
--
-- All privileged writes happen through narrowly scoped
-- SECURITY DEFINER RPC functions.
-- ============================================================

revoke all
on table
  public.profiles,
  public.chores,
  public.completions,
  public.redemptions,
  public.tags,
  public.chore_tags
from public, anon, authenticated;


grant select
on table
  public.profiles,
  public.chores,
  public.completions,
  public.redemptions,
  public.tags,
  public.chore_tags
to authenticated;



-- ============================================================
-- 8. READ POLICIES FOR NEW TABLES
--
-- Policies for profiles / chores / completions originate in
-- 001_initial_schema.sql.
-- ============================================================

drop policy if exists
  "Authenticated users can read redemptions"
on public.redemptions;

create policy
  "Authenticated users can read redemptions"
on public.redemptions
for select
to authenticated
using (true);


drop policy if exists
  "Authenticated users can read tags"
on public.tags;

create policy
  "Authenticated users can read tags"
on public.tags
for select
to authenticated
using (true);


drop policy if exists
  "Authenticated users can read chore tags"
on public.chore_tags;

create policy
  "Authenticated users can read chore tags"
on public.chore_tags
for select
to authenticated
using (true);



-- ============================================================
-- 9. PROFILE COLOR
--
-- Users may change only their own profile color through this
-- RPC. They still receive no direct UPDATE permission on
-- public.profiles.
-- ============================================================

create or replace function public.set_profile_color(
  p_color text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'You must be signed in';
  end if;


  if p_color is null
     or p_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'Color must be a six-digit hex color';
  end if;


  update public.profiles
  set color = p_color
  where id = v_user_id;


  if not found then
    raise exception 'Profile does not exist';
  end if;

end;
$$;


revoke execute
on function public.set_profile_color(text)
from public, anon, authenticated;

grant execute
on function public.set_profile_color(text)
to authenticated;



-- ============================================================
-- 10. COMPLETE CHORE
--
-- Browser supplies ONLY:
--
--   chore_id
--
-- PostgreSQL determines:
--
--   authenticated user
--   trusted point value
--   cycle progress
--   availability
--   completion timestamp
--   next cooldown state
--
-- A row lock serializes simultaneous completion attempts.
-- ============================================================

create or replace function public.complete_chore(
  p_chore_id bigint
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;

  v_points integer;
  v_active boolean;
  v_completion_limit integer;
  v_cooldown_days integer;
  v_available_from timestamptz;

  v_progress integer;
  v_completion_id bigint;

  v_now timestamptz := now();
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'You must be signed in';
  end if;


  -- Lock chore state so simultaneous completions are serialized.
  select
    c.points,
    c.active,
    c.completion_limit,
    c.cooldown_days,
    c.available_from
  into
    v_points,
    v_active,
    v_completion_limit,
    v_cooldown_days,
    v_available_from
  from public.chores as c
  where c.id = p_chore_id
  for update;


  if not found then
    raise exception 'Chore does not exist';
  end if;


  if v_active = false then
    raise exception 'Chore is disabled';
  end if;


  if v_available_from > v_now then
    raise exception 'Chore is not available yet';
  end if;


  -- Count completions belonging to the current cycle.
  if v_completion_limit is not null then

    select count(*)::integer
    into v_progress
    from public.completions as co
    where co.chore_id = p_chore_id
      and co.completed_at >= v_available_from;


    if v_progress >= v_completion_limit then
      raise exception 'Chore completion limit has been reached';
    end if;

  else

    -- Unlimited repeatable chore.
    v_progress := 0;

  end if;


  -- Trusted completion record.
  insert into public.completions (
    chore_id,
    user_id,
    points_awarded
  )
  values (
    p_chore_id,
    v_user_id,
    v_points
  )
  returning id into v_completion_id;


  -- If the current cycle has reached its limit:
  if v_completion_limit is not null
     and (v_progress + 1) >= v_completion_limit then


    -- Automatic elapsed recurrence.
    if v_cooldown_days is not null then

      update public.chores
      set
        available_from =
          v_now
          + (
              (v_cooldown_days::bigint * 86400)
              * interval '1 second'
            ),
        updated_at = v_now
      where id = p_chore_id;


    -- No cooldown means manual reset / one-off.
    else

      update public.chores
      set
        active = false,
        updated_at = v_now
      where id = p_chore_id;

    end if;

  end if;


  return v_completion_id;

end;
$$;


revoke execute
on function public.complete_chore(bigint)
from public, anon, authenticated;

grant execute
on function public.complete_chore(bigint)
to authenticated;



-- ============================================================
-- 11. LIST AVAILABLE CHORES
--
-- Backend is authoritative for chore availability.
--
-- The frontend must not recreate availability rules itself.
-- ============================================================

drop function if exists public.list_available_chores();


create function public.list_available_chores()
returns table (
  id bigint,
  name text,
  description text,
  estimated_minutes integer,
  points integer,
  completion_limit integer,
  progress_count integer,
  cooldown_days integer,
  available_from timestamptz,
  tags text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    c.name,
    c.description,
    c.estimated_minutes,
    c.points,
    c.completion_limit,

    (
      select count(*)::integer
      from public.completions as co
      where co.chore_id = c.id
        and co.completed_at >= c.available_from
    ) as progress_count,

    c.cooldown_days,
    c.available_from,

    coalesce(
      (
        select array_agg(t.name order by t.name)
        from public.chore_tags as ct
        join public.tags as t
          on t.id = ct.tag_id
        where ct.chore_id = c.id
      ),
      array[]::text[]
    ) as tags

  from public.chores as c

  where auth.uid() is not null
    and c.active = true
    and c.available_from <= now()

    and (
      c.completion_limit is null

      or

      (
        select count(*)
        from public.completions as co
        where co.chore_id = c.id
          and co.completed_at >= c.available_from
      ) < c.completion_limit
    )

  order by c.name;
$$;


revoke execute
on function public.list_available_chores()
from public, anon, authenticated;

grant execute
on function public.list_available_chores()
to authenticated;



-- ============================================================
-- 12. PARTIAL CASH-IN
--
-- The frontend chooses a requested whole-number amount.
--
-- Supabase independently calculates the user's actual balance
-- and rejects overspending.
--
-- The profile row is locked so simultaneous cash-in requests
-- cannot spend the same available points twice.
-- ============================================================

-- Remove obsolete no-argument "cash in everything" function.
drop function if exists public.cash_in_points();


create or replace function public.cash_in_points(
  p_points integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_earned integer;
  v_redeemed integer;
  v_available integer;
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'You must be signed in';
  end if;


  if p_points is null
     or p_points <= 0 then
    raise exception 'Cash-in amount must be greater than zero';
  end if;


  -- Serialize cash-in attempts for this user.
  perform 1
  from public.profiles
  where id = v_user_id
  for update;


  if not found then
    raise exception 'Profile does not exist';
  end if;


  select coalesce(sum(c.points_awarded), 0)::integer
  into v_earned
  from public.completions as c
  where c.user_id = v_user_id;


  select coalesce(sum(r.points_redeemed), 0)::integer
  into v_redeemed
  from public.redemptions as r
  where r.user_id = v_user_id;


  v_available := v_earned - v_redeemed;


  if v_available <= 0 then
    raise exception 'No points are available to cash in';
  end if;


  if p_points > v_available then
    raise exception 'Cash-in amount exceeds available points';
  end if;


  insert into public.redemptions (
    user_id,
    points_redeemed
  )
  values (
    v_user_id,
    p_points
  );


  return p_points;

end;
$$;


revoke execute
on function public.cash_in_points(integer)
from public, anon, authenticated;

grant execute
on function public.cash_in_points(integer)
to authenticated;



-- ============================================================
-- 13. ADMIN ROLE CHECK FOR FRONTEND UX
--
-- This tells the frontend whether to SHOW admin navigation.
--
-- It is not the security boundary.
-- Every privileged admin RPC performs its own authorization.
-- ============================================================

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles as p
    where p.id = auth.uid()
      and p.is_admin = true
  );
$$;


revoke execute
on function public.current_user_is_admin()
from public, anon, authenticated;

grant execute
on function public.current_user_is_admin()
to authenticated;



-- ============================================================
-- 14. PRIVATE ADMIN AUTHORIZATION HELPERS
--
-- The private schema is not intended to be exposed through the
-- Data API.
--
-- require_admin():
--   Used by WRITE RPCs and locks the admin profile row for the
--   transaction.
--
-- require_admin_readonly():
--   Used by STABLE/read-only RPCs because row locks are not
--   allowed in PostgREST read-only transactions.
-- ============================================================

create schema if not exists private;


revoke all
on schema private
from public, anon, authenticated;



create or replace function private.require_admin()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin

  v_user_id := auth.uid();


  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;


  perform 1
  from public.profiles as p
  where p.id = v_user_id
    and p.is_admin = true
  for share;


  if not found then
    raise exception 'Administrator access required'
      using errcode = '42501';
  end if;


  return v_user_id;

end;
$$;


revoke all
on function private.require_admin()
from public, anon, authenticated;



create or replace function private.require_admin_readonly()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin

  v_user_id := auth.uid();


  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;


  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_user_id
      and p.is_admin = true
  ) then
    raise exception 'Administrator access required'
      using errcode = '42501';
  end if;


  return v_user_id;

end;
$$;


revoke all
on function private.require_admin_readonly()
from public, anon, authenticated;



-- ============================================================
-- 15. ADMIN: LIST ALL CHORES
--
-- Includes:
--   enabled
--   disabled
--   available
--   cooling-down
--   completed one-off chores
--
-- This is read-only and therefore uses require_admin_readonly().
-- ============================================================

create or replace function public.admin_list_chores()
returns table (
  id bigint,
  name text,
  description text,
  estimated_minutes integer,
  points integer,
  active boolean,
  completion_limit integer,
  progress_count integer,
  cooldown_days integer,
  available_from timestamptz,
  is_available boolean,
  tag_ids bigint[],
  tags text[],
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin

  perform private.require_admin_readonly();


  return query

  select
    c.id,
    c.name,
    c.description,
    c.estimated_minutes,
    c.points,
    c.active,
    c.completion_limit,

    (
      select count(*)::integer
      from public.completions as co
      where co.chore_id = c.id
        and co.completed_at >= c.available_from
    ) as progress_count,

    c.cooldown_days,
    c.available_from,

    (
      c.active = true
      and c.available_from <= now()

      and (
        c.completion_limit is null

        or

        (
          select count(*)
          from public.completions as co
          where co.chore_id = c.id
            and co.completed_at >= c.available_from
        ) < c.completion_limit
      )
    ) as is_available,

    coalesce(
      (
        select array_agg(t.id order by t.name)
        from public.chore_tags as ct
        join public.tags as t
          on t.id = ct.tag_id
        where ct.chore_id = c.id
      ),
      array[]::bigint[]
    ) as tag_ids,

    coalesce(
      (
        select array_agg(t.name order by t.name)
        from public.chore_tags as ct
        join public.tags as t
          on t.id = ct.tag_id
        where ct.chore_id = c.id
      ),
      array[]::text[]
    ) as tags,

    c.created_at,
    c.updated_at

  from public.chores as c

  order by c.name;

end;
$$;


revoke execute
on function public.admin_list_chores()
from public, anon, authenticated;

grant execute
on function public.admin_list_chores()
to authenticated;



-- ============================================================
-- 16. ADMIN: CREATE TAG
-- ============================================================

create or replace function public.admin_create_tag(
  p_name text,
  p_color text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_color text;
  v_tag_id bigint;
begin

  perform private.require_admin();


  v_name := nullif(trim(p_name), '');
  v_color := nullif(trim(p_color), '');


  if v_name is null then
    raise exception 'Tag name is required';
  end if;


  if length(v_name) > 40 then
    raise exception 'Tag name must be 40 characters or fewer';
  end if;


  if v_color is not null
     and v_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'Tag color must be a six-digit hex color';
  end if;


  if exists (
    select 1
    from public.tags as t
    where lower(t.name) = lower(v_name)
  ) then
    raise exception 'Tag already exists';
  end if;


  insert into public.tags (
    name,
    color
  )
  values (
    v_name,
    v_color
  )
  returning id into v_tag_id;


  return v_tag_id;

end;
$$;


revoke execute
on function public.admin_create_tag(text, text)
from public, anon, authenticated;

grant execute
on function public.admin_create_tag(text, text)
to authenticated;



-- ============================================================
-- 17. ADMIN: UPDATE TAG
-- ============================================================

create or replace function public.admin_update_tag(
  p_tag_id bigint,
  p_name text,
  p_color text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_color text;
begin

  perform private.require_admin();


  v_name := nullif(trim(p_name), '');
  v_color := nullif(trim(p_color), '');


  if v_name is null then
    raise exception 'Tag name is required';
  end if;


  if length(v_name) > 40 then
    raise exception 'Tag name must be 40 characters or fewer';
  end if;


  if v_color is not null
     and v_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'Tag color must be a six-digit hex color';
  end if;


  if exists (
    select 1
    from public.tags as t
    where lower(t.name) = lower(v_name)
      and t.id <> p_tag_id
  ) then
    raise exception 'Tag already exists';
  end if;


  update public.tags
  set
    name = v_name,
    color = v_color
  where id = p_tag_id;


  if not found then
    raise exception 'Tag does not exist';
  end if;

end;
$$;


revoke execute
on function public.admin_update_tag(bigint, text, text)
from public, anon, authenticated;

grant execute
on function public.admin_update_tag(bigint, text, text)
to authenticated;



-- ============================================================
-- 18. ADMIN: CREATE CHORE
-- ============================================================

create or replace function public.admin_create_chore(
  p_name text,
  p_points integer,
  p_estimated_minutes integer default null,
  p_description text default null,
  p_completion_limit integer default 1,
  p_cooldown_days integer default null,
  p_tag_ids bigint[] default array[]::bigint[],
  p_active boolean default true
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_description text;
  v_tag_ids bigint[];
  v_chore_id bigint;
begin

  perform private.require_admin();


  v_name := nullif(trim(p_name), '');
  v_description := nullif(trim(p_description), '');
  v_tag_ids := coalesce(p_tag_ids, array[]::bigint[]);


  if v_name is null then
    raise exception 'Chore name is required';
  end if;


  if length(v_name) > 200 then
    raise exception 'Chore name must be 200 characters or fewer';
  end if;


  if v_description is not null
     and length(v_description) > 2000 then
    raise exception 'Description must be 2000 characters or fewer';
  end if;


  if p_points is null
     or p_points < 0
     or p_points > 100000 then
    raise exception 'Points must be between 0 and 100000';
  end if;


  if p_estimated_minutes is not null
     and (
       p_estimated_minutes <= 0
       or p_estimated_minutes > 1440
     ) then
    raise exception 'Estimated minutes must be between 1 and 1440';
  end if;


  if p_completion_limit is not null
     and (
       p_completion_limit <= 0
       or p_completion_limit > 1000
     ) then
    raise exception 'Completion limit must be between 1 and 1000';
  end if;


  if p_cooldown_days is not null
     and (
       p_cooldown_days <= 0
       or p_cooldown_days > 3650
     ) then
    raise exception 'Cooldown days must be between 1 and 3650';
  end if;


  if p_cooldown_days is not null
     and p_completion_limit is null then
    raise exception 'A cooldown requires a completion limit';
  end if;


  if p_active is null then
    raise exception 'Active state is required';
  end if;


  if cardinality(v_tag_ids) > 20 then
    raise exception 'A chore may have at most 20 tags';
  end if;


  if exists (
    select 1
    from unnest(v_tag_ids) as x(tag_id)
    left join public.tags as t
      on t.id = x.tag_id
    where t.id is null
  ) then
    raise exception 'One or more tags do not exist';
  end if;


  insert into public.chores (
    name,
    description,
    estimated_minutes,
    points,
    active,
    completion_limit,
    cooldown_days,
    available_from,
    updated_at
  )
  values (
    v_name,
    v_description,
    p_estimated_minutes,
    p_points,
    p_active,
    p_completion_limit,
    p_cooldown_days,
    now(),
    now()
  )
  returning id into v_chore_id;


  insert into public.chore_tags (
    chore_id,
    tag_id
  )
  select
    v_chore_id,
    x.tag_id
  from (
    select distinct unnest(v_tag_ids) as tag_id
  ) as x;


  return v_chore_id;

end;
$$;


revoke execute
on function public.admin_create_chore(
  text,
  integer,
  integer,
  text,
  integer,
  integer,
  bigint[],
  boolean
)
from public, anon, authenticated;

grant execute
on function public.admin_create_chore(
  text,
  integer,
  integer,
  text,
  integer,
  integer,
  bigint[],
  boolean
)
to authenticated;



-- ============================================================
-- 19. ADMIN: UPDATE CHORE
--
-- Editing configuration does NOT reset the current cycle.
-- Use admin_reset_chore() explicitly to start a new cycle.
-- ============================================================

create or replace function public.admin_update_chore(
  p_chore_id bigint,
  p_name text,
  p_points integer,
  p_estimated_minutes integer default null,
  p_description text default null,
  p_completion_limit integer default 1,
  p_cooldown_days integer default null,
  p_tag_ids bigint[] default array[]::bigint[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_description text;
  v_tag_ids bigint[];
begin

  perform private.require_admin();


  v_name := nullif(trim(p_name), '');
  v_description := nullif(trim(p_description), '');
  v_tag_ids := coalesce(p_tag_ids, array[]::bigint[]);


  if v_name is null then
    raise exception 'Chore name is required';
  end if;


  if length(v_name) > 200 then
    raise exception 'Chore name must be 200 characters or fewer';
  end if;


  if v_description is not null
     and length(v_description) > 2000 then
    raise exception 'Description must be 2000 characters or fewer';
  end if;


  if p_points is null
     or p_points < 0
     or p_points > 100000 then
    raise exception 'Points must be between 0 and 100000';
  end if;


  if p_estimated_minutes is not null
     and (
       p_estimated_minutes <= 0
       or p_estimated_minutes > 1440
     ) then
    raise exception 'Estimated minutes must be between 1 and 1440';
  end if;


  if p_completion_limit is not null
     and (
       p_completion_limit <= 0
       or p_completion_limit > 1000
     ) then
    raise exception 'Completion limit must be between 1 and 1000';
  end if;


  if p_cooldown_days is not null
     and (
       p_cooldown_days <= 0
       or p_cooldown_days > 3650
     ) then
    raise exception 'Cooldown days must be between 1 and 3650';
  end if;


  if p_cooldown_days is not null
     and p_completion_limit is null then
    raise exception 'A cooldown requires a completion limit';
  end if;


  if cardinality(v_tag_ids) > 20 then
    raise exception 'A chore may have at most 20 tags';
  end if;


  if exists (
    select 1
    from unnest(v_tag_ids) as x(tag_id)
    left join public.tags as t
      on t.id = x.tag_id
    where t.id is null
  ) then
    raise exception 'One or more tags do not exist';
  end if;


  update public.chores
  set
    name = v_name,
    description = v_description,
    estimated_minutes = p_estimated_minutes,
    points = p_points,
    completion_limit = p_completion_limit,
    cooldown_days = p_cooldown_days,
    updated_at = now()
  where id = p_chore_id;


  if not found then
    raise exception 'Chore does not exist';
  end if;


  delete from public.chore_tags
  where chore_id = p_chore_id;


  insert into public.chore_tags (
    chore_id,
    tag_id
  )
  select
    p_chore_id,
    x.tag_id
  from (
    select distinct unnest(v_tag_ids) as tag_id
  ) as x;

end;
$$;


revoke execute
on function public.admin_update_chore(
  bigint,
  text,
  integer,
  integer,
  text,
  integer,
  integer,
  bigint[]
)
from public, anon, authenticated;

grant execute
on function public.admin_update_chore(
  bigint,
  text,
  integer,
  integer,
  text,
  integer,
  integer,
  bigint[]
)
to authenticated;



-- ============================================================
-- 20. ADMIN: ENABLE / DISABLE CHORE
--
-- This changes ONLY the administrator switch.
--
-- It does not reset:
--   cycle progress
--   available_from
--   cooldown
-- ============================================================

create or replace function public.admin_set_chore_enabled(
  p_chore_id bigint,
  p_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin

  perform private.require_admin();


  if p_enabled is null then
    raise exception 'Enabled state is required';
  end if;


  update public.chores
  set
    active = p_enabled,
    updated_at = now()
  where id = p_chore_id;


  if not found then
    raise exception 'Chore does not exist';
  end if;

end;
$$;


revoke execute
on function public.admin_set_chore_enabled(bigint, boolean)
from public, anon, authenticated;

grant execute
on function public.admin_set_chore_enabled(bigint, boolean)
to authenticated;



-- ============================================================
-- 21. ADMIN: RESET CHORE
--
-- Starts a fresh cycle immediately and enables the chore.
--
-- Historical completions and awarded points remain intact.
-- ============================================================

create or replace function public.admin_reset_chore(
  p_chore_id bigint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin

  perform private.require_admin();


  update public.chores
  set
    active = true,
    available_from = now(),
    updated_at = now()
  where id = p_chore_id;


  if not found then
    raise exception 'Chore does not exist';
  end if;

end;
$$;


revoke execute
on function public.admin_reset_chore(bigint)
from public, anon, authenticated;

grant execute
on function public.admin_reset_chore(bigint)
to authenticated;



-- ============================================================
-- 22. REMOVE OBSOLETE RESET API
-- ============================================================

drop function if exists public.reset_chore(bigint);



-- ============================================================
-- CURRENT SECURITY SUMMARY
--
-- Anonymous:
--   no table access
--   no privileged RPC access
--
-- Authenticated household users:
--   SELECT household application data
--   complete chores via complete_chore()
--   set own profile color via set_profile_color()
--   cash in own available points via cash_in_points(amount)
--   query available chores via list_available_chores()
--
-- Administrators:
--   have NO direct table-write privileges either
--   privileged changes occur only through admin_* RPCs
--   every admin write RPC checks private.require_admin()
--
-- Browser clients cannot directly:
--   insert/update/delete chores
--   insert/update/delete completions
--   insert/update/delete redemptions
--   insert/update/delete tags/chore_tags
--   change profiles.is_admin
--
-- There is deliberately:
--   no chore-delete RPC
--   no tag-delete RPC
--   no browser admin-promotion RPC
--
-- Historical completions remain the lifetime leaderboard
-- source of truth.
-- ============================================================
