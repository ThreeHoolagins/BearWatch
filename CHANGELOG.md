# Changelog

Bear Watch is built in phases (see `CLAUDE_PLAN.md`). Each finished phase has
an annotated git tag (`phase-0` ... `phase-4`) with these notes.

## Launch prep (unreleased, `main`)

- **Discord alerts** replace the Gmail SMTP email. Out-of-honey (R2 free-tier
  cap) alerts and a new `ErrorAlerts` middleware that pings on 429s and 5xx
  errors, once per status code per 10 minutes. `DISCORD_WEBHOOK_URL` in `.env`.
- **Production hardening:** Caddy security headers (HSTS, CSP, nosniff,
  Referrer-Policy, Permissions-Policy), log rotation, a `web` healthcheck the
  proxy waits on, memory caps on every service.
- **Small over fast:** Solid Queue in async mode with slower polling, 2 Puma
  threads, YJIT off, `MALLOC_ARENA_MAX=2`, lean MySQL, a one-thread detector
  that unloads its model when idle. Measured idle stack: ~450 MB.
- **AWS runbook:** `docs/aws-deploy.md` (single VM + Docker Compose).
- **Global feed from anywhere:** bears from everywhere, newest first, with
  nearby ones lifted (up to 24 hours' worth, fading out at 500 miles) when
  location is on. Location is now optional. New bears wait 10 minutes before
  reaching Global so admins can take down spam first. Cursor is `rank-id`.
- **Terms and privacy:** Terms of Service are out of draft and now grant Bear
  Watch a license to redistribute posted photos; a new Privacy Policy covers
  what we keep (provider account ID, nickname, posts) and what we don't.
- **Production photos on R2:** prod now stores new photos in the shared
  `bearwatch-photos` bucket (at the root; dev uses `development/`).
- Posters can delete their own bears; development seed data with 25
  pop-culture bears and 32 public-domain bear photos.

Still to do before launch: database backups, a detector accuracy run on a
bigger photo set, and an R2 custom domain.

## Phase 4: Ranger station and Fat Bear Week (2026-11-13)

Admin panel: user search, ban/unban with a reason (admins can't ban
themselves or other admins), Fat Bear Week wins awarded from a post (one per
year), a champion card editor (Bear Watch post or an outside photo with
credit) shown in the sidebar and as a mobile banner, and admin post removal.

## Phase 3: Feeds, profiles and following (2026-11-13)

Global feed (published bears within 500 miles, bounding box +
`ST_Distance_Sphere`), Following feed, cursor pagination with infinite
scroll, profiles at `/u/:nickname`, follow/unfollow, and bear-face avatars
cropped from your own photos.

## Phase 2: Photo uploads and the bear check (2026-11-13)

Uploads end to end: size and magic-byte checks, libvips re-encode to stripped
WebP in a worker with no internet, a YOLOX-S bear check (COCO `bear` class,
must beat lookalike animals), people rejected, place search via Nominatim,
rate limits, and the profile grid. Published photos go to Cloudflare R2 with
a free-tier cap ("Oops! Ran out of honey").

## Phase 1: Sign-in and the app shell (2026-11-10 to 11-12)

Rails 8 API + React SPA behind one origin. Google and GitHub SSO (only the
provider's account ID is stored, no tokens), a dev-only developer login,
nickname sign-up with live checks and a blocklist, account linking, the ban
screen, Terms modal, and the signpost/tab navigation.

## Phase 0: Skeleton and design (2026-11-10)

Repo, Docker Compose skeleton, the "Ranger Station" design mockups, and the
working plan.
