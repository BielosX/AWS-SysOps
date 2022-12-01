
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket-name
}

resource "aws_s3_bucket_public_access_block" "public-access-block" {
  bucket = aws_s3_bucket.bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "bucket-policy" {
  version = "2012-10-17"
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
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket-policy.json
}