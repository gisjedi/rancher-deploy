output "private_subnets" {
  value = aws_subnet.private.*
}

output "public_subnets" {
  value = aws_subnet.public.*
}

output "id" {
  value = aws_vpc._.id
}