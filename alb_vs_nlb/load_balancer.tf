resource "aws_lb" "application_load_balancer" {
  name                             = "application-load-balancer"
  load_balancer_type               = "application"
  internal                         = false
  security_groups                  = [aws_security_group.load_balancer_security_group.id]
  subnets                          = aws_subnet.public_subnet[*].id
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "application_lb_target_group" {
  vpc_id   = aws_vpc.vpc.id
  protocol = "HTTP"
  port     = var.http_port
}

resource "aws_lb_listener" "application_lb_listener" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application_lb_target_group.arn
  }
}

resource "aws_lb" "network_load_balancer" {
  name                             = "network-load-balancer"
  load_balancer_type               = "network"
  internal                         = false
  security_groups                  = [aws_security_group.load_balancer_security_group.id]
  subnets                          = aws_subnet.public_subnet[*].id
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "network_lb_target_group" {
  vpc_id   = aws_vpc.vpc.id
  protocol = "TCP"
  port     = var.http_port
}

resource "aws_lb_listener" "network_lb_listener" {
  load_balancer_arn = aws_lb.network_load_balancer.arn
  port              = var.http_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.network_lb_target_group.arn
  }
}
