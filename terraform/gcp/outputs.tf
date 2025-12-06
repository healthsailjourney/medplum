output "instance_name" {
  description = "Name of the instance"
  value       = google_compute_instance.medplum_dev.name
}

output "instance_external_ip" {
  description = "External IP of the instance"
  value       = google_compute_address.medplum_static_ip.address
}

output "instance_internal_ip" {
  description = "Internal IP of the instance"
  value       = google_compute_instance.medplum_dev.network_interface[0].network_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh ${var.ssh_user}@${google_compute_address.medplum_static_ip.address}"
}

output "medplum_api_url" {
  description = "Medplum API URL"
  value       = "http://${google_compute_address.medplum_static_ip.address}:8103"
}

output "medplum_web_url" {
  description = "Medplum Web App URL"
  value       = "http://${google_compute_address.medplum_static_ip.address}:3000"
}

output "vscode_server_url" {
  description = "VS Code Server URL"
  value       = "http://${google_compute_address.medplum_static_ip.address}:8080"
}
