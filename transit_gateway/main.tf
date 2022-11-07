locals {
  cidr-blocks = {
    first = "10.0.0.0/16",
    second = "10.1.0.0/16",
    third = "10.2.0.0/16"
  }
  connections = {
    for s in setproduct(keys(local.cidr-blocks), keys(local.cidr-blocks)): s[0] => s[1]...
    if s[0] != s[1]
  }
}

module "demo-vpcs" {
  for_each = local.cidr-blocks
  source = "../simple_vpc"
  cidr-block = each.value
  name-prefix = each.key
}

resource "aws_security_group" "instance-sg" {
  for_each = local.cidr-blocks
  vpc_id = module.demo-vpcs[each.key].vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
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
}

module "instances" {
  for_each = local.cidr-blocks
  source = "../amzn_linux2_instance"
  instance-type = "t3.nano"
  name = "${each.key}-demo-instance"
  security-group-ids = [aws_security_group.instance-sg[each.key].id]
  subnet-id = module.demo-vpcs[each.key].private-subnet-id
  user-data = file("${path.module}/init.sh")
  managed-policy-arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_ec2_transit_gateway" "transit-gateway" {
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc-attachment" {
  for_each = local.cidr-blocks
  subnet_ids = [module.demo-vpcs[each.key].private-subnet-id]
  transit_gateway_id = aws_ec2_transit_gateway.transit-gateway.id
  vpc_id = module.demo-vpcs[each.key].vpc-id
}

resource "aws_route" "first-to-gateway-routes" {
  for_each = toset(lookup(local.connections, "first", []))
  route_table_id = module.demo-vpcs["first"].private-route-table-id
  destination_cidr_block = module.demo-vpcs[each.value].vpc-cidr-block
  transit_gateway_id = aws_ec2_transit_gateway.transit-gateway.id
}

resource "aws_route" "second-to-gateway-routes" {
  for_each = toset(lookup(local.connections, "second", []))
  route_table_id = module.demo-vpcs["second"].private-route-table-id
  destination_cidr_block = module.demo-vpcs[each.value].vpc-cidr-block
  transit_gateway_id = aws_ec2_transit_gateway.transit-gateway.id
}

resource "aws_route" "third-to-gateway-routes" {
  for_each = toset(lookup(local.connections, "third", []))
  route_table_id = module.demo-vpcs["third"].private-route-table-id
  destination_cidr_block = module.demo-vpcs[each.value].vpc-cidr-block
  transit_gateway_id = aws_ec2_transit_gateway.transit-gateway.id
}

resource "aws_ssm_document" "curl-target" {
  name = "curl-target"
  content = file("${path.module}/curl.yaml")
  document_format = "YAML"
  document_type = "Command"
}