provider "aws" {
  region = "eu-west-1"
}

locals {
  db-port = 5432
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "random_password" "cluster-password" {
  length = 16
  min_lower = 2
  min_upper = 2
  min_numeric = 2
  special = false
}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public-subnets" {
  count = 2
  vpc_id = aws_vpc.demo-vpc.id
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, count.index + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name: "Public"
  }
}

resource "aws_subnet" "private-subnets" {
  count = 2
  vpc_id = aws_vpc.demo-vpc.id
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name: "Private"
  }
}

resource "aws_eip" "eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat-gateway" {
  subnet_id = aws_subnet.public-subnets[0].id
  allocation_id = aws_eip.eip.id
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.demo-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }
  tags = {
    Name: "private-route-table"
  }
}

resource "aws_route_table_association" "private-route-table-association" {
  count = 2
  route_table_id = aws_route_table.private-route-table.id
  subnet_id = aws_subnet.private-subnets[count.index].id
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
  count = 2
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.public-subnets[count.index].id
}

resource "aws_ssm_parameter" "aurora-master-password" {
  name = "aurora-master-password"
  type = "SecureString"
  value = random_password.cluster-password.result
}

resource "aws_db_subnet_group" "aurora-cluster-subnets" {
  subnet_ids = aws_subnet.private-subnets[*].id
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
    security_groups = [
      aws_security_group.aurora-cluster-security-group.id,
      aws_security_group.proxy-security-group.id
    ]
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
  engine_version = "13.7" // Version 14.x not supported by RDS Proxy (yet)
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
  subnet_id = aws_subnet.public-subnets[0].id
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  vpc_security_group_ids = [aws_security_group.jump-box-security-group.id]
  tags = {
    Name: "jump-box"
  }
}

/*
https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy-setup.html#rds-proxy-connecting

You don't configure each individual database user with an authorization plugin.
The database users still have regular user names and passwords within the database.
You set up Secrets Manager secrets containing these user names and passwords,
and authorize RDS Proxy to retrieve the credentials from Secrets Manager.

The IAM authentication applies to the connection between your client program and the proxy.
The proxy then authenticates to the database using the user name and password credentials retrieved from Secrets Manager.
*/
resource "aws_secretsmanager_secret" "proxy-password-secret" {
  recovery_window_in_days = 0
  name = "proxy-password"
}

resource "random_password" "app-password" {
  length = 16
  min_lower = 2
  min_upper = 2
  min_numeric = 2
  special = false
}

resource "aws_secretsmanager_secret_version" "app-password-version" {
  secret_id = aws_secretsmanager_secret.proxy-password-secret.id
  secret_string = jsonencode({
    username: "proxy_user",
    password: random_password.app-password.result
  })
}

resource "aws_security_group" "lambda-security-group" {
  vpc_id = aws_vpc.demo-vpc.id
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = local.db-port
    to_port = local.db-port
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
  }
}

resource "aws_security_group" "proxy-security-group" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = local.db-port
    to_port = local.db-port
  }
  egress {
    security_groups = [aws_security_group.aurora-cluster-security-group.id]
    protocol = "tcp"
    from_port = local.db-port
    to_port  = local.db-port
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
  }
}

data "aws_iam_policy_document" "proxy-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["rds.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "proxy-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.proxy-password-secret.arn]
  }
  statement {
    effect = "Allow"
    actions = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${local.region}:${local.account-id}:key/*"]
    condition {
      test = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${local.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "proxy-role" {
  assume_role_policy = data.aws_iam_policy_document.proxy-assume-role.json
  inline_policy {
    name = "proxy-policy"
    policy = data.aws_iam_policy_document.proxy-policy.json
  }
}

resource "aws_db_proxy" "db-proxy" {
  name = "aurora-proxy"
  engine_family  = "POSTGRESQL"
  role_arn = aws_iam_role.proxy-role.arn
  vpc_subnet_ids = aws_subnet.private-subnets[*].id
  vpc_security_group_ids = [aws_security_group.proxy-security-group.id]
  require_tls = true
  auth {
    auth_scheme = "SECRETS"
    iam_auth = "REQUIRED"
    secret_arn = aws_secretsmanager_secret.proxy-password-secret.arn
  }
}

resource "aws_db_proxy_default_target_group" "proxy-target-group" {
  db_proxy_name = aws_db_proxy.db-proxy.name

  connection_pool_config {
    max_connections_percent = 100
    max_idle_connections_percent = 50
    connection_borrow_timeout = 120
  }
}

resource "aws_db_proxy_target" "proxy-aurora-target" {
  db_proxy_name = aws_db_proxy.db-proxy.name
  target_group_name = aws_db_proxy_default_target_group.proxy-target-group.name
  db_cluster_identifier = aws_rds_cluster.aurora-cluster.id
}

data "aws_iam_policy_document" "lambda-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::${local.account-id}:root"]
      type = "AWS"
    }
  }
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

locals {
  cluster-resource-id = aws_rds_cluster.aurora-cluster.cluster_resource_id
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
  proxy-id = aws_db_proxy.db-proxy.id
}

data "aws_iam_policy_document" "lambda-role-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${local.region}:${local.account-id}:dbuser:${local.cluster-resource-id}/app_user",
      "arn:aws:rds-db:${local.region}:${local.account-id}:dbuser:${local.proxy-id}/proxy_user",
    ]
  }
}

resource "aws_iam_role" "lambda-role" {
  name = "demo-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  inline_policy {
    name = "lambda-role-policy"
    policy = data.aws_iam_policy_document.lambda-role-policy.json
  }
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]
}

resource "aws_lambda_function" "demo-lambda" {
  function_name = "demo-lambda"
  runtime = "python3.9"
  handler = "main.handle"
  role = aws_iam_role.lambda-role.arn
  filename = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  timeout = 30
  vpc_config {
    security_group_ids = [aws_security_group.lambda-security-group.id]
    // Connecting a function to a public subnet doesn't give it internet access or a public IP address.
    subnet_ids = aws_subnet.private-subnets[*].id
  }
  environment {
    variables = {
      DB_ENDPOINT = aws_rds_cluster.aurora-cluster.endpoint
      PROXY_ENDPOINT = aws_db_proxy.db-proxy.endpoint
      REGION = local.region
      DB_PORT = local.db-port
    }
  }
}