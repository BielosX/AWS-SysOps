provider "aws" {
  region = "eu-west-1"
}

module "rds" {
  source = "./rds"
}