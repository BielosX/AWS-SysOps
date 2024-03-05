locals {
  private_subnets = 2
  public_subnets  = 2
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "public_subnets" {
  count                   = local.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = true
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 1)
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private_subnets" {
  count                   = local.private_subnets
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = false
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + local.public_subnets + 1)
  tags = {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = local.public_subnets
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = local.private_subnets
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}
