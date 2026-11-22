#!/usr/bin/env bash
# Deploy Live Monitoring Lambdas (Gmail). Run from anywhere: bash backend/scripts/deploy_monitor.sh
# Creates/updates: phishnet-monitor-connect (+ Function URL), phishnet-monitor-poll,
# their IAM policies. Creates NO EventBridge schedule. Poll stays off via MONITOR_ENABLED.
set -euo pipefail

REGION="us-east-2"
BACKEND="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(mktemp -d)"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
CONNECT_FN="phishnet-monitor-connect"
POLL_FN="phishnet-monitor-poll"
CONNECT_ROLE="phishnet-monitor-connect-role"
POLL_ROLE="phishnet-monitor-poll-role"

TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
SECRET_POLICY=$(cat <<JSON
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":"secretsmanager:GetSecretValue","Resource":"arn:aws:secretsmanager:${REGION}:${ACCOUNT}:secret:phishnet/prod*"},
 {"Effect":"Allow","Action":["secretsmanager:GetSecretValue","secretsmanager:PutSecretValue","secretsmanager:CreateSecret"],"Resource":"arn:aws:secretsmanager:${REGION}:${ACCOUNT}:secret:phishnet/monitor-tokens*"}
]}
JSON
)

echo "== 1. Build packages (Linux x86_64 wheels, Python 3.12)"
build() { # $1 = name, rest = source files (relative to backend/)
  local name=$1; shift
  local dir="$BUILD/$name"; mkdir -p "$dir"
  pip install -q --target "$dir" --platform manylinux2014_x86_64 \
      --implementation cp --python-version 3.12 --only-binary=:all: \
      -r "$BACKEND/lambda/requirements.txt"
  for f in "$@"; do cp "$BACKEND/$f" "$dir/"; done
  (cd "$dir" && zip -q -r "$BUILD/$name.zip" . -x '*__pycache__*')
  echo "   $name.zip: $(du -h "$BUILD/$name.zip" | cut -f1)"
}
build connect monitor/connect.py monitor/gmail.py monitor/store.py
build poll monitor/poll.py monitor/worker.py monitor/gmail.py monitor/store.py lambda/handler.py

echo "== 2. IAM roles and secret policy"
if ! aws iam get-role --role-name "$CONNECT_ROLE" >/dev/null 2>&1; then
  aws iam create-role --role-name "$CONNECT_ROLE" --assume-role-policy-document "$TRUST" >/dev/null
fi
aws iam attach-role-policy --role-name "$CONNECT_ROLE" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam put-role-policy --role-name "$CONNECT_ROLE" --policy-name monitor-secrets --policy-document "$SECRET_POLICY"
aws iam put-role-policy --role-name "$POLL_ROLE" --policy-name monitor-secrets --policy-document "$SECRET_POLICY"
CONNECT_ARN=$(aws iam get-role --role-name "$CONNECT_ROLE" --query Role.Arn --output text)
POLL_ARN=$(aws iam get-role --role-name "$POLL_ROLE" --query Role.Arn --output text)
sleep 10  # IAM propagation

echo "== 3. Connect function"
if aws lambda get-function --function-name "$CONNECT_FN" --region "$REGION" >/dev/null 2>&1; then
  aws lambda update-function-code --function-name "$CONNECT_FN" --zip-file "fileb://$BUILD/connect.zip" --region "$REGION" >/dev/null
else
  aws lambda create-function --function-name "$CONNECT_FN" --runtime python3.12 \
    --handler connect.handler --role "$CONNECT_ARN" --zip-file "fileb://$BUILD/connect.zip" \
    --timeout 15 --memory-size 256 --region "$REGION" >/dev/null
fi
aws lambda wait function-updated --function-name "$CONNECT_FN" --region "$REGION"

echo "== 4. Function URL (public URL; the code checks Firebase tokens)"
if ! aws lambda get-function-url-config --function-name "$CONNECT_FN" --region "$REGION" >/dev/null 2>&1; then
  aws lambda create-function-url-config --function-name "$CONNECT_FN" --auth-type NONE --region "$REGION" >/dev/null
  aws lambda add-permission --function-name "$CONNECT_FN" --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl --principal "*" --function-url-auth-type NONE --region "$REGION" >/dev/null
fi
URL=$(aws lambda get-function-url-config --function-name "$CONNECT_FN" --region "$REGION" --query FunctionUrl --output text)
aws lambda update-function-configuration --function-name "$CONNECT_FN" \
  --environment "Variables={GMAIL_REDIRECT_URI=${URL},SECRET_ID=phishnet/prod}" --region "$REGION" >/dev/null
aws lambda wait function-updated --function-name "$CONNECT_FN" --region "$REGION"

echo "== 5. Poll function (disabled by its own flags; no schedule)"
aws lambda update-function-code --function-name "$POLL_FN" --zip-file "fileb://$BUILD/poll.zip" --region "$REGION" >/dev/null
aws lambda wait function-updated --function-name "$POLL_FN" --region "$REGION"
aws lambda update-function-configuration --function-name "$POLL_FN" --handler poll.lambda_handler \
  --role "$POLL_ARN" --timeout 300 --memory-size 512 --region "$REGION" >/dev/null
aws lambda wait function-updated --function-name "$POLL_FN" --region "$REGION"

echo "== Done"
echo "Connect Function URL (add this EXACT value as an Authorized redirect URI in the Google OAuth client):"
echo "$URL"
rm -rf "$BUILD"
