#!/usr/bin/env bash
set -euo pipefail

APPLY_BOOTSTRAP="${APPLY_BOOTSTRAP:-false}"
MIGRATE_BACKEND="${MIGRATE_BACKEND:-false}"

###########################################################
# Terraform iteration 4: Make Terraform backend dynamic
###########################################################

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/aws-devops-level4-iteration4}"
REPO_ROOT="${REPO_ROOT:-$PROJECT_ROOT/aws-devops}"
WORKDIR="${WORKDIR:-$REPO_ROOT/src/level4}"

echo "===== LEVEL4 ITERATION4 WORKSPACE ====="
echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "REPO_ROOT=$REPO_ROOT"
echo "WORKDIR=$WORKDIR"

mkdir -p "$WORKDIR"

cd "$WORKDIR"

echo
echo "===== AWS AUTHENTICATION ====="

if ! AWS_ARN="$(aws sts get-caller-identity --query Arn --output text)"; then
    echo "ERROR: AWS authentication failed."
    echo "Run 'aws login' and try again."
    exit 1
fi

AWS_REGION="$(aws configure get region)"

if [[ -z "$AWS_REGION" ]]; then
    echo "ERROR: No AWS region is configured."
    exit 1
fi

MY_USER="${AWS_ARN##*/}"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

S3_OWNER="$(
    printf '%s' "$MY_USER" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9.-]+/-/g; s/^[.-]+//; s/[.-]+$//'
)"

S3_BUCKET="${S3_OWNER}-${AWS_ACCOUNT_ID}-apl-devops-terraform-state"
STATE_KEY="level4/iteration4/terraform.tfstate"

export MY_USER
export AWS_REGION
export AWS_ACCOUNT_ID
export S3_OWNER
export S3_BUCKET
export STATE_KEY

echo "AWS ARN:        $AWS_ARN"
echo "AWS USER:       $MY_USER"
echo "AWS ACCOUNT ID: $AWS_ACCOUNT_ID"
echo "AWS REGION:     $AWS_REGION"
echo "S3 OWNER:       $S3_OWNER"
echo "S3 BUCKET:      $S3_BUCKET"
echo "STATE KEY:      $STATE_KEY"

cat <<'EOF' > setup.terraform.backend.sh
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
EOF

chmod +x setup.terraform.backend.sh

# - refactor to use main input variable var.aws_owner

cat <<'EOF' > s3.tf
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.s3_bucket_name

  tags = {
    Project     = "aws-devops-level4"
    Iteration   = "4"
    Team        = "APL"
    ManagedBy   = "Terraform"
    Environment = "level4-iteration4"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
EOF

cat <<'EOF' > variables.tf
variable "s3_bucket_name" {
  description = "Globally unique S3 bucket used for Level4 Iteration4 Terraform state"
  type        = string
}
EOF

cat > level4.auto.tfvars <<EOF
s3_bucket_name = "${S3_BUCKET}"
EOF

# - add backend.tf to .gitignore
cat <<'EOF' > .gitignore
# Terraform working directory
**/.terraform/*

# Terraform state
*.tfstate
*.tfstate.*

# Terraform variable files
*.tfvars
*.tfvars.json

# Terraform plans
tfplan
*.tfplan

# Terraform crash logs
crash.log
crash.*.log

# Dynamically generated backend
backend.tf

# Local/generated files
result.json
src.zip
EOF

cat > provider.tf <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "${AWS_REGION}"
}
EOF

# - time to package our automation script as well
cat <<'EOF' > verify.backend.sh
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
EOF

chmod +x verify.backend.sh

echo
echo "===== REMOTE STATE CHECK ====="

if aws s3api head-object \
    --bucket "$S3_BUCKET" \
    --key "$STATE_KEY" \
    >/dev/null 2>&1
then
    echo "Remote Terraform state already exists."
    echo "Skipping local bootstrap."

    bash setup.terraform.backend.sh

    echo
    echo "===== REMOTE BACKEND INITIALIZATION ====="

    terraform init -reconfigure
    terraform fmt -check
    terraform validate

    echo
    echo "===== REMOTE BACKEND PLAN ====="

    terraform plan

    echo
    echo "===== BACKEND VERIFICATION ====="

    bash verify.backend.sh

    echo
    echo "===== LEVEL4 ITERATION4 ALREADY INITIALIZED ====="
    echo "Remote backend is healthy."

    exit 0
fi

echo "No remote Terraform state found."
echo "Starting first-time local bootstrap."

echo
echo "===== TERRAFORM LOCAL BOOTSTRAP ====="

# Backend bucket must exist before Terraform can use it as an S3 backend.
# Start with local state first.
rm -f backend.tf

terraform init -reconfigure

terraform fmt -check
terraform validate

echo
echo "===== BOOTSTRAP PLAN ====="

terraform plan -out=bootstrap.tfplan

echo
echo "Bootstrap plan created successfully."
echo "Review bootstrap.tfplan before applying."

echo
echo "===== BOOTSTRAP APPLY GUARD ====="

if [[ "$APPLY_BOOTSTRAP" != "true" ]]; then
    echo "Bootstrap apply is disabled."
    echo
    echo "Review the plan with:"
    echo "  terraform show bootstrap.tfplan"
    echo
    echo "When approved, run:"
    echo "  APPLY_BOOTSTRAP=true bash \"Level4 Iteration4.sh\""
    exit 0
fi

echo
echo "Applying approved bootstrap plan..."
terraform apply bootstrap.tfplan

echo
echo "===== BACKEND CONFIGURATION ====="

bash setup.terraform.backend.sh

if [[ "$MIGRATE_BACKEND" != "true" ]]; then
    echo
    echo "S3 bucket has been created."
    echo "backend.tf has been generated."
    echo
    echo "Backend migration is disabled."
    echo "Review backend.tf before migration."
    echo
    echo "When approved, run:"
    echo "  APPLY_BOOTSTRAP=true MIGRATE_BACKEND=true bash \"Level4 Iteration4.sh\""
    exit 0
fi

echo
echo "===== TERRAFORM STATE MIGRATION ====="

terraform init -migrate-state

echo
echo "===== BACKEND VERIFICATION ====="

bash verify.backend.sh

echo
echo "===== LEVEL4 ITERATION4 COMPLETE ====="
echo "Terraform backend migration completed successfully."

exit 0
