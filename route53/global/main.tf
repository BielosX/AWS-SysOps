provider "aws" {}

provider "aws" {
  region = "eu-west-1"
  alias = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias = "us-east-1"
}

data "aws_instance" "eu-west-1-instance" {
  provider = aws.eu-west-1
  filter {
    name = "tag:Name"
    values = ["demo-instance"]
  }
}

data "aws_instance" "us-east-1-instance" {
  provider = aws.us-east-1
  filter {
    name = "tag:Name"
    values = ["demo-instance"]
  }
}

module "route53" {
  source = "../modules/route53"
  ip-addrs = [
    data.aws_instance.eu-west-1-instance.public_ip,
    data.aws_instance.us-east-1-instance.public_ip
  ]
}