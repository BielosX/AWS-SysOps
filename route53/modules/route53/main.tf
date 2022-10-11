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
