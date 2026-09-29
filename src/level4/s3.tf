resource "aws_s3_bucket" "terraform-state" {
  bucket   = format("%s-apl-devops-terraform-state", var.aws_owner)
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
