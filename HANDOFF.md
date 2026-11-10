# HangOut: Developer Handoff

Last updated: 10 Nov 2026. Covers the single-file prototype in `index.html`.

## 1. Product in one paragraph

HangOut is a dating app where matching starts from **shared hangout places**, not photos. A user pins up to 5 places, sees people who share them, swipes interested or not now, and on a mutual match can chat and propose meeting at the shared place. Competitors and references: Tinder, Bumble. Brand personality: friendly, trustworthy, innovative. Main goal of the site: sign-ups.

## 2. How the prototype is built

- One file, `index.html`: HTML, CSS (variables in `:root`) and vanilla JS in one IIFE. No framework, no build.
- **Routing**: hash routes. Each `<section class="page" data-page="...">` is shown or hidden by `route()`. Routes: `home`, `how-it-works`, `places`, `safety`, `join`, `account`. `account` requires a session, otherwise it redirects to `join`; `join` redirects to `account` when logged in.
- **Meta tags**: the `META` object holds the title and description per route, and `route()` updates `<title>`, `description`, `og:title` and `og:description` on navigation.
- **Accessibility**: skip link, visible `:focus-visible` outlines, the `<main>` receives focus on route change, tabs use `role="tablist"`, status messages use `role="alert"` or `role="status"`, and buttons are provided alongside swipe gestures.

### Code map (inside the `<script>`)

| Section | What it does |
|---|---|
| `CONFIG` | `FB_APP_ID`, `MAX_SPOTS` |
| `META` and `ROUTER` | route table, `route()`, mobile menu toggle |
| `AUTH` | tabs (sign up / log in), `hash()` (salted SHA-256 via `crypto.subtle`), `startSession()` |
| Facebook login | loads the FB SDK, `FB.login`, creates or reuses a local user |
| `PLACES` | Nominatim `search` and `reverse` calls, `addSpot()`, `renderAccount()` |
| Match preview | `SAMPLE` people, `people(u)`, `react()`, `drag()`, `renderMatches()` (swipe deck, matches list, chat) |

### Storage (all in `localStorage`)

- `ho_session`: `{ email, name }`
- `ho_users`: map of email to user object:

```js
{
  email, name,
  salt, hash,            // email accounts only
  fb,                    // Facebook id, FB accounts only
  spots: [{ name, lat, lon }],
  reacts: { [personId]: 'like' | 'pass' },
  chats:  { [personId]: [{ me: boolean, t: string }] },
  blocked:{ [personId]: 1 }
}
```

### What is fake

- `SAMPLE` people (6 hard-coded names) are generated around the user's own pins. Which ones "like you back" is a deterministic pseudo-random function (`seeded`).
- Chat replies are canned and sent after 1.2 s.
- "Report" shows a message only.

## 3. Known issues and gaps

Security and privacy (must fix before real users):
1. **Auth is client-side only.** Anyone can read or edit `localStorage`. Replace with a real auth provider.
2. **Facebook login does not verify the token** on a server. The placeholder email `fb_<id>@facebook.local` is used when Facebook gives no email.
3. **Raw latitude and longitude are stored** for each place. In production show only place name plus a coarse distance band, and never expose exact user location.
4. No age gate (18+), no consent flow, no Privacy Policy or Terms pages. Needed for launch, and for GDPR or the data-protection law of each launch country.

Product and technical:
5. Place search is one request per submit (no autocomplete) to respect the Nominatim policy. No caching or retry.
6. Nominatim usage must stay light. Production needs a proper geocoder.
7. **Chat input can lose typed text** when a canned reply arrives, because `renderMatches()` rebuilds the whole chat panel. A real build should append messages instead of re-rendering the panel.
8. After sending a message the input loses focus for the same reason.
9. Meta tags are updated by JavaScript, so social-media scrapers and some crawlers only see the Home defaults. Pre-render per-page HTML for real SEO and share previews.
10. `og:image` is a placeholder URL.
11. Hash routing works for a prototype but real pages (`/safety`, `/places`) are better for SEO.
12. No automated tests. The script passed a syntax check only. It has not had a full browser pass on real devices.
13. Photos are not supported yet. Cards use an initial in a circle.
14. Light mode only. No dark theme.

## 4. Recommended next architecture

Keep the visual design, and move to a project with real structure:

- **Front end**: Vite + a framework (React or Svelte) or keep vanilla modules. Split `index.html` into `pages/`, `components/`, `lib/` and `styles/tokens.css`. Move the CSS variables into the token file unchanged.
- **Backend**: Supabase (Postgres, Auth, Realtime, Storage, Row Level Security). It gives email login, Facebook OAuth, and realtime chat with the least custom server code.
- **Geo**: PostGIS for distance queries. Store places by OpenStreetMap id so two users who pin the same real place match exactly.
- **Hosting**: Cloudflare Pages or Vercel for the front end.

### Suggested Postgres schema (sketch)

```sql
create extension if not exists postgis;

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  first_name text not null,
  birth_date date not null check (birth_date <= current_date - interval '18 years'),
  bio text,
  created_at timestamptz default now()
);

create table places (
  id bigserial primary key,
  osm_type text not null,
  osm_id bigint not null,
  name text not null,
  geog geography(point, 4326) not null,
  unique (osm_type, osm_id)
);

create table profile_places (
  profile_id uuid references profiles on delete cascade,
  place_id bigint references places,
  primary key (profile_id, place_id)
);

create table swipes (
  swiper_id uuid references profiles on delete cascade,
  target_id uuid references profiles on delete cascade,
  direction text not null check (direction in ('like','pass')),
  created_at timestamptz default now(),
  primary key (swiper_id, target_id)
);

create table matches (
  id bigserial primary key,
  user_a uuid references profiles on delete cascade,
  user_b uuid references profiles on delete cascade,
  created_at timestamptz default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);

create table messages (
  id bigserial primary key,
  match_id bigint references matches on delete cascade,
  sender_id uuid references profiles,
  body text not null check (length(body) <= 2000),
  created_at timestamptz default now()
);

create table blocks (
  blocker_id uuid references profiles on delete cascade,
  blocked_id uuid references profiles on delete cascade,
  primary key (blocker_id, blocked_id)
);

create table reports (
  id bigserial primary key,
  reporter_id uuid references profiles,
  reported_id uuid references profiles,
  reason text, created_at timestamptz default now()
);
```

Implementation notes:
- Create a `matches` row with a trigger or Edge Function when two `like` swipes exist in both directions.
- Turn on Row Level Security for every table. Users can read and write only their own profile, places and swipes. Messages are readable only by the two people in the match. Exclude blocked users from every query.
- Candidate query: profiles that share at least one `place_id` with the viewer, or whose places are within N km, excluding existing swipes and blocks, ranked by number of shared places, then distance.
- Never return exact coordinates to other users. Return the shared place name and a distance band such as "under 1 km".

### Mapping prototype functions to backend work

| Prototype | Replace with |
|---|---|
| `store()` / `ho_users` | Supabase Auth plus `profiles`, `profile_places` |
| `hash()` and `AUTH` | `supabase.auth.signUp / signInWithPassword` |
| Facebook block | `supabase.auth.signInWithOAuth({ provider: 'facebook' })` |
| `addSpot()` | upsert into `places`, insert into `profile_places` |
| `people(u)` | candidate query (RPC) |
| `react()` | insert into `swipes` |
| `renderMatches()` chat | `messages` table plus Realtime subscription |

## 5. Testing checklist before showing anyone

- Sign up, log out, log in (right and wrong password), duplicate email.
- Facebook login with a real App ID on https.
- Place search for a few cities, "no results", offline, and location permission denied.
- Pin 5 places, try a 6th, remove one.
- Swipe by drag (touch and mouse) and by buttons. Check keyboard-only use and a screen reader on the deck and chat.
- Widths from 360px up. Check contrast and focus visibility.
- Menu toggle on mobile. Back and forward browser buttons on every route.

## 6. Open decisions for the product owner

1. Launch city or region (drives place coverage and moderation).
2. Photos: required, optional, or verified?
3. Gender and preference model (who sees whom).
4. Free vs paid: what, if anything, is premium.
5. Moderation: who reviews reports, and the response time promised on the Safety page.
6. Legal entity, privacy policy and terms wording.
