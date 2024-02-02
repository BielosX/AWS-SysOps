provider "aws" {
  region = "eu-west-1"
}

terraform {
  required_providers {
    aws = {
      version = ">= 5.35.0"
      source  = "hashicorp/aws"
    }
  }
  required_version = ">= 1.6.0"
}

module "iam" {
  source = "./modules/iam"
}

module "producer" {
  source  = "./modules/producer"
  role-id = module.iam.role-id
}

module "consumer" {
  source       = "./modules/consumer"
  service-name = module.producer.service-name
  role-id      = module.iam.role-id
}