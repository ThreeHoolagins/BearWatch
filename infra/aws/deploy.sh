#!/usr/bin/env bash
# Run from your machine:  AWS_PROFILE=ff15 infra/aws/deploy.sh
# Tells the instance (via SSM Run Command) to pull main and run host-deploy.sh, then waits.
set -euo pipefail
# The AWS CLI on Windows prints with the console code page and chokes on build
# output like "✓"; force UTF-8.
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
STACK=${STACK:-bearwatch}
INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" --output text)
REPO=https://github.com/ThreeHoolagins/BearWatch.git

params=$(cat <<JSON
{"commands":[
  "set -euo pipefail",
  "test -f /opt/bearwatch/.bootstrapped || { echo 'First-boot setup not finished yet, try again in a few minutes'; exit 1; }",
  "test -d /opt/bearwatch/app/.git || git clone $REPO /opt/bearwatch/app",
  "cd /opt/bearwatch/app && git fetch --quiet origin main && git reset --hard --quiet origin/main",
  "bash infra/aws/host-deploy.sh"
],"executionTimeout":["5400"]}
JSON
)

command_id=$(MSYS_NO_PATHCONV=1 aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --comment "bearwatch deploy" \
  --timeout-seconds 600 \
  --parameters "$params" \
  --query Command.CommandId --output text)
echo "Deploying to ${INSTANCE_ID} (SSM command ${command_id}). The first build takes 20-40 minutes."

status=Pending
while :; do
  sleep 20
  status=$(aws ssm get-command-invocation --command-id "$command_id" --instance-id "$INSTANCE_ID" \
    --query Status --output text 2>/dev/null || echo Pending)
  case "$status" in Pending | InProgress | Delayed) printf . ;; *) break ;; esac
done
echo
aws ssm get-command-invocation --command-id "$command_id" --instance-id "$INSTANCE_ID" \
  --query '[StandardOutputContent, StandardErrorContent]' --output text | tail -40
echo "Deploy status: ${status}"
[ "$status" = "Success" ]
