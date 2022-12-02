output "vpc-id" {
  value = aws_vpc.vpc.id
}

output "public-subnet-id" {
  value = aws_subnet.public-subnet.id
}

output "public-subnet-az" {
  value = aws_subnet.public-subnet.availability_zone
}

output "private-subnet-id" {
  value = aws_subnet.private-subnet.id
}

output "public-route-table-id" {
  value = aws_route_table.public-route-table.id
}

output "private-route-table-id" {
  value = aws_route_table.private-route-table.id
}

output "vpc-cidr-block" {
  value = aws_vpc.vpc.cidr_block
}
