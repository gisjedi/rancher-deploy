output "public_ip" {
  value = aws_instance.bastion_registry.public_ip
}

output "private_ip" {
  value = aws_instance.bastion_registry.private_ip
}