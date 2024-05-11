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

resource "aws_lb_target_group" "duration_based_stickiness_group" {
  vpc_id   = aws_vpc.vpc.id
  protocol = "HTTP"
  port     = var.http_port

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 60
  }
}

resource "aws_lb_target_group" "application_based_stickiness_group" {
  vpc_id   = aws_vpc.vpc.id
  protocol = "HTTP"
  port     = 8080

  health_check {
    path = "/health"
    interval = 10
    timeout = 5
  }

  stickiness {
    type            = "app_cookie"
    cookie_name     = "SessionId"
    cookie_duration = 60 * 5
  }
}

resource "aws_lb_listener_rule" "duration_based_stickiness" {
  listener_arn = aws_lb_listener.application_lb_listener.arn

  condition {
    query_string {
      key   = "sticky"
      value = "duration"
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.duration_based_stickiness_group.arn
  }
}

resource "aws_lb_listener_rule" "application_based_stickiness" {
  listener_arn = aws_lb_listener.application_lb_listener.arn

  condition {
    query_string {
      key   = "sticky"
      value = "application"
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application_based_stickiness_group.arn
  }
}
