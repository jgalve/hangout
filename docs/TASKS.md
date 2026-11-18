# Task Handoffs

Use this lightweight template per feature.

## Pending and deferred follow-ups

### Manual ID verification deployment and database tests
- Status: Deferred per user
- Goal: Verify and safely apply migration 018 for the manual ID review flow.
- Acceptance criteria:
  - [ ] Start a disposable local Supabase stack and run `npm run test:db`; the identity-verification pgTAP file has 19 assertions.
  - [ ] Reconcile the hosted migration history before applying migration 018.
  - [ ] Confirm ID upload, admin/moderator review, cleanup retries, and badge behavior after migration.
- Files: `supabase/migrations/018_manual_identity_verification.sql`, `supabase/tests/database/identity_verification.test.sql`
- Developer notes: The local database tests have not run because Postgres at `127.0.0.1:54322` was unavailable and Docker/Podman was not installed. Nothing was applied to production. Prior checks found the hosted migration ledger empty despite schema markers for earlier migrations; do not run `supabase db push` until that history is reconciled.

### Google and Facebook OAuth configuration and validation
- Status: App implementation complete; provider setup pending
- Goal: Enable and verify social sign-up/login in Supabase Auth.
- Acceptance criteria:
  - [ ] Create Google and Meta/Facebook OAuth apps and enable the providers in Supabase Auth.
  - [ ] Configure provider callback URLs and allowlist local and deployed app return URLs.
  - [ ] Test successful login, cancellation/errors, new-account first-name and 18+ completion, and existing-account behavior.
- Files: `src/components/Auth.tsx`, `src/App.tsx`, `README.md`
- Developer notes: Provider credentials belong only in Supabase Auth settings, not client environment variables. Frontend build passed, but live OAuth was not tested because provider credentials and redirect configuration are not set.

### Discover match-success card animation
- Status: Deferred per user
- Goal: Celebrate a mutual match on the Discover card before switching to Matches.
- Acceptance criteria:
  - [ ] Animate only after the server confirms a mutual match.
  - [ ] Respect reduced-motion preferences and preserve the existing no-match behavior.
- Files: `src/components/Discovery.tsx`, `src/App.tsx`, `src/styles.css`
- Developer notes: Plan discussed; no implementation has been made.

## Feature: <title>
- Status: Planned / In progress / In QA / In review / Done
- Goal:
- Assumptions:
- Acceptance criteria:
  - [ ] ...
- Planned files:
- API/data considerations:
- Security considerations:
- Tests to run:
- Developer notes:
- QA results:
- Reviewer findings:
- Unresolved items:

## Feature: Multiple custom HangOut personalities
- Status: In QA
- Goal: Allow up to three comma-separated custom one-word personalities and show each separately in Discover.
- Acceptance criteria:
  - [x] Profile input accepts up to three unique entries, with up to 30 characters per entry.
  - [x] Discover renders each custom entry as a separate personality.
  - [x] Database validation preserves one-word, predefined-choice, count, and uniqueness rules.
  - [ ] Run the database personality tests against the local Supabase stack.
- Files: `src/components/ProfileEditor.tsx`, `src/components/Discovery.tsx`, `supabase/migrations/019_multiple_custom_hangout_personalities.sql`, `supabase/tests/database/hangout_personality.test.sql`, `docs/UX-FLOWS.md`
- Developer notes: TypeScript and production build passed. Database tests could not connect because local Postgres at `127.0.0.1:54322` is unavailable. Migration 019 has not been applied to any database.

## Feature: Match-only social profile links
- Status: In QA
- Goal: Let users share optional Facebook, Instagram, and TikTok profile URLs with active mutual matches only.
- Acceptance criteria:
  - [x] Users can save validated HTTPS profile URLs from the supported social platforms.
  - [x] A server-authorized match function returns links only for active, unblocked mutual matches.
  - [x] Links are rendered in chat and excluded from Discover profile data.
  - [ ] Run the social-link database tests against the local Supabase stack.
- Files: `src/components/ProfileEditor.tsx`, `src/components/MatchesChat.tsx`, `supabase/migrations/020_match_only_social_profiles.sql`, `supabase/tests/database/match_social_profiles.test.sql`, `docs/UX-FLOWS.md`
- Developer notes: TypeScript and production build passed. Database tests could not connect because local Postgres at `127.0.0.1:54322` is unavailable. Migration 020 has not been applied to any database.

## Feature: View match profile from chat
- Status: In QA
- Goal: Let users reopen each active match's profile from its chat.
- Acceptance criteria:
  - [x] Each active conversation has a View profile action that opens the shared profile dialog.
  - [x] Profile data is returned only for an active, unblocked mutual match and omits the exact birth date and private discovery preferences.
  - [ ] Run match-profile authorization tests against the local Supabase stack.
- Files: `src/components/MatchesChat.tsx`, `src/components/Discovery.tsx`, `src/components/ProfileDialog.tsx`, `supabase/migrations/022_match_profile_view.sql`, `supabase/tests/database/match_profile_view.test.sql`, `docs/UX-FLOWS.md`
- Developer notes: The profile dialog is shared with Discover. The new RPC returns only mutual shared-place stories and is separate from the match-only social-link RPC.
- QA results: `npm run build` and `git diff --check` passed. `npm run test:db` could not connect because local Postgres at `127.0.0.1:54322` is unavailable; migration 022 and its authorization tests remain unverified.

## Feature: Discover popular and trending hangouts
- Status: In QA
- Goal: Show the five most-pinned places and five places with the most new pins in the last seven days at the top of Discover.
- Assumptions: Counts are distinct active profiles; existing `profile_places.created_at` timestamps define new pins. Rankings are global and expose counts only.
- Acceptance criteria:
  - [x] Popular and trending lists are limited to five and use active accounts only.
  - [x] Trending counts pins created in the last seven days.
  - [x] Ranked-place names are informational; a separate action pins the place to the signed-in user's profile.
  - [x] Already-pinned places and the five-place limit are handled without duplicates.
  - [ ] Run ranking database tests against the local Supabase stack.
- Files: `src/components/Discovery.tsx`, `src/components/Places.tsx`, `src/lib/profilePlaces.ts`, `src/styles.css`, `supabase/migrations/021_discover_hangout_rankings.sql`, `supabase/tests/database/place_rankings.test.sql`, `docs/UX-FLOWS.md`
- Developer notes: The existing place-pin timestamp supports the requested seven-day window; the new migration adds only a read-only aggregate RPC. The migration has not been applied.
- QA results: `npm run build` and `git diff --check` passed. `npm run test:db` could not connect because local Postgres at `127.0.0.1:54322` is unavailable; the ranking database tests remain unverified.

## Feature: Featured hangout promo on Discover
- Status: In QA
- Goal: Show one admin-configurable featured hangout and pair-focused promo between the Popular and Trending sections.
- Acceptance criteria:
  - [x] Discover renders Popular, Featured, and Trending in that order, with a responsive photo placeholder.
  - [x] Admins can edit the venue, promo copy, terms, optional HTTPS photo and call-to-action, demo-only marker, and publish state.
  - [x] The published Solaire Pasay sample is clearly labeled as a demo and not redeemable or venue-affiliated.
  - [x] Admins select a catalog place; the featured card links to its OpenStreetMap element and pins that same place to the signed-in user's profile.
  - [x] Featured pin controls show already-pinned, pinning, five-place-limit, and error states.
  - [x] Draft content is hidden from Discover, and database functions enforce admin-only configuration access.
  - [ ] Run featured-hangout pgTAP authorization, place association, and publish-state tests against local Supabase.
- Files: `src/components/Discovery.tsx`, `src/components/AdminDashboard.tsx`, `src/components/FeaturedHangoutCard.tsx`, `src/styles.css`, `supabase/migrations/023_featured_hangout.sql`, `supabase/migrations/024_featured_hangout_place_link.sql`, `supabase/tests/database/featured_hangout.test.sql`, `docs/UX-FLOWS.md`
- Developer notes: The initial promo is explicitly demo-only. No real discount, package, venue benefit, or partnership is claimed. Migration 023 was applied by the user with the original nine-argument save function; migration 024 upgrades it to the place-linked function without editing the applied migration.
- QA results: `npm run build` and `git diff --check` passed; the build retains Vite's existing large-chunk warning. The local public page returned HTTP 200, but authenticated Discover/admin states were not visually verified. Migration 024 and the 20 pgTAP assertions have not been applied/run.

## Feature: Discover invite sharing
- Status: In QA
- Goal: Let signed-in users share HangOut's public marketing homepage from the bottom of Discover.
- Acceptance criteria:
  - [x] Share only the public `/` destination, without profile data or signed-in Discover content.
  - [x] Offer the device share sheet when supported, copy link, WhatsApp, Facebook, X, and email.
  - [x] Show accessible copy success/error and share-sheet error states; do not treat cancellation as an error.
  - [x] Use responsive, keyboard-accessible controls with at least 44px touch targets.
  - [x] Defer a direct Messenger button; Messenger may be available from the device share sheet.
  - [ ] Verify rendered behavior at narrow mobile, tablet, and desktop widths.
- Files: `src/components/Discovery.tsx`, `src/components/DiscoveryShare.tsx`, `src/styles.css`, `docs/UX-FLOWS.md`
- Developer notes: Share URLs are static public destinations; no backend changes or new dependencies are required.
- QA results: `npm run build` and `git diff --check` passed. The authenticated Discover panel and its responsive layout were not visually verified because no signed-in test session was available.

## Completed features

### Profile photo gallery
- Status: Done
- Goal: Match profile photo previews to Discover card sizing, unify photo uploads, and allow choosing an extra photo as the default.
- Acceptance criteria:
  - [x] Main photo uses the Discover card's 1.08:1 crop; extra photos use the Discover thumbnail dimensions.
  - [x] Primary and extra photo controls share one profile photos section.
  - [x] Selecting an extra photo as default keeps the former default in the gallery.
  - [x] Photo storage cleanup follows each photo's URL so changing defaults cannot delete or overwrite the wrong image.
- Files: `src/components/ProfileEditor.tsx`, `src/styles.css`
- QA results: Local TypeScript build and Vite production build passed. `git diff --check` passed. npm's global launcher is missing required modules; local binaries were used for validation.
