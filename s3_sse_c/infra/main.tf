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

resource "aws_s3_bucket_acl" "demo-bucket-acl" {
  bucket = aws_s3_bucket.demo-bucket.id
  acl = "private"
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

resource "aws_dynamodb_table" "demo-bucket-key-table" {
  name = "demo-bucket-key-table"
  hash_key = "path"
  billing_mode = "PROVISIONED"
  write_capacity = 1
  read_capacity = 1
  attribute {
    name = "path"
    type = "S"
  }
}