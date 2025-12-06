output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.medplum_dev.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = var.use_elastic_ip ? aws_eip.medplum_dev_eip[0].public_ip : aws_instance.medplum_dev.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.medplum_dev.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${var.use_elastic_ip ? aws_eip.medplum_dev_eip[0].public_ip : aws_instance.medplum_dev.public_ip}"
}

output "medplum_api_url" {
  description = "Medplum API URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.medplum_dev_eip[0].public_ip : aws_instance.medplum_dev.public_ip}:8103"
}

output "medplum_web_url" {
  description = "Medplum Web App URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.medplum_dev_eip[0].public_ip : aws_instance.medplum_dev.public_ip}:3000"
}

output "vscode_server_url" {
  description = "VS Code Server URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.medplum_dev_eip[0].public_ip : aws_instance.medplum_dev.public_ip}:8080"
}
