provider "aws" {}

resource "aws_secretsmanager_secret" "master-password" {
  name = "/rds/demo-cluster/master-password"
  force_overwrite_replica_secret = true
  recovery_window_in_days = 0
}

data "aws_secretsmanager_random_password" "master-password" {
  password_length = 64
  exclude_punctuation = true
}

resource "aws_secretsmanager_secret_version" "master-credentials-version" {
  secret_id = aws_secretsmanager_secret.master-password.id
  secret_string = data.aws_secretsmanager_random_password.master-password.random_password
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_security_group" "db-security-group" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 5432
    to_port = 5432
  }
}

resource "aws_rds_cluster" "demo-cluster" {
  cluster_identifier = "demo-cluster"
  engine = "aurora-postgresql"
  engine_mode = "provisioned"
  engine_version = "14.5"
  database_name = "postgres"
  master_username = "master"
  master_password = aws_secretsmanager_secret_version.master-credentials-version.secret_string
  skip_final_snapshot = true
  apply_immediately = true
  vpc_security_group_ids = [aws_security_group.db-security-group.id]

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }
}

resource "aws_rds_cluster_instance" "demo-cluster-instance" {
  cluster_identifier = aws_rds_cluster.demo-cluster.id
  instance_class = "db.serverless"
  engine = aws_rds_cluster.demo-cluster.engine
  engine_version = aws_rds_cluster.demo-cluster.engine_version
  publicly_accessible = true
}

data "aws_iam_policy_document" "secrets-manager-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["secretsmanager:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "secrets-manager-access" {
  policy = data.aws_iam_policy_document.secrets-manager-policy.json
}

module "secret-rotation-lambda" {
  source = "../python_lambda"
  function-name = "secret-rotation-lambda"
  handler = "main.handler"
  file-path = "${path.module}/main.py"
  managed-policy-arns = [
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  environment-variables = {
    DB_CLUSTER_ID: aws_rds_cluster.demo-cluster.id,
    EXCLUDE_PUNCTUATION: "True"
  }
}

resource "aws_lambda_permission" "secrets-manager-permission" {
  action = "lambda:InvokeFunction"
  function_name = module.secret-rotation-lambda.function-name
  principal = "secretsmanager.amazonaws.com"
}

resource "aws_iam_role_policy_attachment" "lambda-role-policy-attachment" {
  policy_arn = aws_iam_policy.secrets-manager-access.arn
  role = module.secret-rotation-lambda.role-name
}

// Triggers rotation during resource creation
resource "aws_secretsmanager_secret_rotation" "secret-rotation" {
  depends_on = [aws_lambda_permission.secrets-manager-permission]
  rotation_lambda_arn = module.secret-rotation-lambda.function-arn
  secret_id = aws_secretsmanager_secret.master-password.id
  rotation_rules {
    automatically_after_days = 30
  }
}