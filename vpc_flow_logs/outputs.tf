output "network-interface-flow-log-group-id" {
  value = aws_cloudwatch_log_group.network-interface-flow-log-group.id
}

output "network-interface-id" {
  value = aws_instance.demo-instance.primary_network_interface_id
}

output "subnet-flow-log-group-id" {
  value = aws_cloudwatch_log_group.public-subnet-flow-log-group.id
}

output "subnet-id" {
  value = aws_subnet.public-subnet.id
}

output "vpc-flow-log-group-id" {
  value = aws_cloudwatch_log_group.vpc-flow-log-group.id
}

output "vpc-id" {
  value = aws_vpc.demo-vpc.id
}