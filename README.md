# Bear Watch

Instagram, but only for bears. React SPA + Rails API + MySQL, all in Docker.

- `HUMAN_PROJECT_PLAN.md`: the original plan.
- `CLAUDE_PLAN.md`: decisions, data model, open questions and build phases.
- `docs/design/mockups.html`: clickable design mockup (serve the repo root, e.g. `python -m http.server 8787`).

## Run it locally

Requires Docker Desktop.

```sh
cp .env.example .env        # first time only
docker compose up           # MySQL, Rails (:3000), Vite (:5173), photo worker, bear detector
```

Open **http://localhost:5173**. Vite proxies `/api`, `/auth` and `/media` to Rails, so the browser only ever talks to one origin.

Without Google/GitHub credentials you'll see a **Developer sign-in** button (development only). It asks for a name, which becomes a fake account ID, then sends you to the nickname screen like a real new account would.

### Seed data (development)

```sh
docker compose exec web bin/rails db:seed                   # add the seed bears (safe to re-run)
docker compose exec web bin/rails db:seed ME=your_nickname  # ...and make your account follow some of them
docker compose exec web bin/rails bearwatch:seed:reset      # remove the seed bears and seed again
```

25 pop-culture bears (paddington, winnie_the_pooh, yogi_bear, smokey_bear, lotso...) with ~90 posts across
parks near and far from Fort Collins, follows, bear-face avatars, Fat Bear Week wins for 2023-2025, and one banned
bear (lotso). Photos are drawn landscapes with bear silhouettes, generated locally and kept on local disk even
when R2 is on. Sign in as any of them with **Developer sign-in** and their nickname as the name. `smokey_bear` is
an admin. Your own accounts and champion card are never touched.

### Turning on Google and GitHub sign-in

Fill in the `GOOGLE_*` / `GITHUB_*` values in `.env` (see the comments there for where to create the OAuth apps and which redirect URLs to register), then `docker compose restart web`.

We only ever ask for the minimum scope (`openid` for Google, no scopes for GitHub) and only store the provider's account ID.

### Photos

Uploads are re-encoded by the `worker` container and checked by the `detector` container; both sit on a network with no internet access. In development, published photos land in `backend/public/media/` (gitignored).

To tune the bear threshold, put labelled photos in `bears/` and `not_bears/` folders and run:

```sh
docker compose run --rm -v /path/to/photos:/photos:ro detector python tests/evaluate.py /photos
```

Then set `BEAR_CONFIDENCE_THRESHOLD` in `.env`.

### Admins (the Ranger station)

Make your own account an admin once, from the command line:

```sh
docker compose exec web bin/rails "bearwatch:admin[your_nickname]"
```

After that, use **Admin panel** (account menu on desktop, your profile on phones) to search users, ban/unban with a reason, and edit the Fat Bear Week champion card. Open any post to award or revoke a Fat Bear Week win or remove the post. The `bearwatch:ban` / `bearwatch:unban` rake tasks still work too.

### Photo storage and the "out of honey" cap

See `docs/r2-setup.md`. Check usage with `docker compose exec web bin/rails bearwatch:storage:status`.

### Tests and checks

```sh
docker compose exec web bin/rails test
docker compose exec frontend sh -c "npx tsc -b && npx oxlint"
```

## Production

```sh
# In .env: set real passwords, uncomment SECRET_KEY_BASE (bin/rails secret), set APP_HOST.
docker compose -f compose.prod.yaml up -d --build
```

Caddy serves the SPA and proxies the API on one origin, getting HTTPS certificates automatically for `APP_HOST`. The database sits on an internal Docker network with no internet access. Images build for both x86 and ARM (Raspberry Pi 4).
