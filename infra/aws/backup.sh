#!/usr/bin/env bash
# Nightly (systemd timer, installed by host-deploy.sh):
#   mysqldump -> gzip -> s3://$BACKUP_BUCKET/mysql/   (expired after 30 days)
#   local photos (media volume) -> s3://$BACKUP_BUCKET/media/  (a mirror)
set -euo pipefail
export HOME=/root
cd /opt/bearwatch/app
BUCKET=$(grep '^BACKUP_BUCKET=' .env | cut -d= -f2-)
TOKEN=$(curl -fsS -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
REGION=$(curl -fsS -H "X-aws-ec2-metadata-token: ${TOKEN}" http://169.254.169.254/latest/meta-data/placement/region)

docker compose -f compose.prod.yaml exec -T db sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -uroot --single-transaction --routines "$MYSQL_DATABASE"' |
  gzip -9 |
  aws s3 cp - "s3://${BUCKET}/mysql/bearwatch-$(date -u +%Y-%m-%dT%H%M).sql.gz" --region "$REGION"

# Only matters while STORAGE_BACKEND=local; with R2 the volume is a small cache.
media=$(docker volume inspect -f '{{.Mountpoint}}' bearwatch_media)
aws s3 sync "$media" "s3://${BUCKET}/media/" --delete --only-show-errors --region "$REGION"
echo "backup ok"
