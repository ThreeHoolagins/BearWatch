# BearWatch: Working Plan (Claude)

Companion to `HUMAN_PROJECT_PLAN.md` (Caleb's plan; never edited by agents).
This doc records decisions as we make them, open questions, and build phases.

## Status
- **Phase 0 (done):** repo, Docker skeleton, design mockups.
- **Phase 4 (done, branch `phase-2-uploads`):** Ranger station: user search, ban/unban with reason (admins can't ban themselves or other admins), Fat Bear Week wins (one per year, awarded/revoked from the post pop-up, badges on posts and profiles), champion card editor (Bear Watch post or outside photo with credit and link, live preview) shown in the sidebar and as a mobile banner, admin post removal (deletes the stored photo). Alert email verified over Gmail SMTP.
- **Phase 3 (done, branch `phase-2-uploads`):** Global feed (published bears within 500 miles, `ST_Distance_Sphere` with a bounding-box prefilter), Following feed, cursor pagination with infinite scroll, profiles for any user (`/u/:nickname`), follow/unfollow, bear-face avatars (crop + zoom + drag, starting on the detector's bear box).
- **Phase 2 (done, branch `phase-2-uploads`):** photo uploads end to end: magic-byte checks, libvips re-encode to stripped WebP in a no-internet worker, YOLOX-S bear check, place search (Nominatim), rate limits, profile grid. Verified in dev and in the production stack.
- **Phase 1 (done, branch `phase-1-auth`):** Rails 8 API + React SPA; SSO sign-in (Google, GitHub, dev-only developer login), nickname sign-up with live checks and a blocklist, account linking, ban screen, Terms modal, signpost/tab shell. Feeds, posting and admin screens are placeholders until their phases.
- Mockup: `docs/design/mockups.html`, a full clickable site in direction B (desktop + mobile).
  Serve the repo root (`python -m http.server 8787`) and open `/docs/design/mockups.html`.

## Decisions

| # | Topic | Decision |
|---|-------|----------|
| D1 | SSO providers | **Google + GitHub** for v1. Facebook dropped (app review / business verification overhead). |
| D2 | What we store from SSO | Provider name + provider's stable user ID (`sub` / GitHub id) only. **No OAuth tokens stored.** |
| D3 | Account linking | One user can link multiple SSO identities, so a separate `identities` table (not a column per provider). |
| D4 | "Within 500 mi" location | Browser geolocation prompt, sent per request, **never saved**. |
| D5 | Post location | User-entered, rounded to ~10 km (1 decimal place) before saving. Shown as a place name ("Fort Collins, CO" / park name) below the photo. |
| D6 | Fat Bear Wins | Awarded **by hand** by admins to a specific post (the winner of the off-platform Fat Bear Week). Profile count = number of winning posts. |
| D7 | Admin panel | Verified admins only: ban/unban users (with reason), award Fat Bear Week wins to posts. |
| D8 | Bans | Columns on `users` (`banned_at`, `ban_reason`). A banned user who logs in always sees a "banned" screen with the reason. |
| D9 | v1 scope cuts | No likes, no comments, no nickname changes. |
| D10 | Database | MySQL 8.4 (target: AWS/GCP, near-free; Pi 4 as fallback). |
| D12 | Design | **Direction B, "Ranger Station"**: cream paper, wood-sign buttons, Zilla Slab headings, Poppins body. Responsive: bottom tabs on mobile; on desktop, a signpost sidebar nav, a centered feed, and a right column (Fat Bear Week champion + trail rules) on wide screens. |
| D13 | Signpost nav | Kept: desktop nav is a wooden trail signpost; "Post a bear" is the gold sign. |
| D14 | Fat Bear Week card | Champion card is **edited in the admin panel**, not derived from posts: year, bear name/number, blurb, and either a Bear Watch post *or* an outside photo with credit + link (the real winner usually won't be on our site). Shown in the desktop right column and as a tappable banner on mobile feeds. |
| D15 | Sign out | Desktop: dropdown from the nickname in the header (My profile, Admin panel, Terms, Sign out). Mobile: on your own profile page. |
| D16 | Terms of Service | Opens as a modal with a scrolling body and a Close button bottom-right. Linked from login, nickname, sidebar, rail, menu, profile and banned screens. |
| D17 | Nickname filter | Format/length checks plus a blocklist: LDNOOBW English list (CC BY 4.0) with leetspeak normalisation, an allowlist for innocent words ("grape", "button"), and reserved names (`*admin`, `*bearwatch`, `*moderator` anywhere; `ranger`, `staff`, etc. only as the whole name). Lists live in `backend/config/nickname_filter/`. |
| D18 | Sign-up window | After SSO for a new account, the person has 30 minutes to pick a nickname before starting over. |
| D22 | R2 live + "out of honey" cap | Photos go to R2 (`bearwatch-photos`, served from the r2.dev URL for now). Uploads stop at 9.5 GB / 950k writes / 9.5M reads with "Oops! Ran out of honey. A ranger needs to fix this." The owner gets one email per month (`ALERT_EMAIL`, via SMTP). Storage and writes are counted by the app; reads need an optional analytics token (the R2 token is bucket-scoped and can't read analytics). |
| D23 | People in photos | Rejected when the detector's person score is ≥ 20% (`PERSON_MAX_SCORE`); same model pass, no extra compute. |
| D24 | Job queues | `photos` runs in the offline worker; `online` (R2 uploads, email, usage checks) runs inside the web server via the Solid Queue Puma plugin. |
| D25 | Moderation | Admins can remove a single post (photo deleted from storage) without banning. Outside champion photos are processed in the web request (admins only) with the same re-encode and metadata strip, no bear check. |
| D26 | Alert email | Sent from a dedicated Gmail account via SMTP (App Password in `.env`) to the owner's address. |
| D27 | Own-post deletion | Posters can delete their own published/rejected posts (photo removed from storage); not while still processing. |
| D28 | Dev seed data | `db/seeds.rb` (development only): 25 pop-culture bears, ~93 posts drawn from 32 public-domain/CC0 bear photos in `db/seeds/photos` (sources, licenses and detector bear boxes in `photos.yml`) copied to local disk, follows, avatars, wins, a banned bear; idempotent, `bearwatch:seed:reset` removes only seed accounts. |
| D11 | Bear check | ~~bear-conservation detect step~~ → **Option B**: a permissively licensed COCO detector (e.g. YOLOX, Apache-2.0) run with `onnxruntime` (MIT), using COCO's built-in `bear` class at 85% confidence. Avoids Ultralytics' AGPL terms (bear-conservation is MIT but its model is trained with and runs on Ultralytics). Validate against real photos before committing to it. |
| D19 | Photo storage | **Cloudflare R2** in production (free tier, no egress fees); local disk in development. Storage is swappable via `STORAGE_BACKEND`. The no-internet worker writes to a shared volume; the web container uploads to R2. Setup steps: `docs/r2-setup.md`. |
| D20 | Repo visibility | **Private.** Still: keep secrets in `.env` only, run a secret scan before any change of mind. |
| D21 | Real SSO | Google + GitHub verified end to end on 2026-11-12 (sign-up, linking, returning sign-in). Production pins the callback host and allowed Host to `APP_HOST`. |

## Architecture (current draft)

```
browser ──> Caddy (TLS, serves SPA + /media) ──> Rails API (web)  ──┐
                                                    │ edge network    │ internal network (no internet)
                                                    └───────────────> MySQL
                                                      Solid Queue worker (libvips) ──> detector (ONNX)
```

- **Dev:** `docker compose up` (Vite :5173 proxies `/api` + `/auth` to Rails :3000). **Prod:** `compose.prod.yaml` (Caddy image with the built SPA baked in).
- **Sessions:** Rails encrypted cookie session (HttpOnly, SameSite=Lax, Secure in prod). Writes need the CSRF token from `GET /api/session` in an `X-CSRF-Token` header; starting SSO is a form POST with the same token.
- **Single origin** (Caddy): SPA, `/api`, `/auth`, `/media` on one host, so the
  session cookie is HttpOnly + SameSite=Lax with no CORS.
- **Jobs:** Solid Queue (DB-backed), so there's no Redis to run on a small box.
- **No-internet network:** the worker and detector only sit on a Docker
  `internal: true` network.
- **Upload pipeline (built):**
  1. *Web:* size ≤ 12 MB (Caddy caps the body at 13 MB), extension in jpg/jpeg/png/webp/heic/heif, and the file's magic bytes must match the extension. Rate limits checked. Original saved to the `uploads` volume, post created as `processing`, job queued.
  2. *Worker (Solid Queue, no internet, `VIPS_BLOCK_UNTRUSTED=1`):* `vipsheader` reads only the header; over 50 MP is rejected before any decoding. `vipsthumbnail` (30 s hard timeout) auto-rotates, converts to sRGB, fits within 2048×2048 and writes WebP Q82 with all metadata stripped.
  3. *Detector:* receives only the re-encoded WebP. YOLOX-S; bear ≥ 0.85 **and** higher than every lookalike animal (dog, cow, horse, teddy bear…).
  4. Published → WebP moved to `media` under a random 32-char name; otherwise rejected/failed. The original is always deleted (kept only while the detector is temporarily down, for retries: 12 tries over ~2 min).
- **Rate limits:** 1 accepted photo per minute and 20 per day per user (rejected photos don't count), plus 5 upload attempts per minute.
- **Place search:** OpenStreetMap Nominatim via our server (1 req/s throttle, 1-day cache, explicit Search button: Nominatim forbids search-as-you-type). Photon was the first choice but its public server was down on 2026-11-12. "Use where I am now" sends coordinates rounded to 2 decimals for a one-off reverse lookup; not stored.

## Data model (draft)

- `users` *(built)*: id, nickname (unique, case-insensitive, 3-20), is_admin, banned_at, ban_reason, timestamps. `avatar_post_id` comes with posts.
- `identities` *(built)*: id, user_id, provider (`google_oauth2`/`github`/`developer`), uid; unique(provider, uid) and unique(user_id, provider)
- `posts` *(built)*: id, user_id, status (`processing`/`published`/`rejected`/`failed`), image_key, width, height, place_name, latitude/longitude (decimal(4,1), ~11 km), bear_score, failure_reason, timestamps
- `solid_queue_*` *(built)*: background job tables, in the main database
- `follows` *(built)*: follower_id, followee_id; unique pair
- `users` avatar *(built)*: avatar_post_id (own published post), avatar_zoom (1-4), avatar_x/avatar_y (0-1 centre point)
- `posts.bear_x/y/w/h` *(built)*: where the detector found the bear
- `fat_bear_wins` *(built)*: post_id, year (unique), awarded_by_id
- `fat_bear_champions` *(built)*: year (unique), bear_name, bear_number, blurb, post_id **or** image_key/image_storage/size for an outside photo, credit, link_url (http/https only), link_text, updated_by_id

## Open questions
- **Q8 Awarding wins:** The mockup awards a win from the post's pop-up (admins only) and lists/revokes them in the admin panel. OK?
- **Q2 Sightings map (later):** Fine with 10 km rounding as a heatmap/clusters. Avoid exact pins (risk to the bears and to user privacy).
- **Q3 Place names:** Free-text place name, or pick from a list / geocoder (e.g. OSM Nominatim, free but rate limited)?
- **Q4 Detector accuracy:** Test the COCO detector on real bear photos (close-ups, far away, cubs, water, night) and non-bear photos (dogs, people, teddy bears) before wiring it in.
- **Q5 Ban appeals:** Should the banned screen include a contact method?
- **Q10 Detector accuracy:** Only 2 real test photos so far (both correct). Run `detector/tests/evaluate.py` on a bigger labelled set before launch.

## Notes
- `json` gem is pinned to 2.x: json 3.x breaks Rails 8.0's cookie encoder. Revisit when upgrading Rails.
- Fonts are self-hosted (`@fontsource`), so no requests go to Google Fonts.

## Phases
0. Repo, Docker skeleton, mockups, plan *(done)*
1. Scaffold Rails API + React (Vite) SPA; SSO login, nickname, ban screen *(done)*
2. Upload pipeline: worker + libvips + detector *(done)*
3. Feeds (Global/Following), profiles, follow *(done)*
4. Admin panel (bans, Fat Bear wins) *(done)*
5. Deploy (AWS/GCP cheap tier), TOS page
