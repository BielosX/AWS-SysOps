provider "aws" {
  region = "eu-west-1"
}

locals {
  db-port = 5432
}

resource "random_password" "cluster-password" {
  length = 16
  min_lower = 2
  min_upper = 2
  min_numeric = 2
  min_special = 2
}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public-subnet" {
  vpc_id = aws_vpc.demo-vpc.id
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name: "Public"
  }
}

resource "aws_subnet" "private-subnets" {
  count = 2
  vpc_id = aws_vpc.demo-vpc.id
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name: "Private"
  }
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.demo-vpc.id
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.demo-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
  tags = {
    Name: "public-route-table"
  }
}

resource "aws_route_table_association" "public-route-table-association" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.public-subnet.id
}

resource "aws_ssm_parameter" "aurora-master-password" {
  name = "aurora-master-password"
  type = "SecureString"
  value = random_password.cluster-password.result
}

resource "aws_db_subnet_group" "aurora-cluster-subnets" {
  subnet_ids = [aws_subnet.private-subnets[0].id, aws_subnet.private-subnets[1].id]
}

resource "aws_security_group" "aurora-cluster-security-group" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = local.db-port
    to_port = local.db-port
  }
}

resource "aws_security_group" "jump-box-security-group" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  egress {
    security_groups = [aws_security_group.aurora-cluster-security-group.id]
    protocol = "tcp"
    from_port = local.db-port
    to_port = local.db-port
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port  = 443
  }
}

resource "aws_rds_cluster" "aurora-cluster" {
  cluster_identifier = "aurora-cluster"
  engine = "aurora-postgresql"
  engine_mode = "provisioned"
  database_name = "postgres"
  engine_version = "14.4"
  apply_immediately = true
  skip_final_snapshot = true
  master_password = aws_ssm_parameter.aurora-master-password.value
  master_username = "master"
  iam_database_authentication_enabled = true
  db_subnet_group_name = aws_db_subnet_group.aurora-cluster-subnets.id
  vpc_security_group_ids = [aws_security_group.aurora-cluster-security-group.id]
  port = local.db-port

  serverlessv2_scaling_configuration {
    max_capacity = 1
    min_capacity = 0.5
  }
}

resource "aws_rds_cluster_instance" "aurora-cluster-instance" {
  cluster_identifier = aws_rds_cluster.aurora-cluster.cluster_identifier
  instance_class = "db.serverless"
  engine = aws_rds_cluster.aurora-cluster.engine
  engine_version = aws_rds_cluster.aurora-cluster.engine_version
  apply_immediately = true
  performance_insights_enabled = true
}

data "aws_ami" "amazon-linux-2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_iam_policy_document" "ec2-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "ec2-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.ec2-role.id
}

resource "aws_instance" "jump-box" {
  ami = data.aws_ami.amazon-linux-2.image_id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public-subnet.id
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  vpc_security_group_ids = [aws_security_group.jump-box-security-group.id]
  tags = {
    Name: "jump-box"
  }
}