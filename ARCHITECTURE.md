# PligtPointApp Architecture

## Overview

PligtPointApp is a household chores PWA.

Frontend:
- Vite
- TypeScript
- GitHub repository
- Eventually deployed as a PWA

Backend:
- Supabase Cloud
- PostgreSQL
- Supabase Auth
- Row Level Security

---

## Authentication

Household members authenticate with Supabase Auth.

Public signup is disabled.

Anonymous sign-in is disabled.

The application uses:

- Supabase project URL
- Supabase publishable key

The frontend must never contain:

- Supabase secret/service-role keys
- database password
- admin credentials

---

## Profiles

Supabase stores login accounts in:

auth.users

The application stores display information separately in:

public.profiles

The two tables share the same user UUID.

Example:

auth.users.id
    =
public.profiles.id

The frontend does not need direct access to auth.users.

---

## Chores

Available chores are stored in:

public.chores

Important fields:

- id
- name
- estimated_minutes
- points
- active

For the first version, chores are managed directly through Supabase rather than through the PWA.

---

## Completions

Completed chores are stored in:

public.completions

Each completion records:

- chore_id
- user_id
- points_awarded
- completed_at

The leaderboard is calculated from completion records.

It is not stored as a separate authoritative score.

---

## Completing a chore

The browser is NOT allowed to insert directly into public.completions.

Instead it calls:

complete_chore(chore_id)

The browser supplies only the chore ID.

PostgreSQL determines:

- authenticated user via auth.uid()
- current chore point value
- completion timestamp

This prevents the client from choosing its own user ID or point value.

---

## Permissions

Anonymous users:

- cannot read profiles
- cannot read chores
- cannot read completions
- cannot call complete_chore()

Authenticated household users:

- can read profiles
- can read chores
- can read completions
- can call complete_chore()
- cannot directly insert/update/delete completion records

---

## Security principle

The browser is treated as untrusted.

The frontend may request an action, but Supabase/PostgreSQL decides whether that action is allowed and what trusted data is recorded.