provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

resource "aws_s3_bucket" "demo-bucket" {
  bucket = "demo-bucket-${local.region}-${local.account-id}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "demo-bucket-acl" {
  bucket = aws_s3_bucket.demo-bucket.id
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "demo-bucket-public-access-block" {
  bucket = aws_s3_bucket.demo-bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


resource "aws_s3_access_point" "demo-bucket-access-point" {
  bucket = aws_s3_bucket.demo-bucket.id
  name = "demo-bucket-access-point"

  lifecycle {
    ignore_changes = [policy]
  }
}

data "aws_iam_policy_document" "demo-bucket-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = ["*"]
      type = "AWS"
    }
    actions = ["*"]
    resources = [
      aws_s3_bucket.demo-bucket.arn,
      "${aws_s3_bucket.demo-bucket.arn}/*"
    ]
    condition {
      test = "StringEquals"
      variable = "s3:DataAccessPointAccount"
      values = [local.account-id]
    }
  }
}

resource "aws_s3_bucket_policy" "demo-bucket-policy" {
  bucket = aws_s3_bucket.demo-bucket.id
  policy = data.aws_iam_policy_document.demo-bucket-policy.json
}

data "aws_iam_policy_document" "lambda-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  /*
  Workaround for 'MalformedPolicyDocument: Invalid principal in policy'
  */
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

data "aws_iam_policy_document" "ap-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    principals {
      identifiers = [aws_iam_role.lambda-role.arn]
      type = "AWS"
    }
    /*
   ARNs for objects accessed through an access point use the format
   arn:aws:s3:region:account-id:accesspoint/access-point-name/object/resource
    */
    resources = ["${aws_s3_access_point.demo-bucket-access-point.arn}/object/lambda/*"]
  }
}

resource "aws_s3control_access_point_policy" "demo-bucket-ap-policy" {
  access_point_arn = aws_s3_access_point.demo-bucket-access-point.arn
  policy = data.aws_iam_policy_document.ap-policy.json
}

locals {
  lambda-file = "${path.module}/lambda/dist/lambda.zip"
}

resource "aws_lambda_function" "demo-lambda" {
  function_name = "demo-lambda"
  role = aws_iam_role.lambda-role.arn
  handler = "index.handler"
  runtime = "nodejs16.x"
  filename = local.lambda-file
  source_code_hash = filebase64sha256(local.lambda-file)
  environment {
    variables = {
      BUCKET: aws_s3_bucket.demo-bucket.id,
      AP_ARN: aws_s3_access_point.demo-bucket-access-point.arn
    }
  }
}