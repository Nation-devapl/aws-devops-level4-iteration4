#!/bin/sh
echo refreshing backend config for terraform

cat <<EOV > terraform.tfvars
aws_owner = "${MY_USER}"
EOV

cat <<EOT > backend.tf
terraform {
  backend "s3" {
    bucket         = "${MY_USER}-apl-devops-terraform-state-060344054092"
    key            = "devops.school"
    region         = "${AWS_REGION}"
    encrypt        = true
    use_lockfile   = true
  }
}
EOT

