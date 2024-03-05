provider "aws" {
  region = "eu-west-1"
}

terraform {
  required_providers {
    aws = {
      version = ">= 5.39.1"
      source  = "hashicorp/aws"
    }
  }
  required_version = ">= 1.6.0"
}

module "vpc" {
  source = "./modules/vpc"
}

module "ec2" {
  source             = "./modules/ec2"
  private_subnet_ids = module.vpc.public_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  vpc_cidr           = module.vpc.vpc_cidr
  vpc_id             = module.vpc.vpc_id
}

module "waf" {
  source  = "./modules/waf"
  alb_arn = module.ec2.alb_arn
}