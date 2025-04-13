terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.94.1"
    }
  }
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "region" {
  type = string
}

provider "aws" {
  region = var.region
}


resource "aws_instance" "instance" {
  ami = var.ami
  instance_type = var.instance_type

  tags = {
    Name = "demo-instance"
  }
}