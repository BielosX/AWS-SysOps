provider "aws" {
  region = "eu-west-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
  trail-name = "backup-trail"
}

data "aws_iam_policy_document" "key-policy" {
  statement {
    effect = "Allow"
    actions = ["kms:*"]
    principals {
      identifiers = ["backup.amazonaws.com"]
      type = "Service"
    }
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = ["kms:*"]
    principals {
      identifiers = [data.aws_caller_identity.current.arn]
      type = "AWS"
    }
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = ["kms:*"]
    principals {
      identifiers = ["arn:aws:iam::${local.account-id}:root"]
      type = "AWS"
    }
    resources = ["*"]
  }
}

resource "aws_kms_key" "aws-backup-key" {
  deletion_window_in_days = 7
  key_usage = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  policy = data.aws_iam_policy_document.key-policy.json
}

resource "aws_backup_vault" "backup-vault" {
  name = "backup-vault"
  force_destroy = true
  kms_key_arn = aws_kms_key.aws-backup-key.arn
}

resource "aws_backup_plan" "s3-backup-plan" {
  name = "s3-backup-plan"
  rule {
    rule_name = "s3-backup-rule"
    target_vault_name = aws_backup_vault.backup-vault.id
    schedule = "cron(0 * ? * * *)"
    enable_continuous_backup = true

    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_s3_bucket" "demo-bucket" {
  bucket = "demo-bucket-${local.region}-${local.account-id}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "demo-bucket-acl" {
  bucket = aws_s3_bucket.demo-bucket.id
  acl = "private"
}

// Required for Backup
resource "aws_s3_bucket_versioning" "demo-bucket-versioning" {
  bucket = aws_s3_bucket.demo-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "backup-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["backup.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "backup-role" {
  name = "backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup-assume-role.json
  force_detach_policies = true
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup",
    "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
  ]
}

resource "aws_backup_selection" "s3-backup-selection" {
  name = "s3-backup-selection"
  iam_role_arn = aws_iam_role.backup-role.arn
  plan_id = aws_backup_plan.s3-backup-plan.id
  resources = [
    aws_s3_bucket.demo-bucket.arn
  ]
}

resource "aws_s3_bucket" "backup-trail" {
  bucket = "backup-trail-${local.region}-${local.account-id}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "backup-trail-acl" {
  bucket = aws_s3_bucket.backup-trail.id
  acl = "private"
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
    resources = [aws_s3_bucket.backup-trail.arn]
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
    resources = ["${aws_s3_bucket.backup-trail.arn}/AWSLogs/${local.account-id}/*"]
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

resource "aws_s3_bucket_policy" "backup-trail-bucket-policy" {
  bucket = aws_s3_bucket.backup-trail.id
  policy = data.aws_iam_policy_document.bucket-policy-document.json
}

resource "aws_cloudwatch_log_group" "backup-trail-log-group" {
  name = "backup-trail-log-group"
}

resource "aws_cloudwatch_query_definition" "backup-logs" {
  name = "backup-logs"
  query_string = file("${path.module}/select-backup-logs.query")
  log_group_names = [aws_cloudwatch_log_group.backup-trail-log-group.name]
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

resource "aws_iam_role" "trail-role" {
  assume_role_policy = data.aws_iam_policy_document.trail-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchFullAccess"]
}

resource "aws_cloudtrail" "backup-trail" {
  name = local.trail-name
  s3_bucket_name = aws_s3_bucket.backup-trail.id
  enable_logging = true
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.backup-trail-log-group.arn}:*"
  cloud_watch_logs_role_arn = aws_iam_role.trail-role.arn
  advanced_event_selector {
    name = "select-backup"
    field_selector {
      field = "eventCategory"
      equals = ["Management"]
    }
  }
}