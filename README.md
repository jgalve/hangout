# HangOut

Hangout place dating. Users pin the places they love (cafés, parks, venues) and meet people who hang out there too.

This repo is currently a **front-end prototype**: one self-contained `index.html`, no build step, no server. Accounts, places, swipes and chats are stored in the visitor's own browser (`localStorage`), and the people they meet are sample data. A backend is needed before real users can match with each other (see `docs/HANDOFF.md` and `docs/ROADMAP.md`).

## What works today

| Area | Status |
|---|---|
| Marketing pages: Home, How it works, Places, Safety | Done |
| Email sign up / log in | Works locally (demo only, not secure) |
| Facebook login | Wired up, inactive until `FB_APP_ID` is set |
| Place search and "use my location" | Works (OpenStreetMap Nominatim, free) |
| Pin up to 5 hangout places | Works |
| Swipe deck (drag or buttons) | Works on sample people |
| Matches and chat | Works on sample people with canned replies |
| Block / report | Block works locally, report is a placeholder |
| Real users, real matching, real messages | Not built (needs backend) |

## Run it locally

Open `index.html` in a browser for most things. Facebook login needs `https://` or `localhost`, so serve it:

```bash
npx serve .
# or
python3 -m http.server 8000
```

Then visit `http://localhost:8000`.

## Configure

Edit the `CONFIG` block at the top of the `<script>` in `index.html`:

- `FB_APP_ID`: your Facebook App ID. In the Facebook developer dashboard, enable Facebook Login and add your domain (and `http://localhost`) to the valid OAuth origins.
- `MAX_SPOTS`: how many places a user can pin (default 5).

Also replace the placeholder `og:image` URL in the `<head>` with a real 1200×630 image.

## Deploy

It is a static file, so any static host works: Netlify, Vercel, Cloudflare Pages, GitHub Pages. Upload `index.html` (and add a real `og:image`).

## Project layout

```
index.html          the whole app: HTML, CSS and JS
README.md           this file
docs/HANDOFF.md     architecture, data model, code map, known issues, backend plan
docs/ROADMAP.md     phased plan from prototype to launch and beyond
```

## Design system (CSS variables in `:root`)

- Colours: `--ink` #1B1740, `--pin` #C8135A, `--mint` #BFF0D4, `--sun` #FFD84D, `--paper` #FBFAFF
- Fonts: Bricolage Grotesque (headings), Figtree (body), loaded from Google Fonts with system fallbacks
- Shape: pill buttons, 28px card corners, map-pin motif, light mode only
- Motion: pins drop in once on the home hero; `prefers-reduced-motion` is respected

## Third-party services

- **OpenStreetMap Nominatim**: free geocoding. Usage policy: max 1 request per second, no heavy or autocomplete-style use, show attribution (the footer does). For production traffic, move to a self-hosted Nominatim or a commercial geocoder.
- **Facebook JavaScript SDK**: login.
- **Google Fonts**.

## Status and caveats

The prototype has not been through automated tests or a full cross-browser check. Do not collect real personal data with it: passwords are hashed in the browser only and there is no server-side protection. Read the "Known issues" section of `docs/HANDOFF.md` before building on it.
