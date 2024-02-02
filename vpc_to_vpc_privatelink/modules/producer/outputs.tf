output "service-name" {
  value = aws_vpc_endpoint_service.service.service_name
}

output "dns-names" {
  value = aws_vpc_endpoint_service.service.base_endpoint_dns_names
}