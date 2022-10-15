data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "db-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

locals {
  public-subnets = 3
}

resource "aws_subnet" "public-subnets" {
  count = local.public-subnets
  vpc_id = aws_vpc.db-vpc.id
  cidr_block = cidrsubnet(aws_vpc.db-vpc.cidr_block, 4, count.index + 1)
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.db-vpc.id
}

resource "aws_route_table" "public-subnet-table" {
  vpc_id = aws_vpc.db-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
}

resource "aws_route_table_association" "public-subnet-association" {
  count = local.public-subnets
  route_table_id = aws_route_table.public-subnet-table.id
  subnet_id = aws_subnet.public-subnets[count.index].id
}

resource "aws_db_subnet_group" "db-subnet-group" {
  subnet_ids = aws_subnet.public-subnets[*].id
}

locals {
  postgres-port = 5432
}

resource "aws_security_group" "db-security-group" {
  vpc_id = aws_vpc.db-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = local.postgres-port
    to_port = local.postgres-port
  }
}

resource "aws_rds_cluster" "aurora-postgresql-cluster" {
  cluster_identifier = "demo-aurora-cluster"
  engine = "aurora-postgresql"
  database_name = "postgres"
  master_username = "master"
  master_password = "master123!"
  engine_version = "14.4"
  skip_final_snapshot = true
  apply_immediately = true
  port = local.postgres-port
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.id
  vpc_security_group_ids = [aws_security_group.db-security-group.id]
  snapshot_identifier = var.snapshot-id == "" ? null : var.snapshot-id
}

resource "aws_rds_cluster_instance" "aurora-postgres-cluster-instance" {
  count = 2
  cluster_identifier = aws_rds_cluster.aurora-postgresql-cluster.id
  instance_class = "db.t4g.medium"
  identifier = "demo-aurora-cluster-${count.index}"
  engine = "aurora-postgresql"
  apply_immediately = true
  publicly_accessible = true
}