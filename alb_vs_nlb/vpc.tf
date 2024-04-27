locals {
  az_list_len = length(var.availability_zones)
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public_subnet" {
  count                   = local.az_list_len
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  cidr_block              = cidrsubnet(var.cidr_block, var.subnet_bits, count.index + 1)
  availability_zone       = var.availability_zones[count.index]
  tags = {
    Name : "public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  count                   = local.az_list_len
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
  cidr_block              = cidrsubnet(var.cidr_block, var.subnet_bits, count.index + 1 + local.az_list_len)
  availability_zone       = var.availability_zones[count.index]
  tags = {
    Name : "private-subnet"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name : "public-route-table"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  count          = local.az_list_len
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet[0].id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name : "private-route-table"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = local.az_list_len
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet[count.index].id
}
