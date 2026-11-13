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

### Admin chores

Until the admin panel lands (Phase 4):

```sh
docker compose exec web bin/rails "bearwatch:admin[nickname]"
docker compose exec web bin/rails "bearwatch:ban[nickname,Reason the user will see.]"
docker compose exec web bin/rails "bearwatch:unban[nickname]"
```

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
