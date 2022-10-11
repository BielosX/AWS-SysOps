provider "aws" {
  region = "eu-west-1"
  alias = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias = "us-east-1"
}

module "modules" {
  source = "./modules"
  providers = {
    aws.first-region = aws.eu-west-1
    aws.second-region = aws.us-east-1
  }
}