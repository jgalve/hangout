# HangOut Roadmap

Last updated: 11 November 2026

## Goal

Grow HangOut from a working place-based dating beta into a trusted, measurable service that can support real users in one launch area. Phases are ordered by dependency. Estimates assume one experienced full-stack developer and do not include legal review or full-time moderation staffing.

## Current position

- Phase 0: completed in the legacy single-file prototype.
- Phase 1: implemented in source; development environment validation is in progress.
- Phase 2: implemented in source; Supabase integration testing is in progress.
- Profile onboarding, required main photo, two optional extra photos, up to five interest tags, and required primary dating intention are implemented in source.
- Phase 3: authorization and report capture are implemented in source; the admin/moderator dashboard is implemented but database verification remains. Photo moderation and server-side processing remain future work.

## Phase 0: Prototype hardening

**Status: Completed**

Completed items:

- Added prototype and sample-user disclosures.
- Added Privacy Policy, Terms, and Community Guidelines pages for prototype testing.
- Added an 18+ registration confirmation.
- Added deletion of locally stored prototype data.
- Preserved chat drafts and focus during rerenders.
- Added authentication-tab keyboard behavior.
- Retained the original implementation as `legacy-phase0.html`.

Remaining release-polish task:

- Replace temporary brand assets with a production favicon and 1200 x 630 Open Graph image.

## Phase 1: Real accounts and persistent data

**Status: Implemented; development environment validation is in progress**

Implemented:

- Migrated to React, TypeScript, and Vite.
- Added Supabase Auth for email registration and password login.
- Added persistent profiles and automatic profile creation.
- Added adult birth-date validation in the database.
- Added persistent places and `profile_places`.
- Enforced a maximum of five pinned places.
- Added initial RLS policies.
- Added local environment configuration using `.env.local`.
- Added a profile-completion prompt and required main profile photo before discovery.
- Added two optional extra profile photos and up to five predefined interest tags.
- Added a development-only Makati seed script with synthetic accounts and avatars.

Still required before calling Phase 1 production-ready:

- Password-reset user interface.
- Account deletion through a protected server-side function.
- User data export.
- Automated RLS integration tests.
- Profile-photo moderation and trusted server-side image processing.

Acceptance gate:

- Two verified accounts can register on separate devices, create profiles, pin the same place, and see persisted data after signing out and back in.

## Phase 2: Real matching, chat, and meetup proposals

**Status: Implemented in source, pending Supabase integration testing**

Implemented:

- Shared-place candidate discovery.
- Like and pass decisions.
- Atomic mutual-match creation.
- Participant-only match lists.
- Realtime chat through Supabase Realtime.
- Unread counts and read timestamps.
- Structured meetup proposals.
- Accept and decline actions.
- Blocking and reporting.
- RLS policies for new tables.

Hardening work before closed beta:

- Add swipe and message rate limits.
- Add pagination for messages and candidate results.
- Add optimistic-send reconciliation and user-visible retry states.
- Add reconnect handling for Realtime subscriptions.
- Prevent meetup status changes that violate the state model.
- Add database tests for concurrency and duplicate mutual likes.
- Replace prompt-based reporting with a structured accessible dialog — implemented; local database verification pending.
- Replace public Nominatim calls with a production geocoder and cache.

Acceptance gate:

- Two verified users sharing a place can discover each other, create exactly one mutual match under concurrent likes, exchange authorized realtime messages, submit and respond to a meetup proposal, and stop all interaction after a block.

## Phase 3: Trust and safety

**Status: In progress — authorization, report capture, and the initial admin/moderator dashboard are implemented in source; database verification pending**

Estimated implementation: 4 to 6 weeks for one developer, with moderator-policy work in parallel.

### Engineering

- Verify the protected moderator/admin dashboard, report queue, aggregate stats, name/email search, and reversible account deactivation (`015_admin_dashboard.sql`).
- Add report evidence snapshots, moderator roles/actions, and immutable audit logs — schema and report submission implemented; local database verification pending.
- Enforce block behavior across discovery, matches, messages, meetups, notifications, and profile access.
- Add server-side rate limits for sign-up, swipes, messages, reports, and place search.
- Add spam heuristics and account-risk flags.
- Harden existing Supabase Storage photo uploads with server-side MIME, size, and dimension validation, moderation, and a review workflow.
- Add image moderation and a manual review queue.
- Add optional selfie verification and verified-profile status.
- Add user mute in addition to block.
- Add safety tips before the first accepted meetup.
- Add a shareable meetup plan that excludes unnecessary private information.
- Add suspected-minor escalation and immediate account restriction.

### Operations

Define and publish:

- Report severity levels.
- Moderator response targets.
- Emergency escalation process.
- Evidence-retention periods.
- Appeals process.
- Moderator access controls.
- Law-enforcement request handling.
- User-notification templates.

Suggested beta targets:

- Imminent-danger reports: immediate escalation.
- Suspected-minor and impersonation reports: initial review within 4 hours.
- Harassment and spam reports: initial review within 24 hours.
- All moderator actions recorded in an audit log.
- Account deactivation retains data, prevents app operations, and is reversible by an authorized admin.

Acceptance gate:

- A trained moderator can triage, investigate, action, and close a report without direct database access, while all sensitive actions are logged.

## Phase 4: Closed beta and launch preparation

**Estimated duration: 3 to 5 weeks after Phase 3 release gate**

- Select one dense launch district rather than all of Metro Manila. Candidate options include BGC, Makati CBD, or Poblacion.
- Deploy separate development, staging, and production Supabase projects.
- Add Sentry error monitoring and uptime checks.
- Add consent-aware analytics for sign-up completion, pins, candidate coverage, matches, first messages, meetup proposals, reports, and retention.
- Add CI using GitHub Actions for type checking, build, tests, and migration validation.
- Add Playwright browser tests for registration, discovery, matching, chat, block, and report.
- Add Postgres/RLS tests using Supabase CLI and pgTAP.
- Add privacy, terms, and community documents reviewed for the launch jurisdiction.
- Add backup restoration testing and a rollback runbook.

Suggested beta release gates:

- At least 20 eligible candidates for most active users.
- At least 50% of shown candidates share a pinned place.
- No known high-severity RLS bypass.
- Block enforcement passes every integration test.
- Moderator coverage exists during the published response window.

## Phase 5: Growth features

Re-rank after beta data:

- Push and email notifications.
- Place pages and venue partnerships.
- Profile prompts and preference filters (interest tags are already implemented).
- Group hangouts and double dates.
- Event-based matching.
- Premium features such as extra pins, boosts, and “see who liked you.”
- Multi-language and local-currency support.
- PWA installation and later native wrappers if retention supports the investment.

Do not implement live “I’m here now” check-ins until expiry, visibility, rate limiting, abuse handling, and emergency-disable controls are designed and tested.

## Metrics from the first beta

- Sign-up completion rate.
- Median time to first pinned place.
- Places pinned per active user, initial target 3 or more.
- Eligible candidates per active user.
- Shared-place candidate coverage.
- Like-to-match conversion.
- First-message rate.
- Meetup proposals sent and accepted.
- Reports per 1,000 active users.
- Median moderation time by severity.
- Day 7 and day 30 retention.
- Message-send and Realtime-delivery error rate.

## Main risks

| Risk | Mitigation |
|---|---|
| Thin user density | Launch in one dense district, use invited cohorts, measure eligible candidates before expansion |
| Safety incident | Complete Phase 3 before public launch, publish response targets, maintain escalation coverage |
| Location privacy leak | Do not expose exact live locations; use shared place context and coarse distance bands only |
| RLS misconfiguration | Automated policy tests, separate Supabase environments, security review before production |
| Public Nominatim limits | Migrate to Mapbox Search, Google Places, HERE, or a cached server-side provider |
| Spam or harassment | Rate limits, risk flags, block/mute enforcement, trained moderation |
| Fake profiles | Photo controls, optional verification, rate limits, report tooling |
| Duplicate or inconsistent match state | Database uniqueness constraints and concurrency integration tests |

## Detailed implementation plan

The execution-level Phase 3 plan, weekly schedule, migration sequence, test expectations, release gates, and initial tickets are maintained in `docs/PHASE-3-IMPLEMENTATION-PLAN.md`.
