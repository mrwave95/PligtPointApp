# PligtPointApp TODO

This file tracks deliberately deferred work.

Items here are not necessarily bugs. They are features or improvements that were intentionally postponed while building and securing the core application.


## Multi-user testing — completed

Verified:

- normal login works
- normal user does not see Administration
- manually opening `/admin` returns Access Denied
- admin RPCs reject non-admin users
- both users appear correctly on the leaderboard
- chore completions are attributed to the correct user
- counter chores use household-wide progress
- each user has an independent available cash-in balance
- one user's redemption does not affect another user's balance
- cashing in does not reduce lifetime leaderboard points


## Realtime / live updates

Add Supabase Realtime or equivalent automatic query invalidation.

Goal:

Changes made by another device or administrator should appear in already-open clients without requiring a reload or navigation.

Examples:

- admin enables or disables a chore
- admin resets a chore
- admin creates or edits a chore
- tag changes
- another household member completes a chore
- leaderboard changes
- redemption activity changes

The backend remains authoritative. Realtime should notify/refetch frontend state rather than move business rules into the browser.


## Chore administration improvements

Possible later improvements:

- better status text for chores currently in cooldown
- optional display of when a chore will become available again
- improved tag organization if the number of tags becomes large
- search if the chore list becomes large

Do not add chore deletion casually.

Historical completion records are part of the lifetime leaderboard and should remain intact.


## Household/user administration

Currently household accounts and administrator status are managed manually in Supabase.

Possible future admin features:

- invite/create household users safely
- change display names
- controlled administrator promotion/demotion

Admin promotion must remain a protected backend operation and must never rely only on frontend controls.


## Activity

The leaderboard currently includes real cash-in/redemption activity.

Possible future additions:

- recent chore completions
- combined completion/redemption timeline

Keep activity derived from trusted backend records.


## PWA and deployment

Before considering the app finished:

- verify installable PWA behavior
- verify icons and manifest
- verify mobile layout on real devices
- choose production deployment
- confirm HTTPS
- test session persistence after installation


## Backup / recovery

Before relying on the app for long-term household history:

- define a Supabase backup/export routine
- verify the documented migrations can reconstruct a fresh backend
- periodically review `ARCHITECTURE.md` and migration files after backend changes


## Security regression checks

After major backend changes, repeat key checks:

- anonymous access denied
- authenticated users cannot directly write protected tables
- non-admin users cannot execute admin operations successfully
- admin writes work only through secured RPCs
- service-role/secret keys never appear in frontend code
- cash-in cannot exceed actual available balance
- chore completion cannot supply arbitrary points/user IDs
