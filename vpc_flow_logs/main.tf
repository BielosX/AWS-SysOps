provider "aws" {}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "public-subnet" {
  vpc_id = aws_vpc.demo-vpc.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, 1)
  tags = {
    Name: "public-subnet"
  }
}

resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.demo-vpc.id
}

resource "aws_route_table" "public-subnet-table" {
  vpc_id = aws_vpc.demo-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }
  tags = {
    Name: "public-route-table"
  }
}

resource "aws_route_table_association" "public-route-table-association" {
  route_table_id = aws_route_table.public-subnet-table.id
  subnet_id = aws_subnet.public-subnet.id
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

resource "aws_iam_role" "instance-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.instance-role.id
}

resource "aws_security_group" "instance-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    to_port = 22
    from_port = 22
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }
}

resource "aws_instance" "demo-instance" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  user_data_base64 = base64encode(file("${path.module}/init.sh"))
  user_data_replace_on_change = true
  tags = {
    Name: "demo-instance"
  }
}

resource "aws_cloudwatch_log_group" "vpc-flow-log-group" {
  name = "vpc-flow-log-group"
}

data "aws_iam_policy_document" "flow-log-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["vpc-flow-logs.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "flow-log-role" {
  assume_role_policy = data.aws_iam_policy_document.flow-log-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"]
}

resource "aws_flow_log" "vpc-flow-log" {
  traffic_type = "ALL"
  vpc_id = aws_vpc.demo-vpc.id
  log_destination_type = "cloud-watch-logs"
  log_destination = aws_cloudwatch_log_group.vpc-flow-log-group.arn
  iam_role_arn = aws_iam_role.flow-log-role.arn
}

resource "aws_cloudwatch_log_group" "public-subnet-flow-log-group" {
  name = "public-subnet-flow-log-group"
}

resource "aws_flow_log" "public-subnet-flow-log" {
  traffic_type = "ALL"
  subnet_id = aws_subnet.public-subnet.id
  log_destination_type = "cloud-watch-logs"
  log_destination = aws_cloudwatch_log_group.public-subnet-flow-log-group.arn
  iam_role_arn = aws_iam_role.flow-log-role.arn
}

locals {
  queries = [
    ["accepted-requests", "${path.module}/accepted-requests.query"],
    ["rejected-requests", "${path.module}/rejected-requests.query"]
  ]
}

resource "aws_cloudwatch_query_definition" "vpc-queries" {
  count = length(local.queries)
  name = "vpc-${local.queries[count.index][0]}"
  log_group_names = [aws_cloudwatch_log_group.vpc-flow-log-group.id]
  query_string = file(local.queries[count.index][1])
}

resource "aws_cloudwatch_query_definition" "subnet-queries" {
  count = length(local.queries)
  name = "public-subnet-${local.queries[count.index][0]}"
  log_group_names = [aws_cloudwatch_log_group.public-subnet-flow-log-group.id]
  query_string = file(local.queries[count.index][1])
}

resource "aws_cloudwatch_log_group" "network-interface-flow-log-group" {
  name = "network-interface-flow-log-group"
}

resource "aws_flow_log" "network-interface-flow-log" {
  traffic_type = "ALL"
  eni_id = aws_instance.demo-instance.primary_network_interface_id
  log_destination_type = "cloud-watch-logs"
  log_destination = aws_cloudwatch_log_group.network-interface-flow-log-group.arn
  iam_role_arn = aws_iam_role.flow-log-role.arn
}
resource "aws_cloudwatch_query_definition" "network-interface-queries" {
  count = length(local.queries)
  name = "network-interface-${local.queries[count.index][0]}"
  log_group_names = [aws_cloudwatch_log_group.network-interface-flow-log-group.id]
  query_string = file(local.queries[count.index][1])
}
