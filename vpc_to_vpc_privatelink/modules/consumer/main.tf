module "vpc" {
  source = "../vpc"
}

module "ami" {
  source = "../ami"
}

resource "aws_security_group" "endpoint-security-group" {
  vpc_id = module.vpc.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
  }
}

// Same AZ required, so in case of cross-account ZoneID might be required as zone names are different for every account
resource "aws_vpc_endpoint" "endpoint" {
  service_name       = var.service-name
  vpc_id             = module.vpc.vpc-id
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc.public-subnet-id]
  auto_accept        = true
  security_group_ids = [aws_security_group.endpoint-security-group.id]
}

locals {
  user-data = <<-EOT
    #!/bin/bash
    yum update
    yum -y install nginx

    cat <<EOM > /etc/nginx/nginx.conf
    worker_processes  1;
    events {
        worker_connections  1024;
    }
    http {
        include       mime.types;
        default_type  application/octet-stream;
        sendfile        on;
        keepalive_timeout  65;
        server {
            listen       8080;
            location / {
                proxy_pass http://${aws_vpc_endpoint.endpoint.dns_entry[0].dns_name}:8080;
            }
        }
    }
    EOM

    systemctl enable nginx
    systemctl start nginx
  EOT
}

resource "aws_security_group" "security-group" {
  vpc_id = module.vpc.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
}

resource "aws_iam_instance_profile" "profile" {
  role = var.role-id
}

resource "aws_instance" "instance" {
  ami                    = module.ami.id
  instance_type          = "t4g.nano"
  subnet_id              = module.vpc.public-subnet-id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  user_data              = base64encode(local.user-data)
  iam_instance_profile   = aws_iam_instance_profile.profile.id
  tags = {
    Name : "consumer"
  }
}