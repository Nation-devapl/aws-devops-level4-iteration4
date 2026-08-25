# AWS DevOps Level 4 - Iteration 4

Level 4 Iteration 4 implements a standalone Terraform S3 remote backend.

## Features

- Standalone Level 4 workspace
- AWS authentication validation
- Dynamic and globally unique S3 backend bucket name
- S3 versioning enabled
- Server-side encryption with AES256
- Terraform remote state stored in S3
- Safe first-time local bootstrap
- Controlled state migration
- Idempotent re-runs
- Backend verification
- No destructive automatic Terraform operations

## Terraform backend

State is stored using:

`level4/iteration4/terraform.tfstate`

The backend bucket is generated dynamically from the AWS identity and account ID.

## Safety

The script separates:

1. Terraform planning
2. Bootstrap apply
3. Backend migration

Bootstrap and migration require explicit opt-in environment variables.

Normal re-runs detect the existing remote state and verify that the backend remains healthy.