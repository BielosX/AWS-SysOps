resource "aws_vpc" "vpc" {
  cidr_block = var.cidr-block
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name: var.name-prefix
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public-subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name: "${var.name-prefix}-public-subnet"
  }
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name: "${var.name-prefix}-internet-gateway"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name: "${var.name-prefix}-public-route-table"
  }
}

resource "aws_route_table_association" "public-subnet-route-table-association" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.public-subnet.id
}

resource "aws_subnet" "private-subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name: "${var.name-prefix}-private-subnet"
  }
}

resource "aws_eip" "nat-gateway-eip" {
  vpc = true
  tags = {
    Name: "${var.name-prefix}-nat-gateway-eip"
  }
}

resource "aws_nat_gateway" "nat-gateway" {
  subnet_id = aws_subnet.public-subnet.id
  allocation_id = aws_eip.nat-gateway-eip.id
  tags = {
    Name: "${var.name-prefix}-nat-gateway"
  }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }

  tags = {
    Name: "${var.name-prefix}-private-route-table"
  }
}

resource "aws_route_table_association" "private-subnet-route-table-association" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id = aws_subnet.private-subnet.id
}