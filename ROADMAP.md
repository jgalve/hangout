# HangOut Roadmap

Goal: grow from a front-end prototype to a trusted place-based dating app that earns sign-ups and real matches. Phases are ordered by dependency. Timings are rough estimates for one developer and should be adjusted once the team and launch city are known.

## Phase 0: Prototype hardening (about 1 week)

Make the current file safe to show to testers.
- [ ] Fix chat re-render bug (append messages instead of rebuilding the panel; keep draft text and focus)
- [ ] Add a real `og:image` and favicon
- [ ] Add Privacy Policy, Terms and Community Guidelines pages
- [ ] Add an 18+ confirmation on sign up
- [ ] Test on real phones and in Safari, Chrome and Firefox
- [ ] Add a "prototype, sample people" label on the Account page so testers are not misled

## Phase 1: Real accounts and data (2 to 3 weeks)

- [ ] Move to a Vite project and split `index.html` into components and a tokens file
- [ ] Set up Supabase: Auth (email and Facebook OAuth), Postgres, Row Level Security (schema in `HANDOFF.md`)
- [ ] Email verification and password reset
- [ ] Profile editing: first name, birth date, bio, one or more photos (Supabase Storage)
- [ ] Persist pinned places in `places` and `profile_places` using OpenStreetMap ids
- [ ] Account deletion and data export

Done when: two real people can sign up on two devices and see each other's shared places.

## Phase 2: Real matching and chat (3 to 4 weeks)

- [ ] Candidate query: shared places first, then distance, excluding swiped and blocked users
- [ ] Swipe writes to `swipes`, mutual like creates a `matches` row
- [ ] Realtime chat with Supabase Realtime, unread counts, delivery state
- [ ] "Suggest meeting here" creates a structured meetup proposal that the other person can accept, decline or change
- [ ] Coarse distance bands only, never exact coordinates
- [ ] Replace Nominatim with a production geocoder and add place autocomplete with debounce and caching

Done when: a closed beta group can match and message each other.

## Phase 3: Trust and safety (parallel, ongoing from Phase 1)

This is the brand promise, so it is not optional.
- [ ] Report flow that stores the reason, the chat context and a moderator status
- [ ] Moderation queue and a published response-time target
- [ ] Block and mute that apply everywhere
- [ ] Photo verification (selfie check) and a "verified" badge
- [ ] Rate limits and spam detection on messages and swipes
- [ ] Safety tips shown before a first meetup, plus an optional "share my plan with a friend" link
- [ ] Underage prevention checks and a process for handling suspected minors

## Phase 4: Launch (about 2 weeks, after a closed beta)

- [ ] Pick a launch city and seed it with partner venues and local creators
- [ ] Pre-render pages or use SSR so each page has real meta tags for SEO and share previews
- [ ] Analytics with consent: sign-up conversion, places pinned per user, match rate, first-message rate, 7-day retention
- [ ] Error monitoring and uptime checks
- [ ] App store presence through a PWA first, then native wrappers if the numbers justify it
- [ ] Waitlist or invite codes if supply of users in the city is thin

## Phase 5: Growth features (after launch)

Ordered roughly by expected value, to be re-ranked with real data.
- [ ] Push and email notifications for new matches and messages
- [ ] Place check-ins and "I'm here now" so people can meet spontaneously
- [ ] Group hangouts and double dates at a shared place
- [ ] Place pages: who hangs out here, events, partner offers
- [ ] Interests and prompts on profiles, and filters (age, distance, preferences)
- [ ] Premium tier, for example see who liked you, extra pins, boosts (the brief names Tinder and Bumble, so check how they price)
- [ ] Venue partnerships: sponsored places and first-date offers, kept clearly labelled
- [ ] Multi-language support and local currencies
- [ ] Dark theme

## Phase 6: Longer-term ideas

- Friends and community modes using the same place graph
- Event-based matching (concerts, markets, classes)
- Smarter ranking from conversation and meetup outcomes, with fairness and safety review
- Host tools for venues

## Risks to watch

| Risk | Mitigation |
|---|---|
| Too few users per city, so empty decks | Launch in one dense area, use invites, widen radius gradually |
| Safety incident | Phase 3 work before public launch, clear reporting and fast response |
| Location privacy leak | Coarse bands, RLS, no exact coordinates to clients |
| Geocoder cost or limits | Cache places by OSM id, move off public Nominatim early |
| Facebook login policy or review delays | Start app review early, keep email login as the default |
| Fake profiles | Verification, rate limits, report tooling |

## Metrics to track from the first beta

- Sign-up completion rate and time to first pinned place
- Places pinned per user (target 3 or more)
- Share of swipe candidates with at least one shared place
- Match rate and first-message rate
- Meetup proposals sent and accepted
- Reports per 1,000 active users and median moderation time
- Day 7 and day 30 retention
