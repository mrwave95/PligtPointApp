# PligtPointApp Architecture

## Overview

PligtPointApp is a private household chores and points application.

The current application architecture is:

- **Frontend:** Lovable
- **Backend:** Supabase Cloud
- **Database:** PostgreSQL
- **Authentication:** Supabase Auth
- **Authorization:** PostgreSQL privileges, Row Level Security, and secured RPC functions

The original Vite/TypeScript frontend in this repository was used as an early integration and security prototype. The active frontend is now developed in Lovable and connects to the existing Supabase backend.

The backend is the authoritative source of truth.

The browser is treated as untrusted.


---

# Authentication

Household members authenticate using Supabase Auth.

Current security choices:

- Public signup is disabled
- Anonymous sign-in is disabled
- Email/password authentication is enabled
- Household users are created manually
- Password minimum length is 12
- Secure email change is enabled
- Secure password change is enabled
- Current password is required for password changes

The frontend may contain:

- Supabase project URL
- Supabase publishable key

The frontend must never contain:

- Supabase service-role / secret key
- Database password
- Administrative credentials


---

# Profiles

Authentication accounts live in:

`auth.users`

Application-facing profile information lives in:

`public.profiles`

The shared identifier is:

`auth.users.id = public.profiles.id`

Important profile fields include:

- `id`
- `display_name`
- `color`
- `is_admin`
- `created_at`

Authenticated users may read profiles.

Browser users do **not** receive direct UPDATE permission on `public.profiles`.

A user changes their own profile color through:

`set_profile_color(p_color)`

The `is_admin` field is controlled by the database and cannot be modified directly by the browser.


---

# Points Model

PligtPointApp separates **lifetime earned points** from **available points**.

## Lifetime leaderboard points

Lifetime points are calculated from:

`SUM(public.completions.points_awarded)`

Cashing in points does **not** reduce lifetime leaderboard score.

The leaderboard is derived from completion history rather than stored as a mutable score.

## Available points

Available/spendable points are:

`earned points - redeemed points`

Redemptions are stored in:

`public.redemptions`

Users cash in points through:

`cash_in_points(p_points)`

The frontend sends only the requested amount.

The backend independently:

1. identifies the authenticated user
2. calculates lifetime points earned
3. calculates points already redeemed
4. calculates the real available balance
5. rejects invalid or excessive redemption amounts
6. records the redemption

The browser cannot insert directly into `public.redemptions`.


---

# Chores

Chores are stored in:

`public.chores`

Important fields include:

- `id`
- `name`
- `description`
- `estimated_minutes`
- `points`
- `active`
- `completion_limit`
- `cooldown_days`
- `available_from`
- `created_at`
- `updated_at`

## Enabled versus available

These are deliberately different concepts.

### `active`

`active` is the administrator enable/disable switch.

If:

`active = false`

the chore is disabled regardless of recurrence state.

### `available_from`

`available_from` determines the beginning of the current or next chore cycle.

A chore cannot be completed before this timestamp.


---

# Chore Behaviour Model

PligtPointApp avoids calendar scheduling.

Recurrence uses **elapsed time only**.

One cooldown day means exactly:

`24 elapsed hours`

The combination of `completion_limit` and `cooldown_days` describes chore behaviour.

## One-off

```text
completion_limit = 1
cooldown_days = NULL
