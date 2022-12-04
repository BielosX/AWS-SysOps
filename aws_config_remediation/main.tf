provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

module "private-bucket" {
  source = "../private_bucket"
  bucket-name = "config-${local.region}-${local.account-id}"
}

resource "aws_sns_topic" "config-topic" {
  name = "config-topic"
}

resource "aws_sns_topic_subscription" "email-subscription" {
  endpoint = var.email
  protocol = "email"
  topic_arn = aws_sns_topic.config-topic.arn
}

resource "aws_config_delivery_channel" "delivery-channel" {
  name = "demo-delivery-channel"
  s3_bucket_name = module.private-bucket.id
  sns_topic_arn = aws_sns_topic.config-topic.arn
  depends_on = [aws_config_configuration_recorder.config-recorder]
}

data "aws_iam_policy_document" "recorder-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["config.amazonaws.com"]
      type = "Service"
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceAccount"
      values = [local.account-id]
    }
  }
}

data "aws_iam_policy_document" "recorder-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${module.private-bucket.arn}/AWSLogs/${local.account-id}/*"]
  }
  statement {
    effect = "Allow"
    actions = ["sns:Publish"]
    resources = [aws_sns_topic.config-topic.arn]
  }
}

resource "aws_iam_role" "recorder-role" {
  assume_role_policy = data.aws_iam_policy_document.recorder-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
  ]
  inline_policy {
    name = "recorder-policy"
    policy = data.aws_iam_policy_document.recorder-policy.json
  }
}

resource "aws_config_configuration_recorder" "config-recorder" {
  name = "demo-config-recorder"
  role_arn = aws_iam_role.recorder-role.arn
  recording_group {
    all_supported = false
    resource_types = ["AWS::EC2::SecurityGroup"]
  }
}

resource "aws_config_configuration_recorder_status" "recorder-status" {
  is_enabled = true
  name = aws_config_configuration_recorder.config-recorder.id
  depends_on = [aws_config_delivery_channel.delivery-channel]
}

resource "aws_config_config_rule" "config-rule" {
  depends_on = [aws_config_configuration_recorder.config-recorder]
  name = "restricted-ssh"
  source {
    owner = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }
}

data "aws_iam_policy_document" "ssm-automation-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ssm.amazonaws.com"]
      type = "Service"
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceAccount"
      values = [local.account-id]
    }
    condition {
      test = "ArnLike"
      variable = "aws:SourceArn"
      values = ["arn:aws:ssm:*:${local.account-id}:automation-execution/*"]
    }
  }
}

resource "aws_iam_role" "ssh-remediation-role" {
  assume_role_policy = data.aws_iam_policy_document.ssm-automation-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  ]
}

resource "aws_config_remediation_configuration" "ssh-remediation" {
  config_rule_name = aws_config_config_rule.config-rule.id
  target_id = "AWS-DisablePublicAccessForSecurityGroup"
  target_type = "SSM_DOCUMENT"
  resource_type = "AWS::EC2::SecurityGroup"
  target_version = "1"

  parameter {
    name = "AutomationAssumeRole"
    static_value = aws_iam_role.ssh-remediation-role.arn
  }

  parameter {
    name = "GroupId"
    resource_value = "RESOURCE_ID"
  }

  execution_controls {
    ssm_controls {
      concurrent_execution_rate_percentage = 25
      error_percentage = 20
    }
  }

  automatic = true
  maximum_automatic_attempts = 5
  retry_attempt_seconds = 60
}