
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket-name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "public-access-block" {
  bucket = aws_s3_bucket.bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

data "aws_iam_policy_document" "bucket-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["s3:PutObject"]
    principals {
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
      type = "Service"
    }
    resources = [
      "${aws_s3_bucket.bucket.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = ["s3:PutObject"]
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type = "Service"
    }
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    condition {
      test = "StringEquals"
      variable     = "aws:SourceAccount"
      values   = [local.account-id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account-id}:*"]
    }
  }
  statement {
    effect = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type = "Service"
    }
    resources = [aws_s3_bucket.bucket.arn]
    condition {
      test = "StringEquals"
      variable     = "aws:SourceAccount"
      values   = [local.account-id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account-id}:*"]
    }
  }
  statement {
    effect = "Allow"
    actions = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${local.account-id}:root"]
      type = "AWS"
    }
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*"
    ]
  }
  dynamic "statement" {
    for_each = var.sse-s3-header-required ? [1] : []
    content {
      effect = "Deny"
      actions = ["s3:PutObject"]
      principals {
        identifiers = ["*"]
        type = "AWS"
      }
      resources = ["${aws_s3_bucket.bucket.arn}/*"]
      condition {
        test = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values = ["AES256"]
      }
    }
  }
  dynamic "statement" {
    for_each = var.sse-kms-header-required ? [1] : []
    content {
      effect = "Deny"
      actions = ["s3:PutObject"]
      principals {
        identifiers = ["*"]
        type = "AWS"
      }
      resources = ["${aws_s3_bucket.bucket.arn}/*"]
      condition {
        test = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values = ["aws:kms"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket-policy.json
}

resource "aws_s3_bucket_ownership_controls" "bucket-ownership" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}