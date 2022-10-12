output "public-ip" {
  value = aws_eip.instance-eip.public_ip
}