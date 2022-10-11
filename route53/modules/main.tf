terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 2.7.0"
      configuration_aliases = [ aws.first-region, aws.second-region ]
    }
  }
}

module "first-region-ec2" {
  source = "./ec2"
  providers = {
    aws = aws.first-region
  }
}

module "second-region-ec2" {
  source = "./ec2"
  providers = {
    aws = aws.second-region
  }
}

module "route53" {
  source = "./route53"
  ip-addrs = [module.first-region-ec2.public-ip, module.second-region-ec2.public-ip]
  providers = {
    aws = aws.first-region
  }
}