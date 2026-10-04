# PligtPointApp Design Guide

## Purpose

This file documents the approved visual language and interaction style for PligtPointApp.

Its purpose is to help future development preserve the look and feel of the app after the frontend moves away from Lovable and is maintained directly from GitHub.

The design should evolve carefully rather than being reinvented screen by screen.


# Overall Character

PligtPointApp should feel:

- cheerful
- simple
- friendly
- calm
- modern
- household-oriented
- easy to understand at a glance

It should not feel:

- corporate
- overly gamified
- cluttered
- childish
- visually noisy
- overly technical

The interface should prioritize clarity and warmth over decoration.


# Core Visual Language

The primary visual language is:

- white / near-white surfaces in light mode
- black / very dark surfaces in dark mode
- purple as the primary accent color
- rounded corners throughout
- restrained use of user-specific colors
- generous spacing
- clear hierarchy
- simple typography
- soft transitions rather than flashy animation

Purple should be used mainly for:

- primary actions
- active navigation
- important borders
- selected states
- highlights
- progress emphasis

Do not overuse purple as a full-screen or full-card background.


# Branding

The main household branding is:

**Familien PANS Pligt Point**

Existing branding assets include:

- `public/pligtpoint-header.png`
- `public/pligtpoint-icon.png`

Use the wide header/logo near the top of the Home / Leaderboard screen.

Use the compact icon for:

- PWA/app icon
- compact branding
- places where the full header would be too large

Do not stretch, distort, crop awkwardly, or recolor the logo assets without a deliberate redesign.


# Light Mode

Light mode should use:

- white or near-white page background
- white cards/surfaces
- near-black text
- subtle neutral borders
- purple accents
- restrained shadows only when necessary

Avoid grey-on-grey interfaces with low contrast.


# Dark Mode

Dark mode should use:

- black or very dark page background
- dark surfaces
- white or near-white text
- subtle lighter borders
- the same purple accent language as light mode

Dark mode should feel intentionally designed rather than simply inverted.


# Typography

Typography should be clean and highly readable.

Use hierarchy through:

- font size
- font weight
- spacing

Avoid excessive font variation.

Primary values such as:

- household points
- user points
- chore points
- available cash-in balance

should be visually prominent.

Secondary metadata such as:

- estimated time
- tags
- timestamps
- recurrence information

should be quieter.


# Shape Language

Rounded geometry is a major part of the app identity.

Use rounded:

- cards
- buttons
- input fields
- tag chips
- modals
- bottom sheets
- user tiles

Avoid sharp rectangular UI unless technically necessary.

Touch targets should be comfortably sized for phones.


# Home / Leaderboard

The Home screen is also the household leaderboard.

The general composition should remain:

1. Wide PligtPointApp / Familien PANS branding near the top.
2. Main household points area.
3. Household member cards.
4. Activity area.
5. Persistent bottom navigation.

The main leaderboard area may use a rounded purple frame or accent structure near the screen edges.

## Household total

The total household lifetime points should be prominent.

It should be easy to understand immediately without reading explanatory text.

## User cards

Users should appear as compact square or rounded cards, typically in a two-column layout when space allows.

Each card should show:

- display name
- lifetime points
- restrained personal color accent

Do not fill the entire card with the user's profile color.

The profile color should be used for things such as:

- edge accent
- small stripe
- icon
- name accent
- small highlight

The leading user receives a star in the upper-right area.

If multiple users are tied for the lead, all tied leaders should receive the star.

## Activity

Activity should be concise and easy to scan.

Examples:

- `Far cashed in 4 points`
- future completion activity if added later

Activity should be derived from real backend records.

Do not display fake or decorative activity.


# Bottom Navigation

The bottom navigation is a key structural element.

It should remain persistent on the primary authenticated screens.

Current structure:

- left: Leaderboard / Home
- center: Chores
- right: Profile

The Chores action should be visually more prominent than the side actions.

Preferred composition:

- smaller left button
- larger raised circular or strongly emphasized center Chores button
- smaller right button

The active section should be clearly identifiable.

Do not casually add more permanent items to the bottom navigation.

Administration belongs inside Profile rather than becoming a fourth primary nav item.


# Chores Screen

The Chores screen should feel action-oriented and easy to scan.

Available chores are displayed as vertically stacked rounded cards.

Each chore may show:

- name
- estimated time
- points
- tags
- counter progress when relevant

Do not expose backend terminology such as:

- `completion_limit`
- `cooldown_days`
- `available_from`

to normal household users.

Translate backend rules into human language where they need to be shown.


# Chore Cards

The chore name is the primary visual element.

Points should be easy to spot.

Estimated time and tags are secondary.

Counter chores may show progress such as:

`3 / 8`

Do not show meaningless progress such as:

`0 / 1`

for ordinary one-completion chores.

Tags should use compact rounded chips.

A chore with multiple tags may show multiple chips, but avoid allowing tags to dominate the card.


# Completing a Chore

Completing a chore should feel satisfying but restrained.

Preferred interaction:

1. User taps Complete.
2. Confirmation appears.
3. Backend request is sent.
4. Success feedback shows awarded points.
5. Card responds to the resulting backend state.

Possible result:

- one-off chore disappears
- elapsed chore disappears during cooldown
- counter chore remains with increased progress
- unlimited chore remains available

The frontend must not guess which case applies.

It should refetch trusted backend state.


# Chore Completion Animation

A short fade/dim transition is appropriate.

Typical behavior:

- briefly reduce card opacity
- show success feedback
- refetch
- remove or restore the card based on returned backend data

Do not leave unavailable chores permanently faded inside the normal available chores list.


# Chore Sorting and Filtering

Sorting and filtering are display-only frontend features.

Sorting options currently include:

- Name A–Z
- Points highest first
- Points lowest first
- Time shortest first
- Time longest first

Tags are a separate filter, not a sort.

The tag filter should support selecting multiple tags.

Matching uses OR logic:

Selecting:

- Kitchen
- Garden

shows chores tagged Kitchen **or** Garden.

All household tags should remain visible as filter choices even if there is currently no available chore using one of them.


# Profile Screen

The Profile screen should remain simple and personal.

It should show:

- current user
- available/spendable points
- profile color
- cash-in action
- Administration entry for admins only
- quiet Sign Out action near the bottom

Do not turn Profile into a complex settings dashboard.


# Profile Color

Users may select their own personal color.

Color changes should save immediately.

There should not be a separate Save button for the color.

The personal color should influence the UI subtly.

Avoid using it as the entire page or card background.


# Cash In

Cash In refers to spendable points, not lifetime leaderboard points.

The screen should clearly distinguish:

- lifetime points
- available points

The user chooses a whole-number amount to cash in.

The flow should:

1. show current available balance
2. allow amount selection
3. confirm the chosen amount
4. call the secure backend RPC
5. update the remaining balance

The interaction should feel deliberate but not alarming.


# Login Screen

The Login screen should be visually restrained.

It should contain:

- branding
- email
- password
- sign-in action
- restrained loading/error state

It should not contain:

- public signup
- social login
- bottom navigation
- unnecessary promotional text


# Administration

Administration is functional rather than decorative.

It should preserve the same visual language as the rest of the app while clearly communicating system state.

Admins should be able to understand the difference between:

**Enabled**

and:

**Available**

These are not the same state.

An enabled chore may still be unavailable because:

- it is in cooldown
- its counter limit was reached
- its current cycle is otherwise complete


# Admin Chore Cards

Admin cards may display more information than normal chore cards.

Useful admin state includes:

- name
- tags
- points
- estimated time
- enabled / disabled
- available / unavailable
- counter progress
- elapsed cooldown rule

Actions should include only what is necessary.

Current admin actions:

- Create
- Edit
- Enable / Disable
- Reset

Reset should remain visually secondary because it changes the current chore cycle.


# Chore Editor

The admin chore editor should use human-readable behavior choices.

Do not expose the raw database model directly.

Supported UI options:

## One-off

Meaning:

Complete once, then wait for admin reset.

Backend mapping:

```text
completion_limit = 1
cooldown_days = null
