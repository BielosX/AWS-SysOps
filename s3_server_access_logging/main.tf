provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

resource "aws_s3_bucket" "target-bucket" {
  bucket = "s3-access-logging-target-bucket-${local.region}-${local.account-id}"
  force_destroy = true
}

resource "aws_s3_bucket" "source-bucket" {
  bucket = "s3-access-logging-source-bucket-${local.region}-${local.account-id}"
  force_destroy = true
}

data "aws_iam_policy_document" "source-bucket-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${local.account-id}:root"]
      type = "AWS"
    }
    resources = [
      aws_s3_bucket.source-bucket.arn,
      "${aws_s3_bucket.source-bucket.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "source-bucket-policy" {
  bucket = aws_s3_bucket.source-bucket.id
  policy = data.aws_iam_policy_document.source-bucket-policy.json
}

locals {
  source-bucket-target-prefix = "${aws_s3_bucket.source-bucket.id}/"
}

resource "aws_s3_bucket_logging" "source-bucket-logging" {
  bucket = aws_s3_bucket.source-bucket.id
  target_bucket = aws_s3_bucket.target-bucket.id
  target_prefix = local.source-bucket-target-prefix
}

data "aws_iam_policy_document" "target-bucket-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["*"]
    principals {
      identifiers = ["logging.s3.amazonaws.com"]
      type = "Service"
    }
    resources = ["${aws_s3_bucket.target-bucket.arn}/${local.source-bucket-target-prefix}*"]
    condition {
      test = "ArnLike"
      variable = "aws:SourceArn"
      values = [aws_s3_bucket.source-bucket.arn]
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceAccount"
      values = [local.account-id]
    }
  }
}

resource "aws_s3_bucket_policy" "target-bucket-policy" {
  bucket = aws_s3_bucket.target-bucket.id
  policy = data.aws_iam_policy_document.target-bucket-policy.json
}

resource "aws_s3_bucket_public_access_block" "source-bucket-public-access-block" {
  bucket = aws_s3_bucket.source-bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "target-bucket-public-access-block" {
  bucket = aws_s3_bucket.target-bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "source-bucket-ownership" {
  bucket = aws_s3_bucket.source-bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "target-bucket-ownership" {
  bucket = aws_s3_bucket.target-bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
