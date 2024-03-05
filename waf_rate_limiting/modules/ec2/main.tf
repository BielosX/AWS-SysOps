data "aws_ami" "amazon-linux-2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_security_group" "instance_security_group" {
  vpc_id = var.vpc_id

  ingress {
    cidr_blocks = [var.vpc_cidr]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }
}
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance_role" {
  assume_role_policy  = data.aws_iam_policy_document.ec2_assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "instance_profile" {
  role = aws_iam_role.instance_role.id
}

resource "aws_launch_template" "launch_template" {
  instance_type          = "t4g.nano"
  image_id               = data.aws_ami.amazon-linux-2023.id
  vpc_security_group_ids = [aws_security_group.instance_security_group.id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance_profile.arn
  }
  user_data = base64encode(file("${path.module}/init.sh"))
}

resource "aws_autoscaling_group" "asg" {
  max_size            = 2
  min_size            = 2
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.target_group.arn]
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = aws_launch_template.launch_template.latest_version
  }
}

resource "aws_security_group" "alb_security_group" {
  vpc_id = var.vpc_id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
  }

  egress {
    security_groups = [aws_security_group.instance_security_group.id]
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
  }
}

resource "aws_lb" "alb" {
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "target_group" {
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}