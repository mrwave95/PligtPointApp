-- ============================================================
-- PligtPointApp
-- Initial database schema
--
-- This file describes how to recreate the backend from scratch.
--
-- IMPORTANT:
-- Do NOT run this migration manually against the current
-- Supabase project. These objects already exist there.
-- ============================================================


-- ============================================================
-- PROFILES
--
-- App-facing information about authenticated users.
-- Login credentials remain inside Supabase auth.users.
-- ============================================================

create table public.profiles (
  id uuid primary key
    references auth.users(id)
    on delete cascade,

  display_name text not null,

  created_at timestamptz not null
    default now()
);


-- ============================================================
-- CHORES
-- ============================================================

create table public.chores (
  id bigint generated always as identity
    primary key,

  name text not null,

  estimated_minutes integer,

  points integer not null
    check (points >= 0),

  active boolean not null
    default true,

  created_at timestamptz not null
    default now()
);


-- ============================================================
-- COMPLETIONS
--
-- One row represents one completed chore.
--
-- points_awarded is stored here so historical completions
-- keep their original value even if the chore value changes.
-- ============================================================

create table public.completions (
  id bigint generated always as identity
    primary key,

  chore_id bigint not null
    references public.chores(id),

  user_id uuid not null
    references auth.users(id),

  points_awarded integer not null
    check (points_awarded >= 0),

  completed_at timestamptz not null
    default now()
);


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles
  enable row level security;

alter table public.chores
  enable row level security;

alter table public.completions
  enable row level security;


-- ============================================================
-- TABLE PRIVILEGES
--
-- Start with no browser/API access.
-- Then grant authenticated users SELECT only.
-- ============================================================

revoke all
on table public.profiles
from anon, authenticated;

revoke all
on table public.chores
from anon, authenticated;

revoke all
on table public.completions
from anon, authenticated;


grant select
on table public.profiles
to authenticated;

grant select
on table public.chores
to authenticated;

grant select
on table public.completions
to authenticated;


-- ============================================================
-- READ POLICIES
--
-- All authenticated household members may read these tables.
-- Anonymous users receive no access.
-- ============================================================

create policy "Authenticated users can read profiles"
on public.profiles
for select
to authenticated
using (true);


create policy "Authenticated users can read chores"
on public.chores
for select
to authenticated
using (true);


create policy "Authenticated users can read completions"
on public.completions
for select
to authenticated
using (true);


-- ============================================================
-- COMPLETE CHORE
--
-- Browser supplies only the chore ID.
--
-- The database determines:
--   - authenticated user
--   - awarded points
--   - completion timestamp
--
-- Browser users do not receive direct INSERT permission
-- on public.completions.
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
  v_completion_id bigint;
begin

  -- Identify the authenticated caller.
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'You must be signed in';
  end if;


  -- Retrieve the trusted point value directly from the database.
  -- Only active chores may be completed.
  select c.points
    into v_points
  from public.chores as c
  where c.id = p_chore_id
    and c.active = true;


  if not found then
    raise exception 'Chore does not exist or is inactive';
  end if;


  -- Record the completion.
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


  return v_completion_id;
end;
$$;


-- ============================================================
-- FUNCTION PERMISSIONS
--
-- Only authenticated users may call complete_chore().
-- ============================================================

revoke execute
on function public.complete_chore(bigint)
from public, anon, authenticated;


grant execute
on function public.complete_chore(bigint)
to authenticated;