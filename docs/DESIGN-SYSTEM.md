# Design System

Status: HangOut Design System v1.0 is the approved visual direction.

## Brand
- Brand statement: Meet through places. Discover through experiences. Belong through community.
- Product and audience: A community-first social discovery platform for people connecting through shared places and experiences.
- Brand traits: Friendly, trustworthy, local, welcoming, exploratory, modern.
- Principles: Human before algorithm; safe by default; place-centered discovery; warm and approachable; real-world experiences matter.

## Visual direction
- Use a warm, light neutral canvas with coral actions and teal place/community accents.
- Favor clear hierarchy, welcoming language, readable content, and photo-forward discovery.
- Avoid generic gradients, redundant decoration, unsupported verification claims, exaggerated shadows, and unnecessary visual density.
- Use the supplied HangOut logo lockup at `public/hangout-logo.png` on light surfaces and `public/hangout-logo-white.png` in the dark marketing footer. Preserve each image's aspect ratio and original colors; do not crop, recolor, or recreate either logo.

## Design tokens

### Color
- Primary coral: `#FF6B4A`
- Secondary teal: `#1F9D8B`
- Neutral scale: `#FAFAF8`, `#F5F4F1`, `#E7E4DE`, `#D5D0C7`, `#686259`, `#23201C`
- Semantic success: `#2BAF66`; warning: `#F2A93B`; error: `#E85C5C`; info: `#4589FF`
- Use darker text variants on pale brand/semantic surfaces when needed for contrast. The supplied white-on-coral button pairing is below WCAG AA for normal text; HangOut uses dark ink on the coral fill and a darker coral for text or hover states.
- Form boundaries and focus indicators must remain distinguishable; do not use the pale neutral border as the only boundary for interactive controls.

### Typography
- Headings: Plus Jakarta Sans, 600–800.
- Body and controls: Inter, 400–700.
- Web fonts load from Google Fonts; system sans-serif fallbacks keep content readable if the request fails.
- Scale: display 48px; H1 36px; H2 30px; H3 24px; body 16px; caption 14px. Keep responsive sizing within these proportions.

### Spacing, shape, and layout
- Use an 8-point spacing grid: 4, 8, 16, 24, 32, 48, and 64px.
- Radius tokens: small 8px, medium 16px, large 24px. Use 16px for primary buttons and 24px for major surfaces.
- Preserve the 1440px app shell and 1120px marketing content width. Discover uses two columns on tablet, three on standard desktop, and four at 1200px and wider.
- Compact mobile is 600px and below; tablet layout starts at 760px; wide desktop starts at 1024px. Keep mobile layouts compact, single-column where practical, and free of horizontal overflow.
- On signed-in mobile screens, preserve fixed bottom icon navigation, accessible names, safe-area padding, 44px minimum interactive targets, and scroll space below the content.

## Components and product-specific behavior
- Navigation: Discover, Matches, Meetups, and Profile; role-authorized Admin access may be added for staff. Active navigation uses a pale coral surface and a contrast-safe foreground. Show the signed-in user's name as plain text with a separate Log out button after it; do not make the name a dropdown.
- Buttons: Coral primary action with dark ink text; white secondary action with a neutral border. Use visible hover, focus, disabled, loading, and error states.
- Cards: Prioritize profile photo, name, HangOut personality, shared-place names, and existing clear actions. Do not invent distance or match-score data; exact location is not exposed.
- Safety: Keep report and block tools easy to find. Do not claim that accounts are verified unless verification is implemented and the status is trustworthy.
- Preserve existing privacy, authorization, and matching behavior while applying the visual system.
- Loading, empty, success, validation, and error states must remain explicit and accessible.
- Target WCAG 2.2 AA. Honor `prefers-reduced-motion` for new motion.

## Approval and change log
- 2026-11-10: Café Social was adopted as the interim visual direction.
- 2026-11-13: Discover cards were refined around the supplied photo-forward reference and existing profile data.
- 2026-11-17: Adopted the supplied HangOut Design System v1.0, replacing the Café Social palette and typography. Shared app and marketing styles now use Coral, Teal, Plus Jakarta Sans, and Inter. Dark ink replaces white on coral primary buttons to meet text contrast requirements.
