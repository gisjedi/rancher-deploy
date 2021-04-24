output "server_ips" {
  value = aws_network_interface.server.*.private_ip
}

output "agent_ips" {
  value = aws_network_interface.agent.*.private_ip
}

output "server_lb" {
  value = aws_lb.server
}

output "agent_lb" {
  value = aws_lb.ingress
}