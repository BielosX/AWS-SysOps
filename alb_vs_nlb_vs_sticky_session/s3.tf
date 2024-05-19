data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "ansible_bucket" {
  bucket        = "ansible-${local.region}-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "ansible_bucket_access_block" {
  bucket                  = aws_s3_bucket.ansible_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "ansible_bucket_ownership" {
  bucket = aws_s3_bucket.ansible_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket" "packages_bucket" {
  bucket        = "packages-${local.region}-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "packages_bucket_access_block" {
  bucket                  = aws_s3_bucket.packages_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "packages_bucket_ownership" {
  bucket = aws_s3_bucket.packages_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}