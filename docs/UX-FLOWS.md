# UX Flows (project template)

## Primary users and jobs-to-be-done
TBD

## Key journeys
Document entry points, steps, decision states, validation, error/empty/loading/success states, and navigation return paths.

### Sign up or log in with a social provider
- Choose Google or Facebook from either the sign-up or log-in screen and return to HangOut through the configured Supabase Auth redirect.
- A social account without a first name or recorded 18+ confirmation must complete account setup before accessing the app. Existing email/password registration and login remain available.
- Show provider cancellation/configuration errors on the auth screen. Do not silently link accounts by matching email addresses in app code.

### Reset a forgotten password
- From Log in, choose **Forgot your password?**, enter an email address, and request a reset link. Always use the same confirmation whether or not an account exists for the address.
- Supabase sends the reset email and returns the user to the configured HangOut login URL. A valid recovery session shows a form to enter and confirm a new password of at least eight characters.
- Show loading, validation, expired-link, and update errors accessibly. After a successful update, let the user continue into HangOut. Never log or expose password values.

### Set gender identity and discovery preferences
- Gender identity is optional. Users may choose Woman, Man, Non-binary, Self-described, or Prefer not to say. Self-described identity requires a short description (up to 50 characters).
- Interested-in preferences are separate from identity. Users may select one or more categories, or keep the default Open to everyone.
- Discover uses preferences mutually for disclosed categories. A profile that does not disclose identity may still appear; never infer or require gender identity.
- Gender identity, dating intention, and bio are shown in a profile popup opened from a Discover card, not on the card itself. Preference settings are private and are not returned for other users.

### View a profile from Discover
- Select a Discover card to open the person's full profile in a dialog; swipe actions remain separate.
- The dialog shows their age and zodiac sign, photos, bio, dating intention, disclosed gender identity, Hangout personality, and shared places with any place stories. It does not expose their exact birth date or private discovery preferences.
- Close the dialog or press Escape to return to the same Discover list.

### Start a conversation with a match
- Select a match to open its message history. Show the match's profile photo beside their name in the match list and active chat header, falling back to their initial if the photo is unavailable. Show three unique opening lines randomly selected from a curated list of 15 only after an empty history has loaded successfully.
- Selecting an opening line fills the message composer without sending it; users can edit it or choose another line before sending.
- Hide opening lines when the conversation already has messages or its history could not be loaded.
- In an active conversation, **View profile** reopens the match's profile dialog with their shared profile details and places. Do not expose their exact birth date or private discovery preferences. The server returns profile data only to an active, unblocked mutual match.
- Optionally add Facebook, Instagram, and TikTok profile URLs in Profile. Only an active mutual match can retrieve or open these links; do not return them in Discover profile data.

### Choose a Hangout personality
- Choose three to five predefined one-word options that describe the kinds of hangouts you enjoy: Coffee, Explore, Foodie, Music, Culture, Markets, Parks, Fitness, Games, Nightlife, Nature, or Community. Optionally add up to three unique custom one-word personalities, separated by commas; each can be up to 30 characters and is additional to the predefined choices.
- A profile needs at least three predefined choices to access Discover; the optional custom personality does not count toward that requirement. Existing interest selections are preserved separately and are not converted into personality choices.

### Request manual ID review
- In Profile, users may optionally upload a clear photo of a government-issued photo ID after acknowledging that admins and moderators can review it.
- The image is re-encoded as JPEG to remove metadata, stored in a private bucket, and visible only to authorized admins/moderators while the request is pending. Users may withdraw a pending request.
- Admins and moderators approve or reject the request. The image is deleted after a decision or withdrawal; if deletion fails, the request remains visible as a cleanup task and no Verified badge appears until cleanup succeeds.
- Rejected users may submit a new image. Only the review status and audit events remain after image deletion; ID numbers and document contents are not copied into profile data.
- The public Verified badge means a HangOut admin or moderator reviewed a government-issued photo ID. It does not imply a background check or safety guarantee.

### Filter Discover by shared place
- Choose a shared place from the Discover filter to show only loaded candidates who share it.
- The filter defaults to **All places**. If no loaded candidate shares the selected place, show an empty message and allow switching back to **All places** or another place.
- Discover shows up to five popular hangouts, ranked by distinct active users who pinned each place, and up to five trending hangouts, ranked by distinct active users who pinned each place in the last seven days. The rankings expose aggregate counts only, not member identities.
- Ranked places are informational; each has a **Pin hangout** button that adds the place to the signed-in user's profile. Show an already-pinned state, respect the five-place limit, and report errors. Pinning a ranked place does not change the Discover filter.
- Show loading, empty, and error states for the rankings and the user's existing pins.
- Place the single published featured hangout between Popular and Trending. Show its configured venue, pair-focused promo copy, optional photo, terms, and optional HTTPS call-to-action. Use a labeled photo placeholder when no image is configured.
- The featured card links to its selected OpenStreetMap place and lets the signed-in user pin that same place. Show already-pinned, pinning, five-place-limit, and error states; keep the map link and pin target tied to one catalog record.
- At the bottom of Discover, invite friends using only the public marketing homepage (`/`), never profile details or signed-in Discover content. Offer the device share sheet when supported, copy link, WhatsApp, Facebook, X, and email; show decorative Lucide icons beside visible action labels, and Messenger may be selected from the device share sheet when available. Announce copy success and errors, and treat share-sheet cancellation as a normal dismissal.
- The featured section reads only published content for an active signed-in user. An unpublished draft is available only through the admin workspace.
- The initial Solaire Pasay promo is sample content, prominently labeled as not a real offer, not redeemable, and not affiliated with the venue. Keep the sample-only marker until actual offer details are confirmed.

### Admin and moderator dashboard
- Only accounts with a server-validated moderator or admin role can open the operations workspace.
- Admins can view aggregate user, match, and report counts and search users by name or email. Email lookup is available only through an admin-authorized server function.
- Admins can deactivate or reactivate an account with a required reason. Deactivation is reversible, retains account and safety data, and denies app operations; it does not permanently delete the Auth account.
- Admins can configure the single featured Discover hangout by selecting a place from the catalog, then edit its display name, promo copy, terms, optional HTTPS photo and call-to-action, sample-only status, and publish state. Database functions enforce admin access; clients cannot read or write the settings table directly.
- Moderators can review reports, view their limited evidence snapshots and action history, and move cases to reviewing, resolved, or dismissed.
- Unauthorized users cannot access dashboard data or actions by calling the database API directly. Show loading, empty, and error states for each queue or search.

### Pin a hangout place
- Search by name or choose **Use current location**; the browser requests permission before location is read.
- For location lookup, coordinates are sent to OpenStreetMap Nominatim to find a nearby named place. Show the result and require the user to select it before pinning; never save the raw device coordinates as the user's place.
- Explain the location sharing before the action, and show clear permission, lookup, duplicate-place, and save errors.
- Optionally add a place story of up to 280 characters. Make clear it is shown to people who share that place; do not make a story required to pin a place or discover people.

## Responsive considerations
- Mobile (up to 600px): Keep app pages single-column, use a 0.5rem page gutter and compact panel/card padding, and reduce vertical gaps. Keep primary app navigation fixed to the bottom as icon-only controls with accessible names, safe-area padding, and enough reserved content space to prevent overlap. Keep buttons, navigation, and form controls at least 44px tall. Allow long content to wrap; use horizontal scrolling only for compact navigational lists such as the match picker.
- Tablet (from 760px): Use available width for two-column content where useful, including Discover cards.
- Desktop (from 1024px): Use three-column Discover cards; at 1200px and wider use four columns. Cap the app shell at 1440px.
- New screens and components must follow the shared breakpoints and compact-mobile sizing in `src/styles.css` and `docs/DESIGN-SYSTEM.md`. Check narrow (320–375px), tablet, and desktop widths; avoid horizontal overflow and preserve touch target sizes.

## Accessibility
Keyboard sequence, focus management, labels, status announcements, contrast and motion considerations.
