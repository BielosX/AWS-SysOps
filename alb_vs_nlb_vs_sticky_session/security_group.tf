resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = var.http_port
    to_port     = var.http_port
  }
}

resource "aws_security_group" "instance_security_group" {
  vpc_id = aws_vpc.vpc.id
  ingress {
    security_groups = [aws_security_group.load_balancer_security_group.id]
    protocol        = "tcp"
    from_port       = var.http_port
    to_port         = var.http_port
  }
  ingress {
    security_groups = [aws_security_group.load_balancer_security_group.id]
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
}

resource "aws_security_group_rule" "load_balancer_to_instance_http_sg_rule" {
  security_group_id        = aws_security_group.load_balancer_security_group.id
  source_security_group_id = aws_security_group.instance_security_group.id
  from_port                = var.http_port
  to_port                  = var.http_port
  protocol                 = "tcp"
  type                     = "egress"
}

resource "aws_security_group_rule" "load_balancer_to_instance_app_http_sg_rule" {
  security_group_id        = aws_security_group.load_balancer_security_group.id
  source_security_group_id = aws_security_group.instance_security_group.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  type                     = "egress"
}
