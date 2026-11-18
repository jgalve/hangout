# HangOut Developer Handoff

Last updated: 11 November 2026

## 1. Product summary

HangOut is a dating application where discovery starts with shared hangout places. A user pins up to five cafés, parks, venues, or similar places. The app finds eligible people sharing at least one pinned place. Users can like or pass, and a mutual like creates a match. Matched users can chat and propose meeting at the shared public place.

Brand attributes: friendly, trustworthy, place-oriented, and safety-conscious.

Current objective: continue development in the active React/TypeScript/Vite workspace. Core discovery, matching, chat, meetups, profile onboarding, dating intentions, interest tags, and profile photos are implemented in source. Continue Supabase integration testing and Phase 3 authorization/safety hardening before any public beta.

## 2. Local development

### Prerequisites

- Node.js and npm versions supported by the installed Vite toolchain
- A Supabase project for development
- Optional: Supabase CLI and Docker Desktop for local Supabase

### Commands

```bash
npm install
test -e .env.local || cp .env.example .env.local
npm run typecheck
npm run build
npm run dev
```

Windows PowerShell equivalent:

```powershell
npm install
if (!(Test-Path '.env.local')) { Copy-Item .env.example .env.local }
npm run typecheck
npm run build
npm run dev
```

Set these variables in `.env.local`:

```text
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
```

Never use a Supabase service-role key in the browser application.

## 3. Database migration order

Run the SQL files in this order:

1. `supabase/migrations/001_initial.sql`
2. `supabase/migrations/002_matching_chat_safety.sql`
3. `supabase/migrations/003_fix_profile_places_insert_policy.sql`
4. `supabase/migrations/004_profile_interests_and_photos.sql`
5. `supabase/migrations/005_require_profile_photo.sql`
6. `supabase/migrations/006_additional_profile_photos.sql`
7. `supabase/migrations/007_authorization_hardening.sql`
8. `supabase/migrations/008_moderation.sql`
9. `supabase/migrations/009_dating_intentions.sql`
10. `supabase/migrations/010_place_stories.sql`
11. `supabase/migrations/011_discovery_one_card_per_person.sql`
12. `supabase/migrations/012_gender_discovery_preferences.sql`
13. `supabase/migrations/013_discovery_profile_age_zodiac.sql`
14. `supabase/migrations/014_hangout_personality.sql`
15. `supabase/migrations/015_admin_dashboard.sql`
16. `supabase/migrations/016_hangout_personality_one_word.sql`
17. `supabase/migrations/017_custom_hangout_personality.sql`
18. `supabase/migrations/018_manual_identity_verification.sql`

`001_initial.sql` creates:

- `profiles`
- `places`
- `profile_places`
- automatic profile creation after a new Auth user
- initial RLS policies

`002_matching_chat_safety.sql` creates:

- `swipes`
- `matches`
- `messages`
- `meetup_proposals`
- `blocks`
- `reports`
- enum types for swipe, meetup, and report status
- discovery, matching, and match-list database functions
- participant RLS policies
- Realtime publication entries for messages and meetup proposals

`004_profile_interests_and_photos.sql` adds up to five predefined profile interests and a public profile-photo bucket. Photos are limited to JPEG after browser-side resizing/re-encoding; originals are not retained. The public URLs are visible to anyone who has the URL. Storage upload, update, and delete operations are restricted to the authenticated user's folder.

`005_require_profile_photo.sql` requires a profile photo for profile updates and discovery. Existing users without a photo must upload one before they can save profile edits or appear in discovery. The profile photo is replaceable but cannot be removed through the app.

`006_additional_profile_photos.sql` adds two optional photo slots per profile and returns them through discovery. The photos use the existing public bucket and per-user Storage ownership policies.

`007_authorization_hardening.sql` makes match, message, and meetup access block-aware; limits message updates to read receipts; and replaces direct meetup status updates with validated response, cancellation, and revision RPCs. The matching client uses those RPCs and displays failures. First apply it to a disposable local Supabase database and pass the database tests; only then apply it to a hosted development project.

`008_moderation.sql` adds the moderator role registry, private report evidence snapshots, moderation action/audit tables, and an authenticated `submit_report` RPC. The RPC accepts only report participants, snapshots a limited profile, and records either up to 20 selected conversation messages or the latest 20. `MatchesChat` provides the accessible report form and case reference. `npm install` installs the project-scoped Supabase CLI; Docker Desktop must also be running. Use `npm run db:start` and then `npm run test:db` to verify locally before applying unverified migrations to a hosted project. Moderator accounts are provisioned only through trusted database administration.

`015_admin_dashboard.sql` adds admin-only aggregate statistics and name/email search, moderator report status actions, immutable account-status history, and reversible app deactivation. Email lookup is available only through the admin-checked search RPC. Deactivation retains the Auth user and safety data while denying app operations. The dashboard component is `src/components/AdminDashboard.tsx`; the pgTAP suite is `supabase/tests/database/admin_dashboard.test.sql`. Verify the full database suite before applying the migration to a hosted project.

`016_hangout_personality_one_word.sql` maps existing HangOut personality values to one-word labels while preserving each profile's selections and the three-to-five choice requirement.

`017_custom_hangout_personality.sql` adds one optional custom one-word personality alongside the three-to-five predefined choices and returns it from discovery.

`018_manual_identity_verification.sql` adds private government-ID uploads, admin/moderator review, immutable review events, deletion after a decision or withdrawal, and a public Verified status that appears only after cleanup. The badge means an ID was reviewed; it is not a background check.

`009_dating_intentions.sql` adds a required primary intention with a constrained set of values. Existing profiles default to "Still figuring it out"; the profile editor lets users change it and Discover displays it on candidate cards. The profile editor also derives and displays age and zodiac sign from the entered birth date without storing these redundant values. The pgTAP coverage for dating intention is in `supabase/tests/database/dating_intentions.test.sql`.

`010_place_stories.sql` adds an optional 280-character story to each pinned place. Owners can edit only their own story; discovery returns it only with a candidate's shared place. The profile place editor and Discover card surface this story. pgTAP coverage is in `supabase/tests/database/place_stories.test.sql`.

`011_discovery_one_card_per_person.sql` changes discovery to return one row per person with an ordered array of all shared places and their stories. The Discover cards show every shared place once. pgTAP coverage is in `supabase/tests/database/discovery_one_card_per_person.test.sql`.

`012_gender_discovery_preferences.sql` adds optional gender identity and mutual discovery preferences. Identity is shown only when disclosed; "open to everyone" is the default, and profiles without a disclosed identity may remain eligible. The profile editor and Discover cards expose these fields. pgTAP coverage is in `supabase/tests/database/gender_discovery_preferences.test.sql`.

The full database suites for migrations 007–012 remain unverified; assertion 22 from the authorization suite was reported as passing, but Docker was unavailable and remote database verification was deferred. Do not apply unverified migrations to a hosted database until the relevant test suites pass on a disposable database.

The current profile-photo policy is one required main photo plus up to two optional extra photos. All three are in a public bucket; anyone with a photo URL can view it. Interests are limited to five predefined values. Discover requires a first name, birth date, and main photo.

Apply migrations first to a disposable development project. Do not run unreviewed SQL directly against production.

For five synthetic Makati discovery accounts, configure the ignored `.env.seed.local` file with `SEED_TARGET=development`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY`, then run `npm run seed:makati`. The script is idempotent, creates confirmed Auth users with unsaved random passwords and synthetic avatar illustrations, and pins Ayala Triangle Gardens to each profile. Seeded users are for discovery testing, not sign-in.

Migration 003 replaces the original `profile_places` insert policy, whose row-count subquery recursively evaluated RLS on the same table. Run it after migrations 001 and 002, including on fresh databases. The `position` range and unique `(profile_id, position)` constraint enforce the five-place maximum without that subquery.

## 4. Frontend code map

| File | Responsibility |
|---|---|
| `src/App.tsx` | Session bootstrap, authenticated navigation, top-level feature routing |
| `src/components/AdminDashboard.tsx` | Protected stats, user search/deactivation, and moderation queue |
| `src/lib/supabase.ts` | Supabase browser client and environment validation |
| `src/components/Auth.tsx` | Email/social sign-up and login, social-account completion, and auth messages |
| `src/components/ProfileEditor.tsx` | Profile fields, primary dating intention, interest tags, and required/optional photo uploads |
| `src/components/Places.tsx` | Nominatim search and up to five persisted places |
| `src/components/Discovery.tsx` | Candidate loading and like/pass actions |
| `src/components/MatchesChat.tsx` | Match list, message history, Realtime subscription, block and report |
| `src/components/Meetup.tsx` | Meetup creation and accept/decline actions |
| `src/styles.css` | Global responsive styling |
| `src/types.ts` | Shared profile, place, and relationship types |

## 5. Data and authorization model

### Profiles

- `profiles.id` matches `auth.users.id`.
- A database trigger creates a profile after registration.
- The current owner policy allows users to read and update their own complete profile.
- Discovery exposes only selected candidate fields through `discover_candidates`.

### Places

- `places` stores normalized OpenStreetMap identifiers and coordinates.
- `profile_places` links users to up to five places.
- Coordinates must not be returned to other users through discovery or match APIs.
- Current place-write policies are acceptable only for a closed development environment. Restrict canonical writes through an Edge Function before production.

### Swipes and matches

- A user owns their swipe rows.
- `record_swipe` records the decision and atomically creates a match when a reciprocal like exists.
- User IDs are stored in deterministic low/high order.
- A unique constraint prevents duplicate pairs.
- The match stores one shared place as context.

### Messages

- Messages belong to a match and sender.
- RLS calls `are_matched` to limit access to participants.
- Realtime listens for inserts filtered by match ID.
- The recipient updates `read_at`.
- Before beta, add pagination, rate limits, reconnect handling, and delivery reconciliation.

### Blocks

- The blocker owns the block row.
- `is_blocked` checks both directions.
- Discovery and match-list functions exclude blocked pairs.
- Migration 007 also applies block-aware match, message, and meetup policies. The existing authorization pgTAP suite covers core blocked reads and writes; notification and profile-access cases remain untested.

### Reports

- Migration 008 routes report submissions through `submit_report`, captures a limited profile snapshot and at most 20 messages, and allows reporters to read their own report evidence.
- Reported users cannot read reports about themselves.
- A moderator role registry, moderator-only report/evidence reads, moderation-action records, and immutable audit log are in the schema. Provisioning is database-admin-only. The dashboard and role-checked action RPCs are implemented in source; migration 015 and its pgTAP coverage still need local verification.
- Run `supabase/tests/database/moderation.test.sql` locally before applying migration 008 to a hosted project.

## 6. Important implementation risks

### Existing migration needs security review

Security-definer functions must explicitly minimize privileges and use a fixed `search_path`. Review all `grant execute` statements and add tests for unauthenticated, unrelated authenticated, participant, blocked, and moderator roles.

### Meetup state transitions are too permissive

Migration 007 replaces direct client updates with database functions that validate who may accept, decline, change, or cancel each status. Run the full local database suite before applying the migration to a hosted project.

### Message access after blocking

Migration 007 replaces the caller-supplied-user helper with a block-aware helper and denies new message and meetup access after either participant blocks the other. The migration and pgTAP suite still require local database execution before deployment.

### Public place search

`Places.tsx` calls public Nominatim directly. This is suitable for low-volume development only. For beta, use a supported provider such as Mapbox Search, Google Places, or HERE, or proxy and cache requests through a Supabase Edge Function.

### Browser dialogs

Report and block flows currently use `prompt` and `confirm`. Replace them with accessible modal forms containing explicit categories, validation, cancellation, focus management, and success states.

## 7. Recommended development tooling

Add the following during setup:

- ESLint with TypeScript ESLint.
- Prettier.
- Vitest and React Testing Library for component tests.
- Playwright for browser workflows.
- Supabase CLI for migrations and local development.
- pgTAP for database and RLS tests.
- GitHub Actions for type check, test, build, and migration validation.
- Sentry for frontend error monitoring before beta.

Recommended npm scripts after tooling is added:

```json
{
  "lint": "eslint .",
  "format:check": "prettier --check .",
  "test": "vitest run",
  "test:e2e": "playwright test",
  "db:start": "supabase start",
  "db:reset": "supabase db reset"
}
```

## 8. Baseline test matrix

| Scenario | Expected result |
|---|---|
| Unauthenticated table request | Denied except explicitly public data |
| User reads another complete profile directly | Denied |
| User discovers someone with no shared place | Not returned |
| User discovers someone already swiped | Not returned |
| Two simultaneous reciprocal likes | Exactly one match |
| Unrelated user reads match messages | Denied |
| Match participant sends message | Allowed |
| Blocked participant sends another message | Must be denied after Phase 3 policy fix |
| User submits report | Allowed and hidden from reported user |
| Sixth profile place | Denied |
| Under-18 birth date | Denied by database constraint |
| Meetup scheduled in the past | Rejected by application now; add database enforcement |

## 9. Phase 3 backlog, in order

1. Fix block-aware message and meetup authorization.
2. Replace meetup updates with validated database functions.
3. Add automated RLS and concurrency tests.
4. Replace the remaining browser block confirmation with an accessible dialog.
5. Verify the moderator/admin queue, report actions, user search, and reversible deactivation in migration 015.
6. Add per-account and per-IP rate limits through Edge Functions or gateway controls.
7. Add profile-photo Storage policy tests, moderation, and trusted server-side image processing; current client-side uploads and public bucket are basic beta-only implementation.
8. Add password reset, account deletion, and data export.
9. Add production geocoding and caching.
10. Add Playwright end-to-end tests and GitHub Actions.

## 10. Product decisions still required

- Initial launch district: BGC, Makati CBD, Poblacion, or another tightly bounded area.
- Whether profile photos need pre-publication moderation and/or verification.
- Gender and matching-preference model.
- Moderator staffing and published response targets.
- Data-retention and deletion rules for messages, reports, photos, and backups.
- Legal entity and jurisdiction-specific privacy and terms documents.
- Whether accepted meetups remain visible after either participant blocks the other.
