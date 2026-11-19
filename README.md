# HangOut

HangOut is a place-based dating application where users pin up to five cafés, parks, venues, and other places they enjoy, discover people who share those places, express interest, form mutual matches, chat, and propose meeting at a shared public location.

This README covers the current implementation, development setup, security boundaries, and roadmap. The legacy prototype is retained separately for reference.

## Current status

The active codebase is the **React, TypeScript, Vite, and Supabase app**, with the core Phase 2 flows and profile enhancements implemented. Supabase integration still needs broader verification. Phase 3 priorities are in `docs/PHASE-3-IMPLEMENTATION-PLAN.md`.

The signed-out home page is a public marketing page. Its sign-up and login links open the existing Supabase authentication form; `legacy-phase0.html` remains a reference prototype and is not served as the live app.

| Phase | Status | Outcome |
|---|---|---|
| 0 | Completed | Hardened single-file prototype, retained as `legacy-phase0.html` |
| 1 | Implemented; environment validation in progress | Real accounts, profiles, photos, interests, and persistent pinned places |
| 2 | Implemented in source; integration testing in progress | Discovery, swipes, matches, realtime chat, meetups, blocks, and reports |
| 3 | In progress | Authorization hardening and admin/moderator dashboard implemented in source; database verification, abuse prevention, photo safety, and lifecycle work remain |
| 4 | Planned | Closed beta and launch preparation |
| 5 | Planned | Evidence-led growth features |
| 6 | Exploratory | Community, events, smarter ranking, and venue tools |

## Product principles

- **Place-oriented:** matching begins with a shared place rather than generic proximity alone.
- **Safety-conscious:** exact live locations are not exposed.
- **Server-enforced:** authorization must be enforced through PostgreSQL Row Level Security and protected functions, not only React controls.
- **Focused launch:** begin in one dense district before expanding.
- **Evidence-led:** growth features are prioritized after retention, safety, and marketplace-density results are available.

## Technology stack

- React 19
- TypeScript 5
- Vite 7
- Supabase Auth, PostgreSQL, Realtime, and Row Level Security
- OpenStreetMap Nominatim for development place search
- Planned Phase 3 tooling: Supabase CLI, pgTAP, Vitest, React Testing Library, Playwright, GitHub Actions, and Sentry

## Repository structure

```text
hangout-development-package/
├── .env.example
├── index.html
├── legacy-phase0.html
├── package.json
├── README.md
├── docs/
│   ├── HANDOFF.md
│   ├── PHASE-3-IMPLEMENTATION-PLAN.md
│   ├── ROADMAP.md
│   └── START-HERE.md
├── public/
│   ├── hangout-logo.png
│   ├── marketing-hero.png
│   └── marketing-hero-collage.png
├── src/
│   ├── App.tsx
│   ├── main.tsx
│   ├── styles.css
│   ├── types.ts
│   ├── components/
│   │   ├── Auth.tsx
│   │   ├── AdminDashboard.tsx
│   │   ├── Discovery.tsx
│   │   ├── MatchesChat.tsx
│   │   ├── Meetup.tsx
│   │   ├── Places.tsx
│   │   └── ProfileEditor.tsx
│   └── lib/supabase.ts
├── scripts/
│   └── seed-makati-test-users.mjs
└── supabase/migrations/
    ├── 001_initial.sql
    ├── 002_matching_chat_safety.sql
    ├── 003_fix_profile_places_insert_policy.sql
    ├── 004_profile_interests_and_photos.sql
    ├── 005_require_profile_photo.sql
    ├── 006_additional_profile_photos.sql
    ├── 007_authorization_hardening.sql
    ├── 008_moderation.sql
    ├── 009_dating_intentions.sql
    ├── 010_place_stories.sql
    ├── 011_discovery_one_card_per_person.sql
    ├── 012_gender_discovery_preferences.sql
    ├── 013_discovery_profile_age_zodiac.sql
    ├── 014_hangout_personality.sql
    ├── 015_admin_dashboard.sql
    ├── 016_hangout_personality_one_word.sql
    ├── 017_custom_hangout_personality.sql
    └── 018_manual_identity_verification.sql
```

# Combined development phases

## Phase 0: Prototype and hardening

**Status: Completed**

Phase 0 proved the concept in one browser-only file using HTML, CSS, vanilla JavaScript, hash routing, sample people, and `localStorage`.

Completed:

- Home, How it works, Places, and Safety pages
- Local demonstration sign-up and login
- Nominatim place search and up to five local pins
- Sample swipe deck, simulated matches, and canned chat replies
- Local blocking
- Prototype and sample-user disclosure
- Prototype Privacy Policy, Terms, and Community Guidelines
- 18+ registration confirmation
- Local data deletion
- Chat-draft and focus preservation
- Keyboard behavior for authentication tabs

The prototype is retained as `legacy-phase0.html`. It must not be used as a production authentication or messaging implementation.

## Phase 1: Accounts, profiles, and persistent data

**Status: Implemented in source; environment validation in progress**

Implemented:

- Migration to React, TypeScript, and Vite
- Supabase email registration and password login
- Email-verification-ready authentication and persisted sessions
- Automatic profile creation
- First name, adult birth date, and 280-character bio
- Persistent `places` and `profile_places`
- Maximum of five pins
- Initial RLS policies
- Responsive authenticated dashboard
- Discover onboarding prompts users to complete required profile fields and upload a main photo.
- One required public profile photo and up to two optional public photos.
- Up to five predefined interests, shown on discovery cards.

Still required:

- Protected account deletion
- User data export
- Automated RLS tests
- Profile-photo moderation and trusted server-side image processing

**Acceptance gate:** two verified users can register on separate devices, create profiles, pin the same place, sign out, sign back in, and recover the same data.

## Phase 2: Discovery, matching, chat, and meetups

**Status: Implemented in source, pending full Supabase integration testing**

Implemented:

- Discovery restricted to users sharing a pinned place
- Exclusion of previously swiped and blocked users
- Like and pass decisions
- Atomic reciprocal matching with a unique user-pair constraint
- Participant-only match lists
- Realtime messages, unread counts, and read timestamps
- Messages limited to 1,000 characters
- Meetup proposals with place, date/time, note, and status
- Accept and decline actions
- Blocks and categorized reports
- RLS for all Phase 2 tables

Database objects include `swipes`, `matches`, `messages`, `meetup_proposals`, `blocks`, `reports`, `discover_candidates(...)`, `record_swipe(...)`, and `list_matches()`.

Remaining hardening:

- Make message and meetup authorization explicitly block-aware.
- Replace direct meetup updates with validated RPC state transitions.
- Add pagination, message retry, and Realtime reconnect behavior.
- Replace `prompt` and `confirm` with accessible dialogs.
- Add concurrency, RPC, and RLS tests.
- Replace public Nominatim browser calls with a supported production provider or protected proxy.

**Acceptance gate:** two users sharing a place can discover each other, create exactly one match under concurrent likes, exchange authorized realtime messages, manage a meetup proposal, and stop interaction after a block.

## Phase 3: Trust, safety, and operations

**Status: Planned and ready to implement**

The detailed six-week plan is in `docs/PHASE-3-IMPLEMENTATION-PLAN.md`.

Workstreams:

1. Block-aware message, meetup, discovery, and match authorization
2. Validated meetup accept, decline, cancel, and change functions
3. Structured report dialog and limited evidence snapshots
4. Server-validated moderator roles, queue, actions, assignments, and immutable audit logs
5. Server-side rate limits for sign-up, login, swipes, messages, reports, place search, and photos
6. Complete photo safety controls: server-side validation/re-encoding, moderation, and review workflow. Basic browser validation, metadata-removal re-encoding, ownership policies, a public bucket, and a size limit are implemented.
7. Session revocation, data export, and account deletion
8. ESLint, Prettier, Vitest, React Testing Library, Playwright, Supabase CLI, pgTAP, GitHub Actions, and Sentry

The initial baseline uses migrations `001` through `006`; current migrations extend through `018`. Continue with new numbers and do not reuse migration filenames:

```text
019_rate_limits.sql
020_photo_moderation.sql
021_account_lifecycle.sql
```

First tickets:

- `SEC-301`: block-aware message authorization
- `SEC-302`: block-aware meetup authorization
- `DB-303`: validated meetup-transition RPCs
- `TEST-304`: Supabase CLI and pgTAP RLS test foundation

The migration and client integration for these tickets are implemented. `npm install` installs the project-scoped Supabase CLI. Install and start Docker Desktop, start a disposable local stack with `npm run db:start`, and run `npm run test:db` to execute all database suites before applying migrations 007–022 to a hosted project. The tests require Docker to be running.

**Acceptance gate:** a trained moderator can investigate and action a report without direct database access; blocked interactions are denied by the database; sensitive actions are audited; automated security tests pass.

## Phase 4: Closed beta and launch preparation

**Status: Planned after Phase 3**

Planned:

- Select one dense launch district, such as BGC, Makati CBD, or Poblacion, instead of all Metro Manila.
- Separate development, staging, and production Supabase projects.
- CI-controlled migration deployment.
- Sentry monitoring, uptime checks, backup restoration, and rollback drills.
- Consent-aware analytics.
- Playwright user-journey and pgTAP RLS tests.
- Jurisdiction-reviewed Privacy Policy, Terms, and Community Guidelines.
- Moderator staffing and response targets.
- Production geocoding using Mapbox Search, Google Places, HERE, or a protected cache/proxy.

Suggested beta gates:

- At least 20 eligible candidates for most active users
- At least 50% shared-place coverage in displayed candidates
- No known high-severity RLS bypass
- All block-enforcement integration tests passing
- Moderator coverage during published response windows
- Successful staging backup restoration

## Phase 5: Evidence-led growth

**Status: Planned after beta evidence**

Candidates:

- Push and email notifications
- Place pages and clearly labeled venue partnerships
- Profile prompts and preference filters (interest tags are already implemented)
- Group hangouts and double dates
- Event-based matching
- Premium features such as extra pins, boosts, and “see who liked you”
- Multi-language, local currencies, and dark theme
- PWA installation, then native wrappers only if retention supports the investment

Do not implement live “I’m here now” check-ins until expiry, visibility, abuse controls, rate limits, and emergency-disable behavior are designed and tested.

## Phase 6: Longer-term options

**Status: Exploratory**

- Friends and community modes using the place graph
- Concert, market, class, and event discovery
- Ranking informed by conversation and meetup outcomes
- Fairness and safety review for ranking models
- Host tools for venues
- Community-led activities around trusted places

These ideas must not displace safety, retention, and marketplace-density work.

# Local development

## Prerequisites

- Node.js 20 LTS or newer
- npm 10 or newer
- Git
- Visual Studio Code
- A Supabase development project
- Optional: Supabase CLI and Docker Desktop

## Setup

```bash
npm install
test -e .env.local || cp .env.example .env.local
```

Windows PowerShell:

```powershell
npm install
if (!(Test-Path '.env.local')) { Copy-Item .env.example .env.local }
```

Configure `.env.local`:

```text
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
```

Run:

```bash
npm run typecheck
npm run build
npm run dev
```

Vite normally serves the app at `http://localhost:5173`.

## Supabase setup

Run migrations in order:

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
19. `supabase/migrations/019_multiple_custom_hangout_personalities.sql`
20. `supabase/migrations/020_match_only_social_profiles.sql`
21. `supabase/migrations/021_discover_hangout_rankings.sql`
22. `supabase/migrations/022_match_profile_view.sql`

Profile photos are required for profile updates and discovery, and stored in a public bucket. Images are resized and re-encoded in the browser as JPEG to remove metadata; public URLs may be viewed by anyone who has the URL.

Migration 007 makes match/message/meetup reads and writes block-aware, restricts message updates to read receipts, and routes meetup responses, cancellations, and revisions through validated RPCs.

Migration 008 adds private report evidence, role-protected moderator data, and `submit_report`, which captures the reported profile plus no more than 20 selected or recent conversation messages. Reports are submitted in-app through the accessible report dialog. Provision moderator accounts only through trusted database administration.

Migration 009 adds a required primary dating intention. Existing profiles default to "Still figuring it out"; users can change it in Profile, and it appears on Discover cards.

Migrations 013 and 014 add the profile details and discovery eligibility used by current screens.

Migration 015 adds admin-only aggregate statistics and name/email search, moderator report triage, immutable account-status history, and reversible account deactivation. Email lookup is restricted to an admin-checked database function. Deactivated users are excluded from discovery and interaction RPCs; user-facing profile edits, swipes, blocks, and photo writes are denied. The dashboard is in `src/components/AdminDashboard.tsx`; run `supabase/tests/database/admin_dashboard.test.sql` before applying this migration to a hosted project.

Migration 016 renames HangOut personality choices to one-word labels and maps existing profile values to their matching labels without changing the three-to-five selection requirement.

Migration 017 adds one optional, one-word custom personality (up to 30 characters) in addition to the three-to-five predefined choices. Discovery returns the custom label with each profile.

Migration 018 adds a private government-ID upload and manual review workflow. Only admins and moderators can view pending images; files are deleted after approval, rejection, or withdrawal. The public Verified badge means only that an ID was reviewed, not that a background or safety check was performed. The profile editor requires consent, and cleanup failures remain visible to reviewers and prevent the badge from appearing until deletion succeeds. Run `supabase/tests/database/identity_verification.test.sql` as part of the full database suite before applying the migration to a hosted project.

Migration 021 adds an authenticated aggregate RPC for the five most-pinned places and the five places pinned by the most active users in the last seven days. It returns counts, not member identities.

Migration 022 adds a match-authorized RPC to reopen a match's profile in chat. It returns shared profile details but not the exact birth date or discovery preferences, and denies access for non-matches, blocked users, and inactive accounts.

### Seed Makati discovery profiles

After applying migrations through `006`, create five synthetic development accounts that share Ayala Triangle Gardens:

1. Create `.env.seed.local` with `SEED_TARGET=development`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY`. Use the development project's service-role key only in this ignored, server-side file; never use a `VITE_` variable or commit/share the key.
2. Run `npm run seed:makati`.
3. Pin Ayala Triangle Gardens to your own profile to see the seed accounts in Discover.

The script is idempotent and uses synthetic avatar illustrations rather than real people's photos. Generated account passwords are not saved or printed; the accounts are for discovery test data, not sign-in. Remove the `hangout-seed-01@example.com` through `hangout-seed-05@example.com` Auth users from the development project when finished.

Configure Supabase Auth:

- Set the Site URL to the local or deployed app.
- Add `http://localhost:5173` and the return URLs `http://localhost:5173/?authMode=signup` and `http://localhost:5173/?authMode=login` to the redirect URL allowlist. Password reset uses the login return URL. Add the equivalent deployed URLs.
- Keep email confirmation enabled for realistic tests.
- Never place a service-role key, database password, or secret provider credential in `VITE_*` variables.

To enable Google and Facebook sign-in:

1. Create OAuth apps in the Google and Meta developer consoles.
2. Enable Google and Facebook under Supabase Auth providers, and configure each provider with the callback URL shown by the Supabase project.
3. Store the provider client credentials in Supabase Auth settings only. Do not commit them or expose them in browser environment variables.
4. Set Meta's Privacy Policy URL to the deployed app origin plus `/privacy-policy.html`.
5. Test both a new social account and an existing account. New social accounts must complete first-name and 18+ confirmation before using HangOut.

After another environment depends on a migration, add corrective migrations rather than editing previously applied migrations.

# Code map

| File | Responsibility |
|---|---|
| `src/App.tsx` | Session bootstrap, navigation, and top-level routing |
| `src/components/AdminDashboard.tsx` | Protected stats, user search/deactivation, and moderation queue |
| `src/lib/supabase.ts` | Supabase client and environment validation |
| `src/components/Auth.tsx` | Email and social registration/login, plus social account completion |
| `src/components/ProfileEditor.tsx` | Profile and adult birth-date validation |
| `src/components/Places.tsx` | Search and management of five pinned places |
| `src/components/Discovery.tsx` | Shared-place candidates and swipes |
| `src/components/MatchesChat.tsx` | Matches, Realtime chat, block, and report |
| `src/components/Meetup.tsx` | Meetup proposals and responses |
| `src/styles.css` | Responsive global styling |
| `src/types.ts` | Shared TypeScript types |

# Two-account smoke test

1. Register and verify two accounts in separate browser profiles.
2. Set an adult birth date for both.
3. Pin the same place.
4. Like each account from the other.
5. Confirm exactly one match.
6. Exchange messages and verify realtime delivery.
7. Confirm unread counts clear after opening the chat.
8. Create and accept a meetup proposal.
9. Submit a test report.
10. Test blocking with disposable accounts.
11. Verify through database or direct API tests that blocked interaction is denied, not merely hidden.

# Security requirements

- Treat RLS and protected server functions as the authorization boundary.
- Never rely on React controls alone for security.
- Never expose a Supabase service-role key in browser code.
- Keep exact live coordinates out of discovery, analytics, and logs.
- Strip EXIF location from uploaded photos.
- Exclude messages, report details, birth dates, access tokens, and exact coordinates from Sentry and analytics.
- Test unauthenticated, unrelated authenticated, participant, blocked, and moderator access.
- Keep admin email search behind an admin-checked server function; never expose Auth email data through broad client queries.
- Treat account deactivation as reversible app access suspension, not permanent deletion or Auth-user removal.
- Keep development, staging, and production data separate.
- Use fictional test users and places outside production.

# Testing target

- **Vitest:** unit and component logic
- **React Testing Library:** forms, dialogs, and accessibility behavior
- **Playwright:** registration, discovery, matching, chat, block, report, and moderation journeys
- **Supabase CLI:** repeatable local database environment
- **pgTAP:** RLS, RPC, transition, and concurrency tests
- **GitHub Actions:** install, format, lint, type check, test, build, migration reset, database tests, and Playwright smoke tests

High-risk scenarios must cover unauthorized reads, concurrent reciprocal likes, block enforcement, invalid meetup transitions, report confidentiality, moderator authorization, the five-place limit, adult-date validation, and account deletion.

# Beta metrics

- Sign-up completion
- Median time to first pinned place
- Pins per active user, initial target 3 or more
- Eligible candidates per active user
- Shared-place candidate coverage
- Like-to-match conversion
- First-message rate
- Meetup proposals and acceptance
- Reports per 1,000 active users
- Median moderation time by severity
- Day 7 and day 30 retention
- Message-send and Realtime-delivery error rate

# Main risks

| Risk | Mitigation |
|---|---|
| Thin user density | Launch in one dense district and measure eligible candidates before expansion |
| Safety incident | Complete Phase 3 and establish escalation coverage before public launch |
| Location privacy leak | Use place context and coarse bands, never exact live coordinates |
| RLS misconfiguration | pgTAP negative tests, separate environments, and security review |
| Nominatim limits | Move to Mapbox Search, Google Places, HERE, or a protected cached proxy |
| Spam and harassment | Rate limits, risk signals, block/mute enforcement, and moderation |
| Fake profiles | Controlled photos, optional verification, rate limits, and reporting |
| Duplicate matches | Unique database constraints and concurrency tests |
| Moderator misuse | Least privilege, MFA, audit logs, and access reviews |

# Development workflow

Recommended branches:

- `main`: protected and deployable
- `develop`: optional for a multi-developer team
- Short-lived feature branches such as `security/block-aware-messages`

Require at least one review for normal changes and two reviews for migrations, RLS, authentication, moderation, deletion, or Edge Functions. Include migration and rollback notes in related pull requests.

Suggested baseline commit:

```text
chore: establish validated phase 2 baseline
```

# Related documentation

- `docs/START-HERE.md`: concise environment bootstrap
- `docs/HANDOFF.md`: architecture, risks, and continuation instructions
- `docs/ROADMAP.md`: phase-level roadmap
- `docs/PHASE-3-IMPLEMENTATION-PLAN.md`: detailed six-week Phase 3 execution plan

# Immediate next step

Open `docs/PHASE-3-IMPLEMENTATION-PLAN.md`. Tickets `SEC-301` through `TEST-304` have implementation in place but remain incomplete until the local Supabase pgTAP suite passes. Install Supabase CLI and Docker Desktop, run `npm run db:start`, then `npm run test:db`.
