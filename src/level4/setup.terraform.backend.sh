#!/usr/bin/env bash
set -euo pipefail

echo "===== TERRAFORM BACKEND CONFIGURATION ====="

: "${S3_BUCKET:?ERROR: S3_BUCKET is not set}"
: "${AWS_REGION:?ERROR: AWS_REGION is not set}"
: "${STATE_KEY:?ERROR: STATE_KEY is not set}"

cat > backend.tf <<EOT
terraform {
  backend "s3" {
    bucket       = "${S3_BUCKET}"
    key          = "${STATE_KEY}"
    region       = "${AWS_REGION}"
    encrypt      = true
    use_lockfile = true
  }
}
EOT

echo "Generated backend.tf"
echo "Bucket: $S3_BUCKET"
echo "Region: $AWS_REGION"
