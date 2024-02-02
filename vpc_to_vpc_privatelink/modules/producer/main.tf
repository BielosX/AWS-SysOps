module "vpc" {
  source = "../vpc"
}

module "ami" {
  source = "../ami"
}

resource "aws_security_group" "nlb-security-group" {
  vpc_id = module.vpc.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
  }
  egress {
    security_groups = [aws_security_group.instance-security-group.id]
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
  }
}

data "aws_region" "region" {}
data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.region.name
  account-id = data.aws_caller_identity.current.account_id
  user-data  = <<-EOT
    #!/bin/bash
    yum update
    yum -y install httpd

    cat <<EOM >> /var/www/html/index.html
    <h1>Hello from EC2! VPC: ${module.vpc.vpc-id}</h1>
    EOM

    systemctl enable httpd
    systemctl start httpd
  EOT
}

module "nlb-logs" {
  source      = "../../../private_bucket"
  bucket-name = "nlb-logs-${local.region}-${local.account-id}"
}

resource "aws_lb" "network-load-balancer" {
  load_balancer_type = "network"
  internal           = true
  subnets            = [module.vpc.private-subnet-id]
  security_groups    = [aws_security_group.nlb-security-group.id]

  access_logs {
    bucket  = module.nlb-logs.id
    enabled = true
  }
}

resource "aws_lb_target_group" "target-group" {
  protocol = "TCP"
  port     = 80
  vpc_id   = module.vpc.vpc-id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.network-load-balancer.arn
  port              = 8080
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}

resource "aws_vpc_endpoint_service" "service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.network-load-balancer.arn]
}

resource "aws_security_group" "instance-security-group" {
  vpc_id = module.vpc.vpc-id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "profile" {
  role = var.role-id
}

resource "aws_launch_template" "template" {
  instance_type          = "t4g.nano"
  image_id               = module.ami.id
  vpc_security_group_ids = [aws_security_group.instance-security-group.id]
  user_data              = base64encode(local.user-data)
  iam_instance_profile {
    arn = aws_iam_instance_profile.profile.arn
  }
}

resource "aws_autoscaling_group" "asg" {
  max_size          = 2
  min_size          = 2
  target_group_arns = [aws_lb_target_group.target-group.arn]
  launch_template {
    id      = aws_launch_template.template.id
    version = aws_launch_template.template.latest_version
  }
  vpc_zone_identifier = [module.vpc.private-subnet-id]
  tag {
    propagate_at_launch = true
    key                 = "Name"
    value               = "producer"
  }
}