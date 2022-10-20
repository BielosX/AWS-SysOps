provider "aws" {
  region = "eu-west-1"
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

resource "aws_security_group" "instance-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
  }
}

resource "aws_route_table_association" "public-route-table-association" {
  route_table_id = aws_route_table.public-subnet-table.id
  subnet_id = aws_subnet.public-subnet.id
}

resource "aws_iam_role" "ec2-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  ]
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.ec2-role.id
}

resource "aws_imagebuilder_infrastructure_configuration" "builder-infra" {
  instance_profile_name = aws_iam_instance_profile.instance-profile.id
  name = "builder-infra"
  instance_types = ["t3.micro"]
  subnet_id = aws_subnet.public-subnet.id
  security_group_ids = [aws_security_group.instance-sg.id]
  terminate_instance_on_failure = true
}

resource "aws_imagebuilder_component" "web-component" {
  name = "web-component"
  platform = "Linux"
  version  = "1.0.0"
  data = file("${path.module}/build.yaml")
}

resource "aws_imagebuilder_image_recipe" "web-image-recipe" {
  name = "web-image-recipe"
  parent_image = data.aws_ami.amazon-linux-2.id
  version = "1.0.0"
  component {
    component_arn = aws_imagebuilder_component.web-component.arn
  }
}

resource "aws_imagebuilder_image_pipeline" "web-image-pipeline" {
  name = "web-image-pipeline"
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.builder-infra.arn
  image_recipe_arn = aws_imagebuilder_image_recipe.web-image-recipe.arn

  image_tests_configuration {
    image_tests_enabled = false
  }

  schedule {
    schedule_expression = "rate(1 day)"
  }
}