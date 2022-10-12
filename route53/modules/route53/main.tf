terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 2.7.0"
      configuration_aliases = [aws]
    }
  }
}

resource "aws_route53_zone" "demo-zone" {
  name = "szakalaka.com"
}

resource "aws_route53_record" "simple-record" {
  name = "simple.${aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 60
  zone_id = aws_route53_zone.demo-zone.id
  records = [var.ip-addrs[0]]
}

resource "aws_route53_record" "weighted-record-primary" {
  name = "weighted.${aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 1
  zone_id = aws_route53_zone.demo-zone.id
  records = [var.ip-addrs[0]]
  set_identifier = "primary"
  weighted_routing_policy {
    weight = 70
  }
}

resource "aws_route53_record" "weighted-record-secondary" {
  name = "weighted.${aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 1
  zone_id = aws_route53_zone.demo-zone.id
  records = [var.ip-addrs[1]]
  set_identifier = "secondary"
  weighted_routing_policy {
    weight = 30
  }
}

resource "aws_route53_record" "latency-record-eu-west-1" {
  name = "latency.${aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 60
  zone_id = aws_route53_zone.demo-zone.id
  records = [var.ip-addrs[0]]
  latency_routing_policy {
    region = "eu-west-1"
  }
  set_identifier = "eu-west-1-latency"
}

resource "aws_route53_record" "latency-record-us-east-1" {
  name = "latency.${aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 60
  zone_id = aws_route53_zone.demo-zone.id
  records = [var.ip-addrs[1]]
  latency_routing_policy {
    region = "us-east-1"
  }
  set_identifier = "us-east-1-latency"
}

resource "aws_route53_health_check" "health-checks" {
  count = length(var.ip-addrs)
  type = "HTTP"
  port = 80
  resource_path = "/"
  request_interval = 30
  failure_threshold = 2
  ip_address = var.ip-addrs[count.index]
}

resource "aws_route53_record" "multi-value-first-record" {
  name = "multivalue.${aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 10
  zone_id = aws_route53_zone.demo-zone.id
  records = [var.ip-addrs[0]]
  multivalue_answer_routing_policy = true
  health_check_id = aws_route53_health_check.health-checks[0].id
  set_identifier = "multi-value-first"
}

resource "aws_route53_record" "multi-value-second-record" {
  name = "multivalue.${aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 10
  zone_id = aws_route53_zone.demo-zone.id
  records = [var.ip-addrs[1]]
  multivalue_answer_routing_policy = true
  health_check_id = aws_route53_health_check.health-checks[1].id
  set_identifier = "multi-value-second"
}

resource "aws_route53_record" "primary-failover-record" {
  name = "failover.${aws_route53_zone.demo-zone.name}"
  type = "A"
  zone_id = aws_route53_zone.demo-zone.id
  ttl = 10
  health_check_id = aws_route53_health_check.health-checks[0].id
  records = [var.ip-addrs[0]]
  set_identifier = "primary-failover"
  failover_routing_policy {
    type = "PRIMARY"
  }
}

resource "aws_route53_record" "secondary-failover-record" {
  name = "failover.${aws_route53_zone.demo-zone.name}"
  type = "A"
  zone_id = aws_route53_zone.demo-zone.id
  ttl = 10
  health_check_id = aws_route53_health_check.health-checks[1].id
  records = [var.ip-addrs[1]]
  set_identifier = "secondary-failover"
  failover_routing_policy {
    type = "SECONDARY"
  }
}

resource "aws_route53_record" "europe-record" {
  name = "geolocation.${aws_route53_zone.demo-zone.name}"
  type = "A"
  zone_id = aws_route53_zone.demo-zone.id
  ttl = 30
  records = [var.ip-addrs[0]]
  set_identifier = "europe-geolocation"
  geolocation_routing_policy {
    continent = "EU"
  }
}

resource "aws_route53_record" "north-america-record" {
  name = "geolocation.${aws_route53_zone.demo-zone.name}"
  type = "A"
  zone_id = aws_route53_zone.demo-zone.id
  ttl = 30
  records = [var.ip-addrs[1]]
  set_identifier = "north-america-geolocation"
  geolocation_routing_policy {
    continent = "NA"
  }
}