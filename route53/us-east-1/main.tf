provider "aws" {
  region = "us-east-1"
}

module "ec2" {
  source = "../modules/ec2"
}