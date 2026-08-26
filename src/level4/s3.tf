resource "aws_s3_bucket" "terraform-state" {
  bucket = format("%s-apl-devops-terraform-state-060344054092", var.aws_owner)
  tags = {
    Team = "APL"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "devops-terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  versioning_configuration {
    status = "Enabled"
  }
}
