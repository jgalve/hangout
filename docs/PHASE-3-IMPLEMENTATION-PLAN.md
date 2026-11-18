# HangOut Phase 3 Implementation Plan

Last updated: 11 November 2026

## 1. Objective

Phase 3 turns the Phase 2 closed-beta code into a safety-operable product. The release goal is not merely to add moderation screens. It is to ensure that blocking, reporting, moderation, account controls, photos, and abuse controls are enforced on the server and validated with automated tests.

Target duration: **6 weeks** for one experienced full-stack developer, plus part-time product/legal review and a named moderator or safety owner.

## 2. Release outcomes

Phase 3 is complete only when:

1. Blocking immediately prevents new messages, meetup changes, discovery, and match access in both directions.
2. All meetup state changes occur through validated database functions.
3. Reports preserve relevant evidence and enter a moderator queue.
4. Moderator actions are role-restricted and written to an immutable audit log.
5. Message, swipe, report, sign-up, and place-search abuse controls exist.
6. Profile-photo upload has type, size, authorization, and moderation controls.
7. Password reset, account deletion, and data export are available.
8. Automated RLS, database, component, and end-to-end tests pass in CI.
9. The staging environment has monitoring, backup, rollback, and incident runbooks.

## 3. Scope boundaries

### Included

- Block-aware database authorization
- Validated meetup state machine
- Structured reporting and evidence capture
- Moderator roles, queue, actions, and audit history
- Message and swipe limits
- Profile-photo upload and review workflow
- Password reset, data export, and account deletion
- Supabase Edge Functions where elevated server authority is required
- Vitest, React Testing Library, Playwright, Supabase CLI, and pgTAP tests
- GitHub Actions CI
- Sentry frontend monitoring
- Moderator and incident-response documentation

### Deferred

- Paid subscriptions and boosts
- Live check-ins or “I’m here now”
- Group hangouts
- Native iOS or Android applications
- Machine-learning ranking
- Full automated identity verification
- Large-scale venue partnerships

## 4. Workstreams

### Workstream A: Authorization hardening

**Priority: Critical**  
**Target: Week 1**

#### Database changes

Add authorization hardening in a new migration after the existing `001`–`006` baseline (planned number: `007_authorization_hardening.sql`):

- Replace `are_matched(match_uuid, user_uuid)` with a helper that also rejects blocked pairs.
- Update message `SELECT`, `INSERT`, and `UPDATE` policies to use the block-aware helper.
- Update meetup policies to reject blocked participants.
- Prevent direct client updates to meetup status.
- Add a `respond_to_meetup(proposal_id, action)` security-definer function.
- Add a `cancel_meetup(proposal_id)` function that limits pending cancellations to the proposer and allows either participant to cancel an accepted meetup.
- Add a `change_meetup(...)` function that creates a new pending revision rather than silently overwriting accepted details.
- Revoke unnecessary table privileges after RPC functions are available.
- Add `SECURITY DEFINER`, fixed `search_path`, explicit ownership, and narrow `GRANT EXECUTE` rules to every privileged function.

Implementation is present in `supabase/migrations/007_authorization_hardening.sql`, with client integration in `src/components/MatchesChat.tsx` and `src/components/Meetup.tsx`. The user reports that pgTAP assertion 22 passed; apply to a disposable local database and verify the full suite before applying the migration to a hosted project.

Report capture is implemented in migration 008 and `src/components/ReportDialog.tsx`. The RPC validates match participation and category, limits message evidence to 20, and stores a profile snapshot. Its pgTAP suite is `supabase/tests/database/moderation.test.sql`; run it locally before hosted application.

#### Required state transitions

| Current state | Actor | Allowed next state |
|---|---|---|
| pending | Recipient | accepted, declined |
| pending | Proposer | cancelled |
| accepted | Either participant | cancelled |
| accepted | Either participant | changed through a replacement pending proposal |
| declined | Any | No direct transition |
| cancelled | Any | No direct transition |

#### Tests

- A blocked participant cannot read or insert messages.
- A blocked participant cannot create or update meetup proposals.
- Blocking either direction has the same effect.
- An unrelated authenticated user cannot access match data.
- Invalid meetup transitions fail at the database layer.
- Concurrent reciprocal likes still create exactly one match.

### Workstream B: Structured safety reporting

**Priority: Critical**  
**Target: Weeks 1 and 2**

Moderation schema is implemented after authorization hardening in `008_moderation.sql`; local pgTAP verification remains pending:

- `moderator_roles`
- `report_evidence`
- `moderation_actions`
- `moderation_audit_log`
- Optional `account_restrictions`

Capture evidence at report submission time:

- Reported user ID
- Match ID, when applicable
- Selected message IDs or the latest limited message window
- Reporter-selected category
- Free-text details
- Profile snapshot fields needed for investigation
- Submission timestamp

Do not copy an unlimited conversation into the report. Start with the latest **20 messages** or explicitly selected messages, then adjust after legal and safety review.

The accessible report dialog is implemented in `src/components/ReportDialog.tsx` and includes:

- Category selection
- Optional message selection
- Description, maximum 1,000 characters
- Emergency guidance for imminent danger
- Confirmation and case reference

Initial categories:

- Harassment or threats
- Spam or scam
- Impersonation
- Suspected underage user
- Unsafe offline behavior
- Non-consensual or inappropriate content
- Other

### Workstream C: Moderator and admin console

**Priority: Critical**  
**Target: Weeks 2 and 3**

The initial console is implemented in `src/components/AdminDashboard.tsx`, with role-protected RPCs and reversible account deactivation in migration `015_admin_dashboard.sql`. The console includes:

- Aggregate user, match, and report counts
- Admin-only user search by name or email
- Reversible account deactivation/reactivation with an immutable reason and actor history
- Moderator report queue, limited report evidence, report status transitions, and audit history

Recommended service targets for closed beta:

- Imminent danger: immediate escalation
- Suspected minors and impersonation: initial review within **4 hours**
- Harassment, scams, and unsafe behavior: initial review within **24 hours**
- Lower-severity spam: initial review within **48 hours**

The database functions enforce admin or moderator roles; the client-side role check only controls navigation. Deactivation denies app operations and retains data; it does not delete the Auth user. Run `supabase/tests/database/admin_dashboard.test.sql` and the complete database suite before hosted deployment. Email access is limited to the admin search function.

### Workstream D: Abuse prevention and rate limits

**Priority: High**  
**Target: Week 3**

Implement limits through Supabase Edge Functions, database functions, or gateway controls rather than React-only counters.

Starting limits for beta testing:

| Operation | Initial limit |
|---|---:|
| Sign-up attempts | 5 per IP per hour |
| Login failures | 10 per account/IP per 15 minutes |
| Swipes | 100 per account per 24 hours |
| Messages | 30 per account per minute and 500 per day |
| Reports | 10 per account per 24 hours |
| Place search | 30 requests per account per minute |
| Photo uploads | 10 per account per 24 hours |

Return user-safe `429` responses with retry guidance. Record limit events without storing unnecessary raw personal data. Tune thresholds from beta telemetry.

Add basic risk signals:

- Repeated copy-paste messages across multiple matches
- High block or report rate
- Rapid swipe bursts
- Excessive new-account outbound messages
- Repeated image rejections

Risk signals should trigger review or temporary limits, not automatic permanent bans.

### Workstream E: Profile photos and verification foundation

**Priority: High**  
**Target: Week 4**

The current approved implementation uses a public `profile-photos` bucket. Users have one required main photo and two optional extra photos, stored under their own user folder. Public URLs are accessible to anyone who has the URL. Before launch, ensure this visibility is clearly disclosed and review whether pre-publication moderation is required.

Initial constraints:

- JPEG, PNG, or WebP only
- Maximum **8 MB** per original upload
- Maximum 3 profile photos (one required main photo and two optional extra photos in the current implementation)
- Server-side re-encode before publication
- Strip metadata, including EXIF location
- Generate fixed display sizes
- Reject animated images for the first beta

Add tables for:

- `profile_photos`
- `photo_reviews`
- `verification_requests`, reserved for later selfie verification

Photo states:

- pending
- approved
- rejected
- removed

For Phase 3, implement manual review with optional provider integration deferred until volume justifies it. Never expose an unreviewed photo to unrelated users if the chosen safety policy requires pre-moderation.

### Workstream F: Account lifecycle and privacy controls

**Priority: High**  
**Target: Week 4**

Add:

- Password-reset request and update screens
- Account-deletion request
- Data-export request
- Session revocation
- Downloadable export containing profile, places, swipes, matches, messages, meetups, blocks, and reports submitted by the user, subject to safety and legal retention rules

Deletion design:

- Immediately remove the account from discovery.
- Revoke active sessions.
- Delete or anonymize user-generated data according to an approved retention matrix.
- Preserve restricted report evidence only when required for safety, disputes, or legal obligations.
- Delete Storage objects and derived image sizes.

Implement deletion and export in Edge Functions or another trusted backend. Do not expose service-role credentials to the browser.

### Workstream G: Quality, CI, and observability

**Priority: Critical**  
**Target: Weeks 5 and 6**

Add tooling:

- ESLint with TypeScript ESLint
- Prettier
- Vitest
- React Testing Library
- Playwright
- Supabase CLI
- pgTAP
- GitHub Actions
- Sentry

Required GitHub Actions checks:

1. Dependency installation using `npm ci`
2. Formatting check
3. ESLint
4. TypeScript type check
5. Unit and component tests
6. Vite production build
7. Local Supabase migration reset
8. pgTAP RLS tests
9. Playwright smoke tests

Minimum automated scenarios:

- Registration and email-verification callback
- Adult-date validation
- Five-place maximum
- Shared-place discovery
- Concurrent mutual match
- Authorized and unauthorized messaging
- Realtime reconnect recovery
- Block immediately stops interaction
- Valid and invalid meetup transitions
- Report submission and evidence snapshot
- Moderator authorization
- Account deletion removes discovery access

Add Sentry with environment and release tags. Do not send message bodies, exact coordinates, birth dates, access tokens, or report details to telemetry.

## 5. Six-week delivery schedule

| Week | Deliverables | Exit check |
|---|---|---|
| 1 | Block-aware authorization, meetup RPC state machine, RLS test harness | Critical negative-access tests pass |
| 2 | Structured report dialog, evidence snapshot, moderation schema | Reporter can submit a traceable case; reported user cannot see it |
| 3 | Moderator queue and actions, audit log, initial rate limits | Authorized moderator can action a case; unauthorized user is denied |
| 4 | Photo pipeline, password reset, export and deletion foundation | File policies and lifecycle tests pass |
| 5 | Component and end-to-end tests, CI pipeline, Sentry | Pull requests cannot merge when required checks fail |
| 6 | Full regression, security review, staging deployment, runbooks | Phase 3 release gate completed |

Keep a **20% contingency** within each week for migration defects, RLS debugging, and Realtime race conditions.

## 6. Definition of done

A backlog item is done only when:

- Database migration is reversible or has a documented rollback.
- RLS policy or Edge Function authorization is tested.
- UI includes loading, empty, error, and success states.
- Keyboard and screen-reader behavior is covered for interactive dialogs.
- Sensitive fields are excluded from logs and analytics.
- Product documentation and handoff notes are updated.
- At least one negative-security test proves unauthorized access is denied.
- The feature passes in a fresh Supabase environment created from migrations.

## 7. Environments and deployment

Use separate Supabase projects for:

- Development
- Staging
- Production

Never reuse production user data in development. Seed development with fictional accounts and places.

Recommended branch workflow:

- `main`: protected, deployable
- `develop`: optional integration branch if more than one developer
- Short-lived branches such as `feature/moderation-queue` or `security/block-aware-messages`

Recommended pull-request checks:

- One reviewer for normal changes
- Two reviewers for migrations, RLS, auth, moderation, deletion, or Edge Functions
- Migration and rollback notes included in the PR description

## 8. Phase 3 database migration sequence

The initial product baseline occupies migrations `001` through `006`; current migrations extend through `018`:

```text
supabase/migrations/
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

Do not edit previously applied migration files after another environment depends on them. Add corrective migrations instead.

## 9. Key risks and controls

| Risk | Control |
|---|---|
| Security-definer privilege escalation | Fixed search path, narrow grants, owned functions, pgTAP negative tests |
| Block bypass through direct API calls | Database policy enforcement, not UI-only filtering |
| Moderator abuse | Least privilege, MFA, immutable audit trail, periodic access review |
| Evidence overcollection | Limited message snapshot, documented retention, access logging |
| Photo malware or privacy leak | MIME inspection, re-encode, metadata stripping, private staging bucket |
| Rate-limit evasion | Combine account, IP, device/session, and behavior signals where lawful |
| Accidental production migration | Separate projects, protected CI environment, reviewed deployment job |
| Sensitive telemetry | Explicit Sentry filtering and allowlisted event fields |

## 10. Release gate checklist

- [ ] Fresh staging environment builds from migrations without manual SQL fixes.
- [ ] Type check, lint, unit, database, and Playwright tests pass.
- [ ] Block enforcement passes across messages, meetups, discovery, match lists, and profile access.
- [ ] Report evidence is immutable and visible only to authorized roles.
- [ ] Moderator actions are audited.
- [ ] Rate limits return controlled errors and cannot be bypassed by direct table writes.
- [ ] Photo Storage policies pass owner and non-owner tests.
- [ ] Password reset, export, and deletion are tested.
- [ ] Sentry excludes sensitive content.
- [ ] Backup and rollback procedures are rehearsed in staging.
- [ ] Moderator response process and escalation owner are documented.
- [ ] Privacy, Terms, and Community Guidelines reflect the implemented workflows.

## 11. First implementation tickets

1. `SEC-301`: Make message authorization block-aware — implemented; user reports assertion 22 passed.
2. `SEC-302`: Make meetup access block-aware — implemented; user reports assertion 22 passed.
3. `DB-303`: Add validated meetup transition RPCs — implemented; user reports assertion 22 passed.
4. `TEST-304`: Establish Supabase CLI and pgTAP RLS suite — suite added; assertion 22 reported passing, full local run evidence still needed.
5. `SAFE-305`: Add report evidence schema and submission RPC — implemented; local database verification pending.
6. `UI-306`: Replace report prompt with accessible dialog — implemented; build and interaction verification pending.
7. `SAFE-307`: Verify the moderator report queue and protected status actions in migration 015.
8. `AUDIT-308`: Verify the existing moderation and account-status audit history in the local database suite.
9. `ABUSE-309`: Add message and swipe rate limits.
10. `CI-310`: Add GitHub Actions quality and database checks.
11. `OPS-311`: Verify the admin/moderator dashboard and account deactivation against the full local database suite.

The admin/moderator dashboard and migration 015 are implemented in source; migration and interaction verification remain pending. Run the entire local suite before hosted application.
