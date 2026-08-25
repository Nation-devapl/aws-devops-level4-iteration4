#!/usr/bin/env bash
set -euo pipefail

echo "===== LEVEL4 ITERATION4 BACKEND VERIFICATION ====="

AWS_ARN="$(aws sts get-caller-identity --query Arn --output text)"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
AWS_REGION="$(aws configure get region)"
MY_USER="${AWS_ARN##*/}"

S3_OWNER="$(
    printf '%s' "$MY_USER" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9.-]+/-/g; s/^[.-]+//; s/[.-]+$//'
)"

S3_BUCKET="${S3_OWNER}-${AWS_ACCOUNT_ID}-apl-devops-terraform-state"

echo "AWS user:   $MY_USER"
echo "AWS region: $AWS_REGION"
echo "S3 bucket:  $S3_BUCKET"

echo
echo "Checking S3 bucket..."

aws s3api head-bucket \
    --bucket "$S3_BUCKET"

VERSIONING_STATUS="$(
    aws s3api get-bucket-versioning \
        --bucket "$S3_BUCKET" \
        --query Status \
        --output text
)"

if [[ "$VERSIONING_STATUS" != "Enabled" ]]; then
    echo "ERROR: S3 bucket versioning is not enabled."
    exit 1
fi

echo "S3 bucket exists."
echo "Versioning: Enabled"

if [[ ! -f backend.tf ]]; then
    echo "ERROR: backend.tf does not exist."
    exit 1
fi

echo "backend.tf exists."
echo "Backend verification successful."
