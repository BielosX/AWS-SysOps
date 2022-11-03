provider "aws" {}

module "first-vpc" {
  source = "../simple_vpc"
  cidr-block = "10.0.0.0/16"
  name-prefix = "first-vpc"
}

module "second-vpc" {
  source = "../simple_vpc"
  cidr-block = "192.168.0.0/16"
  name-prefix = "second-vpc"
}

resource "aws_vpc_peering_connection" "vpc-peering" {
  peer_vpc_id = module.second-vpc.vpc-id
  vpc_id = module.first-vpc.vpc-id
  auto_accept = true
}

resource "aws_route" "from-first-to-second-public" {
  route_table_id = module.first-vpc.public-route-table-id
  destination_cidr_block = module.second-vpc.vpc-cidr-block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
}

resource "aws_route" "from-first-to-second-private" {
  route_table_id = module.first-vpc.private-route-table-id
  destination_cidr_block = module.second-vpc.vpc-cidr-block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
}

resource "aws_route" "from-second-to-first-public" {
  route_table_id = module.second-vpc.public-route-table-id
  destination_cidr_block = module.first-vpc.vpc-cidr-block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
}

resource "aws_route" "from-second-to-first-private" {
  route_table_id = module.second-vpc.private-route-table-id
  destination_cidr_block = module.first-vpc.vpc-cidr-block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
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

resource "aws_security_group" "instance-sg" {
  vpc_id = module.second-vpc.vpc-id
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

resource "aws_instance" "demo-instance" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.nano"
  subnet_id = module.second-vpc.private-subnet-id
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  user_data = file("${path.module}/init.sh")
}

resource "aws_eip" "demo-instance-eip" {
  vpc = true
  instance = aws_instance.demo-instance.id
}

resource "aws_security_group" "inbound-endpoint-sg" {
  vpc_id = module.second-vpc.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 53
    to_port   = 53
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "udp"
    from_port = 53
    to_port   = 53
  }
}

resource "aws_route53_resolver_endpoint" "inbound-endpoint" {
  direction = "INBOUND"
  security_group_ids = [aws_security_group.inbound-endpoint-sg.id]
  ip_address {
    subnet_id = module.second-vpc.private-subnet-id
  }
  ip_address {
    subnet_id = module.second-vpc.public-subnet-id
  }
}

resource "aws_security_group" "outbound-endpoint-sg" {
  vpc_id = module.first-vpc.vpc-id
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 53
    to_port   = 53
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "udp"
    from_port = 53
    to_port   = 53
  }
}

resource "aws_route53_resolver_endpoint" "outbound-endpoint" {
  direction = "OUTBOUND"
  security_group_ids = [aws_security_group.outbound-endpoint-sg.id]
  ip_address {
    subnet_id = module.first-vpc.public-subnet-id
  }
  ip_address {
    subnet_id = module.first-vpc.private-subnet-id
  }
}

resource "aws_route53_resolver_rule" "outbound-rule" {
  domain_name = "www.demo.bielosx.com"
  rule_type = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound-endpoint.id

  target_ip {
    ip = tolist(aws_route53_resolver_endpoint.inbound-endpoint.ip_address)[0].ip
  }
  target_ip {
    ip = tolist(aws_route53_resolver_endpoint.inbound-endpoint.ip_address)[1].ip
  }
}

resource "aws_route53_resolver_rule_association" "outbound-rule-association" {
  resolver_rule_id = aws_route53_resolver_rule.outbound-rule.id
  vpc_id = module.first-vpc.vpc-id
}

resource "aws_route53_zone" "second-vpc-zone" {
  name = "demo.bielosx.com"

  vpc {
    vpc_id = module.second-vpc.vpc-id
  }
}

resource "aws_route53_record" "second-vpc-zone-record" {
  name = "www.demo.bielosx.com"
  type = "A"
  ttl = 60
  zone_id = aws_route53_zone.second-vpc-zone.id
  records = [aws_eip.demo-instance-eip.private_ip]
}

resource "aws_security_group" "jump-box-sg" {
  vpc_id = module.first-vpc.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  egress {
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
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 53
    to_port = 53
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "udp"
    from_port = 53
    to_port = 53
  }
}

resource "aws_instance" "jump-box" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.nano"
  subnet_id = module.first-vpc.public-subnet-id
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  vpc_security_group_ids = [aws_security_group.jump-box-sg.id]
  tags = {
    Name: "jump-box"
  }
}
