provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_organizations_organization" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
  organization-id = data.aws_organizations_organization.current.id
}

resource "aws_s3_bucket" "demo-bucket" {
  bucket = "demo-bucket-${local.region}-${local.account-id}"
}

resource "aws_s3_bucket_ownership_controls" "bucket-ownership" {
  bucket = aws_s3_bucket.demo-bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "bucket-policy" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["*"]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    resources = [
      aws_s3_bucket.demo-bucket.arn,
      "${aws_s3_bucket.demo-bucket.arn}/*"
    ]
    condition {
      test = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values = [local.organization-id]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = aws_s3_bucket.demo-bucket.id
  policy = data.aws_iam_policy_document.bucket-policy.json
}

resource "aws_s3_bucket_public_access_block" "public-access-block" {
  bucket = aws_s3_bucket.demo-bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}