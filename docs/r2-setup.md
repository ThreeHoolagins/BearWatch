# Setting up Cloudflare R2 for photo storage

Bear Watch stores processed photos (WebP, metadata stripped) on local disk by
default. When you move to a cloud host, switch to Cloudflare R2: S3-compatible
storage with **no download (egress) fees**, which matters for a photo site.

You don't need any of this for local development.

## What it costs

| | Free each month | After that |
|---|---|---|
| Storage | 10 GB | $0.015 per GB |
| Writes (uploads, lists) | 1 million | $4.50 per million |
| Reads (photo views) | 10 million | $0.36 per million |
| Downloads/bandwidth | Always free | Always free |

A processed photo is roughly 300–500 KB, so 10 GB is about 20–30k photos.
Each upload costs us a couple of writes. Views through a custom domain are
mostly served from Cloudflare's cache, so they rarely reach R2.

**There's no hard spending cap.** Set up a billing alert (step 6).

## 1. Account and R2

1. Create a Cloudflare account at <https://dash.cloudflare.com/sign-up>.
2. In the dashboard sidebar open **R2 Object Storage** and enable it.
   Cloudflare asks for a payment method even if you stay inside the free tier.

## 2. Create the bucket

1. **R2 → Create bucket**.
2. Name: `bearwatch-photos` (lowercase, no spaces).
3. Location: **Automatic**, or pick the region nearest your server.
4. Storage class: **Standard** (the free tier only applies to Standard).

## 3. Create an API token for the app

1. **R2 → Manage R2 API Tokens → Create API token**.
2. Permissions: **Object Read & Write**.
3. Scope it to **only the `bearwatch-photos` bucket**. If this token ever leaks,
   it can't touch anything else in your account.
4. Leave the TTL empty (no expiry) or set a reminder to rotate it.
5. Create it and copy these three values. **The secret is shown only once**:
   - Access Key ID
   - Secret Access Key
   - The S3 endpoint, which looks like `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`

## 4. Make photos publicly viewable

Photos are public on Bear Watch, so the browser loads them straight from
Cloudflare instead of through our server.

**Recommended: a custom domain** (for example `photos.yourdomain.com`).

1. Your domain's DNS must be on Cloudflare (free plan is fine).
   **Websites → Add a site**, then follow the steps to change your nameservers.
2. **R2 → bearwatch-photos → Settings → Custom Domains → Connect Domain**.
3. Enter `photos.yourdomain.com`. Cloudflare creates the DNS record and certificate.

**Testing only: the `r2.dev` URL.** Under **Settings → Public Development URL**
you can enable `https://pub-<id>.r2.dev`. It's rate-limited and not meant for
production, so don't launch on it.

## 5. Tell Bear Watch about it

Add these to `.env` on the server (never commit them):

```sh
STORAGE_BACKEND=r2
R2_ACCOUNT_ID=<the long id in your endpoint URL>
R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
R2_BUCKET=bearwatch-photos
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_PUBLIC_URL=https://photos.yourdomain.com
```

Then restart: `docker compose -f compose.prod.yaml up -d`.

How it fits the upload pipeline: the image worker has **no internet access** by
design, so it never talks to R2. It writes the finished WebP to a shared
volume, and the web container uploads it to R2 and deletes the local copy.
Photos already stored on local disk keep working; only new ones go to R2.
Non-production environments use their own folder in the bucket
(`development/...`) so test photos are easy to spot and delete.

## The free-tier cap ("Out of honey")

Bear Watch stops accepting uploads before it would cost you anything:

| Limit | Free tier | Bear Watch stops at | Setting |
|---|---|---|---|
| Storage | 10 GB | 9.5 GB | `R2_STORAGE_LIMIT_GB` |
| Writes (Class A) | 1,000,000 / month | 950,000 | `R2_CLASS_A_LIMIT` |
| Reads (Class B) | 10,000,000 / month | 9,500,000 | `R2_CLASS_B_LIMIT` |

When a limit is hit, uploaders see *"Oops! Ran out of honey. A ranger needs to
fix this."* and `ALERT_EMAIL` gets one email per month (needs the `SMTP_*`
settings).

Storage and writes are counted by Bear Watch itself (it's the only thing
writing to the bucket), and the bucket is measured every 6 hours as a
cross-check. **Reads** happen directly between browsers and Cloudflare, so to
cap them too, create a second API token with **Account → Account Analytics →
Read** and set `R2_ANALYTICS_TOKEN`.

```sh
docker compose exec web bin/rails bearwatch:storage:status       # usage now
docker compose exec web bin/rails bearwatch:storage:check        # measure the bucket now
docker compose exec web bin/rails bearwatch:storage:reset_alert  # allow another email this month
```

## 6. Billing alert

**Manage Account → Billing → Notifications** (or **Notifications → Add**):
create a usage-based billing alert for R2 at a low threshold, such as $1, so
you hear about it the moment anything goes past the free tier.

## Rotating the token

If the secret leaks or you just want to rotate it:

1. Create a new token (step 3).
2. Update `.env` and restart the app.
3. Delete the old token in **Manage R2 API Tokens**.
