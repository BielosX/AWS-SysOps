provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
  trail-name = "demo-trail"
}

resource "aws_s3_bucket" "demo-bucket" {
  bucket = "demo-trail-${local.region}-${local.account-id}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "demo-bucket-acl" {
  bucket = aws_s3_bucket.demo-bucket.id
  acl = "private"
}

resource "aws_cloudwatch_log_group" "trail-log-group" {
  name_prefix = "demo-trail-log-group"
}

data "aws_iam_policy_document" "trail-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["cloudtrail.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "demo-trail-role" {
  assume_role_policy = data.aws_iam_policy_document.trail-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchFullAccess"]
}

data "aws_iam_policy_document" "bucket-policy-document" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = ["cloudtrail.amazonaws.com"]
      type = "Service"
    }
    actions = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.demo-bucket.arn]
    condition {
      test = "StringEquals"
      variable = "aws:SourceArn"
      values = ["arn:aws:cloudtrail:${local.region}:${local.account-id}:trail/${local.trail-name}"]
    }
  }
  statement {
    effect = "Allow"
    principals {
      identifiers = ["cloudtrail.amazonaws.com"]
      type = "Service"
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.demo-bucket.arn}/AWSLogs/${local.account-id}/*"]
    condition {
      test = "StringEquals"
      variable = "aws:SourceArn"
      values = ["arn:aws:cloudtrail:${local.region}:${local.account-id}:trail/${local.trail-name}"]
    }
    condition {
      test = "StringEquals"
      variable = "s3:x-amz-acl"
      values = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail-bucket-policy" {
  bucket = aws_s3_bucket.demo-bucket.id
  policy = data.aws_iam_policy_document.bucket-policy-document.json
}

resource "aws_cloudtrail" "demo-trail" {
  depends_on = [aws_s3_bucket_policy.trail-bucket-policy]
  name = local.trail-name
  s3_bucket_name = aws_s3_bucket.demo-bucket.id
  include_global_service_events = true
  is_multi_region_trail = true
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail-log-group.arn}:*"
  cloud_watch_logs_role_arn = aws_iam_role.demo-trail-role.arn
}

resource "aws_cloudwatch_query_definition" "who-deleted-queue" {
  name = "who-deleted-queue"
  log_group_names = [aws_cloudwatch_log_group.trail-log-group.name]
  query_string = file("${path.module}/who-deleted-queue.query")
}

resource "aws_cloudwatch_query_definition" "number-of-queue-deletes-in-5minutes" {
  name = "number-of-queue-deletes-in-5minutes"
  log_group_names = [aws_cloudwatch_log_group.trail-log-group.name]
  query_string = file("${path.module}/number-of-queue-deletes-in-5minutes.query")
}
