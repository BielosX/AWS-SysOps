provider "aws" {}

module "vpc" {
  source = "../simple_vpc"
  cidr-block = "10.0.0.0/16"
  name-prefix = "simple"
}

resource "aws_efs_file_system" "file-system" {
  availability_zone_name = module.vpc.public-subnet-az // OneZone deployment
}

resource "aws_security_group" "instance-sg" {
  vpc_id = module.vpc.vpc-id
  egress {
    cidr_blocks = [module.vpc.vpc-cidr-block]
    protocol  = "tcp"
    from_port = 2049
    to_port   = 2049
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 20
    to_port  = 21
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 10090
    to_port = 10100
  }
}

resource "aws_security_group" "mount-target-sg" {
  vpc_id = module.vpc.vpc-id
  ingress {
    cidr_blocks = [module.vpc.vpc-cidr-block]
    protocol  = "tcp"
    from_port = 2049
    to_port   = 2049
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 0
    to_port   = 65353
  }
}

resource "aws_efs_mount_target" "mount-target" {
  file_system_id = aws_efs_file_system.file-system.id
  subnet_id = module.vpc.public-subnet-id
  security_groups = [aws_security_group.mount-target-sg.id]
}

resource "aws_eip" "eip" {
  vpc = true
}

module "instance" {
  source = "../amzn_linux2_instance"
  instance-type = "t3.nano"
  name = "demo-instance"
  security-group-ids = [aws_security_group.instance-sg.id]
  managed-policy-arns = ["arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"]
  subnet-id = module.vpc.public-subnet-id
  user-data = templatefile("${path.module}/init.sh.tmpl", {
    file-system-id: aws_efs_file_system.file-system.id,
    eip-addr: aws_eip.eip.public_ip
  })
}

resource "aws_eip_association" "eip-association" {
  allocation_id = aws_eip.eip.id
  instance_id = module.instance.instance-id
}

data "aws_iam_policy_document" "data-sync-assume-role" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["datasync.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "data-sync-role" {
  assume_role_policy = data.aws_iam_policy_document.data-sync-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]
}

resource "aws_datasync_location_efs" "efs-location" {
  depends_on = [aws_efs_mount_target.mount-target]
  efs_file_system_arn = aws_efs_file_system.file-system.arn
  file_system_access_role_arn = aws_iam_role.data-sync-role.arn
  in_transit_encryption = "TLS1_2"
  ec2_config {
    security_group_arns = [aws_security_group.mount-target-sg.arn]
    subnet_arn = module.vpc.public-subnet-arn
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

module "bucket" {
  source = "../private_bucket"
  bucket-name = "datasync-bucket-${local.region}-${local.account-id}"
}

resource "aws_datasync_location_s3" "s3-location" {
  s3_bucket_arn = module.bucket.arn
  subdirectory  = "/datasync"
  s3_config {
    bucket_access_role_arn = aws_iam_role.data-sync-role.arn
  }
}

resource "aws_datasync_task" "task" {
  name = "efs-to-s3"
  destination_location_arn = aws_datasync_location_s3.s3-location.arn
  source_location_arn = aws_datasync_location_efs.efs-location.arn

  schedule {
    schedule_expression = "cron(0 12 ? * SUN,WED *)"
  }

  excludes {
    filter_type = "SIMPLE_PATTERN"
    value = "/excluded"
  }
}