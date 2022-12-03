provider "aws" {}

module "vpc" {
  source = "../simple_vpc"
  cidr-block = "10.0.0.0/16"
  name-prefix = "demo-vpc"
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
    security_groups = [aws_security_group.instance-sg.id]
    protocol  = "tcp"
    from_port = 2049
    to_port   = 2049
  }
}

resource "aws_efs_mount_target" "mount-target" {
  file_system_id = aws_efs_file_system.file-system.id
  subnet_id = module.vpc.public-subnet-id
  security_groups = [aws_security_group.mount-target-sg.id]
}

resource "aws_efs_access_point" "fist-access-point" {
  file_system_id = aws_efs_file_system.file-system.id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/first"
    creation_info {
      owner_gid = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }
}

resource "aws_efs_access_point" "root-access-point" {
  file_system_id = aws_efs_file_system.file-system.id
  posix_user {
    gid = 1001
    uid = 1001
  }
  root_directory {
    path = "/"
    creation_info {
      owner_gid = 1001
      owner_uid = 1001
      permissions = "777"
    }
  }
}

locals {
  access-points = [
    aws_efs_access_point.fist-access-point.id,
    aws_efs_access_point.root-access-point.id
  ]
}

resource "aws_eip" "eip" {
  count = 2
  vpc = true
}

module "instance" {
  count = 2
  source = "../amzn_linux2_instance"
  instance-type = "t3.nano"
  name = "demo-instance"
  security-group-ids = [aws_security_group.instance-sg.id]
  subnet-id = module.vpc.public-subnet-id
  user-data = templatefile("${path.module}/init.sh.tmpl", {
    file-system-id: aws_efs_file_system.file-system.id,
    access-point-id: local.access-points[count.index],
    eip-addr: aws_eip.eip[count.index].public_ip
  })
}

resource "aws_eip_association" "eip-association" {
  count = 2
  allocation_id = aws_eip.eip[count.index].id
  instance_id = module.instance[count.index].instance-id
}