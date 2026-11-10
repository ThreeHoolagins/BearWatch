# BearWatch: Working Plan (Claude)

Companion to `HUMAN_PROJECT_PLAN.md` (Caleb's plan; never edited by agents).
This doc records decisions as we make them, open questions, and build phases.

## Status
- **Phase 0 (in progress):** repo, Docker skeleton, design mockups.
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
| D11 | Bear check | `earthtoolsmaker/bear-conservation` **detect step only**, 85% confidence threshold. |

## Architecture (current draft)

```
browser ──> Caddy (TLS, serves SPA + /media) ──> Rails API (web)  ──┐
                                                    │ edge network    │ internal network (no internet)
                                                    └───────────────> MySQL
                                                      Solid Queue worker (libvips) ──> detector (ONNX)
```

- **Single origin** (Caddy): SPA, `/api`, `/auth`, `/media` on one host, so the
  session cookie is HttpOnly + SameSite=Lax with no CORS.
- **Jobs:** Solid Queue (DB-backed), so there's no Redis to run on a small box.
- **No-internet network:** the worker and detector only sit on a Docker
  `internal: true` network.
- **Upload pipeline:** check extension + magic bytes, then read the header
  dimensions and reject over the pixel limit, then libvips re-encodes to WebP
  (≤2048 px wide, strip metadata, with a timeout), then the detector runs on
  the *re-encoded* image only, then the original is deleted and the post is
  published (or rejected with the "blurry photo" message).

## Data model (draft)

- `users`: id, nickname (unique, 3-20), avatar_post_id (nullable), is_admin, banned_at, ban_reason, timestamps
- `identities`: id, user_id, provider (`google`/`github`), provider_uid; unique(provider, provider_uid)
- `posts`: id, user_id, image_key, place_name, lat (rounded), lng (rounded), status (`processing`/`published`/`rejected`), timestamps
- `fat_bear_wins`: id, post_id, year, awarded_by (user_id)
- `fat_bear_champions`: id, year (unique), bear_name, bear_number, blurb, post_id (nullable), image_key (nullable, for outside photos), credit, link_url, link_text
- `follows`: id, follower_id, followee_id; unique pair

## Open questions
- **Q1 Own-post deletion:** The mockup lets users delete their own posts (not in the original plan). Keep?
- **Q8 Awarding wins:** The mockup awards a win from the post's pop-up (admins only) and lists/revokes them in the admin panel. OK?
- **Q2 Sightings map (later):** Fine with 10 km rounding as a heatmap/clusters. Avoid exact pins (risk to the bears and to user privacy).
- **Q3 Place names:** Free-text place name, or pick from a list / geocoder (e.g. OSM Nominatim, free but rate limited)?
- **Q4 Detector coverage:** Verify that the detect model handles full-body and far-away shots, not just faces. Also check the Ultralytics AGPL license implications.
- **Q5 Ban appeals:** Should the banned screen include a contact method?
- **Q6 Blob storage:** Local disk first; Cloudflare R2 (10 GB free, no egress fees) as the cloud option?
- **Q7 Rate limit:** 1 upload/min/user plus a daily cap?

## Phases
0. Repo, Docker skeleton, mockups, plan *(now)*
1. Scaffold Rails API + React (Vite) SPA; SSO login, nickname, ban screen
2. Upload pipeline: worker + libvips + detector
3. Feeds (Global/Following), profiles, follow
4. Admin panel (bans, Fat Bear wins)
5. Deploy (AWS/GCP cheap tier), TOS page
