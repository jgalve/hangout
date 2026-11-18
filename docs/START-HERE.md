# Start Here

1. Open this folder in Visual Studio Code.
2. Run `npm install`.
3. If `.env.local` does not already exist, copy `.env.example` to `.env.local`.
4. Add the Supabase project URL and publishable key without overwriting existing environment values.
5. On a disposable local Supabase project, apply SQL migrations in order:
   - `supabase/migrations/001_initial.sql`
   - `supabase/migrations/002_matching_chat_safety.sql`
   - `supabase/migrations/003_fix_profile_places_insert_policy.sql`
   - `supabase/migrations/004_profile_interests_and_photos.sql`
   - `supabase/migrations/005_require_profile_photo.sql`
   - `supabase/migrations/006_additional_profile_photos.sql`
   - `supabase/migrations/007_authorization_hardening.sql`
   - `supabase/migrations/008_moderation.sql`
   - `supabase/migrations/009_dating_intentions.sql`
   - `supabase/migrations/010_place_stories.sql`
   - `supabase/migrations/011_discovery_one_card_per_person.sql`
   - `supabase/migrations/012_gender_discovery_preferences.sql`
   - `supabase/migrations/013_discovery_profile_age_zodiac.sql`
   - `supabase/migrations/014_hangout_personality.sql`
   - `supabase/migrations/015_admin_dashboard.sql`
   - `supabase/migrations/016_hangout_personality_one_word.sql`
   - `supabase/migrations/017_custom_hangout_personality.sql`
   - `supabase/migrations/018_manual_identity_verification.sql`
   Do not apply migrations 007–018 to a hosted project until the full database suite passes against a disposable database.
6. Run `npm run typecheck`, `npm run build`, and `npm run dev`.
7. For synthetic Makati discovery data, follow the "Seed Makati discovery profiles" section in `README.md`.
8. `npm install` installs the project-scoped Supabase CLI. Install and start Docker Desktop, then start a disposable local stack with `npm run db:start` and run `npm run test:db`. All database test files run. Do not run `supabase db reset` if the local database contains data you need; it reapplies migrations by resetting that database.
9. Read `docs/HANDOFF.md` for current Phase 3 status and remaining work.

Never place a Supabase service-role key in a `VITE_*` environment variable.

## Phase 3

Read `docs/PHASE-3-IMPLEMENTATION-PLAN.md` for the release plan and remaining tickets. Migrations 007–016 require full local database test verification before applying to a hosted project.
