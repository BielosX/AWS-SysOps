provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  account-id = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "demo-bucket" {
  bucket = "demo-bucket-${local.region}-${local.account-id}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "demo-bucket-lifecycle" {
  bucket = aws_s3_bucket.demo-bucket.id
  rule {
    id = "incomplete-multipart"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_public_access_block" "demo-bucket-public-access-block" {
  bucket = aws_s3_bucket.demo-bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "demo-bucket-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${local.account-id}:root"]
      type = "AWS"
    }
    resources = [
      aws_s3_bucket.demo-bucket.arn,
      "${aws_s3_bucket.demo-bucket.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "demo-bucket-policy" {
  bucket = aws_s3_bucket.demo-bucket.id
  policy = data.aws_iam_policy_document.demo-bucket-policy.json
}

resource "aws_s3_bucket_ownership_controls" "demo-bucket-ownership" {
  bucket = aws_s3_bucket.demo-bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}