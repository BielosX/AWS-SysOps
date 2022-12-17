provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  account-id = data.aws_caller_identity.current.account_id
}

resource "aws_kms_key" "demo-key" {
  key_usage = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "key-alias" {
  target_key_id = aws_kms_key.demo-key.id
  name = "alias/demo-key"
}

module "sse-s3-bucket" {
  source = "../private_bucket"
  bucket-name = "sse-s3-bucket-${local.region}-${local.account-id}"
  sse-s3-header-required = true
}

module "sse-kms-bucket" {
  source = "../private_bucket"
  bucket-name = "sse-kms-bucket-${local.region}-${local.account-id}"
  sse-kms-header-required = true
}