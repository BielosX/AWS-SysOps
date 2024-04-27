variable "region" {
  type = string
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.46.0"
    }
  }
}

provider "aws" {
  region = var.region
}
