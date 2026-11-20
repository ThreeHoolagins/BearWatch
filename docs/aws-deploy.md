# Deploying Bear Watch on AWS

One small VM running `compose.prod.yaml`. No ECS, RDS or load balancer: they
cost more than the whole box and Bear Watch doesn't need them. Photos live in
Cloudflare R2 (`docs/r2-setup.md`), so the VM only holds the database and
photos waiting to be processed.

## 1. The machine

The production stack is tuned to be small rather than fast. Measured idle
(x86, Docker Desktop, 2026-11-19):

| Service  | Idle    | Notes |
|----------|---------|-------|
| proxy    | ~17 MB  | |
| web      | ~95 MB  | Puma + the "online" job queue in threads |
| worker   | ~95 MB  | plus libvips while re-encoding a photo |
| detector | ~35 MB  | ~110 MB with the model loaded; unloads after 10 idle min |
| db       | ~160 MB | |

About 400-460 MB in total, plus whatever the OS needs.

- **Cheapest that works:** 1 GB RAM plus a 2 GB swap file. Uploads get slow
  under load; browsing stays fine.
- **Comfortable:** 2 GB RAM (e.g. EC2 `t4g.small`, Arm/Graviton) plus swap.
- Arm (`t4g`) is cheaper than x86 for the same size, and every image builds
  for arm64.
- Disk: 20 GB gp3 is plenty.
- Ubuntu 24.04 LTS or Amazon Linux 2023.

Add a swap file (once):

```sh
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swap.conf && sudo sysctl --system
```

## 2. Network

- **Elastic IP** attached to the instance, so the address survives restarts.
- **Security group:** inbound 80 and 443 from anywhere. Nothing else.
  Use **SSM Session Manager** to get a shell instead of opening port 22
  (attach the `AmazonSSMManagedInstanceCore` role to the instance).
- **DNS** (at your registrar, e.g. Hostinger): an `A` record for your host
  (`bearwatch.example.com`) pointing at the Elastic IP. Caddy gets the TLS
  certificate by itself once DNS resolves and 80/443 are open.
- **AWS Budgets:** set a monthly budget alert (e.g. $15) so mistakes show up early.

## 3. Install and first start

```sh
# Docker Engine + compose plugin (Ubuntu)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # log out and back in

git clone <repo> bearwatch && cd bearwatch
cp .env.example .env            # then fill it in, see below
docker compose -f compose.prod.yaml up -d --build
docker compose -f compose.prod.yaml ps    # web should turn "healthy"
```

The first build on a 1-2 GB box is slow (the frontend and gems compile). If it
runs out of memory, make sure swap is on, or build one service at a time:
`docker compose -f compose.prod.yaml build web`, then `proxy`, then `detector`.

### `.env` for production

- `APP_HOST`: your real hostname.
- `SECRET_KEY_BASE`: `docker compose -f compose.prod.yaml run --rm web bin/rails secret`
- `MYSQL_*`: long random passwords (`openssl rand -hex 24`).
- `STORAGE_BACKEND=r2` and all `R2_*` values (`docs/r2-setup.md`).
- `GOOGLE_*`, `GITHUB_*`: and register the production callback URLs
  `https://APP_HOST/auth/google_oauth2/callback` and `https://APP_HOST/auth/github/callback`.
  Google also needs the consent screen moved out of "Testing" (needs a privacy policy URL).
- `GEOCODER_CONTACT`, `DISCORD_WEBHOOK_URL`.
- Resource knobs (`RAILS_MAX_THREADS`, `JOB_POLL_INTERVAL`, `DETECTOR_*`) are
  optional; the defaults favour low memory.

## 4. Updating

Production (the `bearwatch` CloudFormation stack, `infra/aws/bearwatch.yaml`)
deploys itself:

1. Push to `main`.
2. GitHub Actions (`.github/workflows/ci.yml`) runs the backend tests and the
   frontend lint and build. If they pass, it moves the `production` branch to
   that commit. If they fail, nothing ships.
3. CodePipeline `bearwatch-deploy` sees `production` move (through the
   `bearwatch-github` CodeConnections link) and starts CodeBuild, which runs
   `infra/aws/deploy.sh <commit>`.
4. That tells the instance, over SSM, to check out the commit and run
   `infra/aws/host-deploy.sh`: rebuild `.env` from `/bearwatch/` parameters,
   build images one at a time, restart, and wait for `web` to be healthy.

Deploys queue rather than overlap. Watch them in the console under
CodePipeline > `bearwatch-deploy`, or the logs in CloudWatch
`/aws/codebuild/bearwatch`.

GitHub Actions has no AWS credentials: this account's org policy blocks GitHub
OIDC, so AWS pulls from GitHub instead (same as FF15). The connection had to be
authorized once in the console (Developer Tools > Settings > Connections).

**By hand** (e.g. after changing a `/bearwatch/` setting, or to redeploy without
a push): `AWS_PROFILE=ff15 infra/aws/deploy.sh`, which redeploys
`origin/production`. Pass a commit or branch to deploy something else.
Or re-run the pipeline: **Release change** in the console.

**Rolling back:** `git revert` the bad commit and push to `main`.

`web` runs `db:prepare` on start, which applies new migrations. Old images are
pruned after each deploy.

## 5. Day to day

- Logs: `docker compose -f compose.prod.yaml logs -f web` (rotated at 3 x 10 MB per service).
- Memory: `docker stats --no-stream`.
- R2 usage: `docker compose -f compose.prod.yaml exec web bin/rails bearwatch:storage:status`.
- Alerts land in Discord (429s, 5xx, out of honey). They can't fire if the box
  itself is down, so add a free external uptime check on `https://APP_HOST/up`.

## Still to do before launch

- **Database backups.** Nothing backs up `db_data` yet. At minimum a nightly
  `mysqldump` to R2/S3, or EBS snapshots via Data Lifecycle Manager; test a restore once.
- **R2 custom domain** instead of the rate-limited `r2.dev` URL (needs the
  domain's DNS on Cloudflare, see `docs/r2-setup.md`).
