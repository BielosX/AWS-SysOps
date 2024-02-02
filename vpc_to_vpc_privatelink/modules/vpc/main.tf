data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc-cidr = "10.0.0.0/16"
  first-az = data.aws_availability_zones.available.names[0]
}

resource "aws_vpc" "vpc" {
  cidr_block           = local.vpc-cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}


resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(local.vpc-cidr, 8, 1)
  availability_zone       = local.first-az
  map_public_ip_on_launch = true
  tags = {
    Name : "public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(local.vpc-cidr, 8, 2)
  availability_zone       = local.first-az
  map_public_ip_on_launch = false
  tags = {
    Name : "private-subnet"
  }
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id
}
resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
}

resource "aws_route_table_association" "public-route-table-association" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }
}

resource "aws_route_table_association" "private-route-table-association" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id      = aws_subnet.private.id
}
