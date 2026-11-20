#!/usr/bin/env bash
# Runs ON the EC2 host (as root, via SSM, from infra/aws/deploy.sh).
# Pulls main, writes .env from SSM Parameter Store (/bearwatch/*), rebuilds and restarts.
set -euo pipefail
export HOME=/root
cd /opt/bearwatch/app

TOKEN=$(curl -fsS -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
REGION=$(curl -fsS -H "X-aws-ec2-metadata-token: ${TOKEN}" http://169.254.169.254/latest/meta-data/placement/region)

# 1. Config: every /bearwatch/* parameter becomes KEY=value in .env (secrets are SecureString).
aws ssm get-parameters-by-path --region "$REGION" --path /bearwatch/ --with-decryption \
  --query 'Parameters[].[Name,Value]' --output text |
  awk -F'\t' '{ sub(/^\/bearwatch\//, "", $1); print $1 "=" $2 }' >.env.new
chmod 600 .env.new
mv .env.new .env

# 2. Build one image at a time (keeps peak memory low), then start.
compose="docker compose -f compose.prod.yaml"
for service in web detector proxy; do
  $compose build "$service"
done
$compose up -d --remove-orphans

# 3. Wait for Rails to report healthy.
state=starting
for _ in $(seq 1 60); do
  state=$(docker inspect -f '{{.State.Health.Status}}' "$($compose ps -q web)" 2>/dev/null || echo starting)
  [ "$state" = healthy ] && break
  sleep 5
done
$compose ps
if [ "$state" != healthy ]; then
  $compose logs --tail 80 web
  exit 1
fi

# 4. Free disk from old builds.
docker image prune -f >/dev/null || true
docker builder prune -f --filter "until=168h" >/dev/null || true

# 5. Nightly backup timer (idempotent).
install -m 700 infra/aws/backup.sh /opt/bearwatch/backup.sh
cat >/etc/systemd/system/bearwatch-backup.service <<'UNIT'
[Unit]
Description=Bear Watch backup to S3

[Service]
Type=oneshot
ExecStart=/opt/bearwatch/backup.sh
UNIT
cat >/etc/systemd/system/bearwatch-backup.timer <<'UNIT'
[Unit]
Description=Nightly Bear Watch backup

[Timer]
OnCalendar=*-*-* 10:00:00 UTC
Persistent=true

[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now bearwatch-backup.timer >/dev/null
echo "Deployed $(git rev-parse --short HEAD)"
