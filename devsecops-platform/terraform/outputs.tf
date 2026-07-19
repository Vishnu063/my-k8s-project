output "instance_public_ip" {
  description = "Public IP of the K3s node. Use this to SSH in, hit the app, and reach Grafana."
  value       = aws_instance.k3s_node.public_ip
}

output "ssh_command" {
  description = "Ready-to-paste SSH command"
  value       = "ssh -i /path/to/${var.key_pair_name}.pem ubuntu@${aws_instance.k3s_node.public_ip}"
}

output "ecr_repository_url" {
  description = "Push your Docker images here. Also goes into the ECR_REPOSITORY GitHub secret."
  value       = aws_ecr_repository.app.repository_url
}

output "app_url" {
  description = "Once deployed, the app is reachable here"
  value       = "http://${aws_instance.k3s_node.public_ip}:30080"
}

output "grafana_url" {
  description = "Once monitoring manifests are applied, Grafana is reachable here"
  value       = "http://${aws_instance.k3s_node.public_ip}:30030"
}
