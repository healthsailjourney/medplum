# Cost Optimization Configuration for Medplum
# This file provides variables and configurations for controlling infrastructure costs

# Cost Control Variable - Set to false to disable/stop the instance and save costs
variable "enable_instance" {
  description = "Whether to create and run the EC2 instance. Set to false to stop the instance and reduce costs."
  type        = bool
  default     = true
}

variable "stop_instance_schedule" {
  description = "Enable scheduled stop/start using EventBridge and Lambda"
  type        = bool
  default     = false
}

variable "stop_instance_time" {
  description = "Time to stop instance (24-hour format, UTC). Example: '18:00'"
  type        = string
  default     = "18:00"
}

variable "start_instance_time" {
  description = "Time to start instance (24-hour format, UTC). Example: '08:00'"
  type        = string
  default     = "08:00"
}

# Modify the EC2 instance resource to support enable_instance variable
# Add this line to the aws_instance.medplum_dev resource in main.tf:
# count = var.enable_instance ? 1 : 0

# Modify the Elastic IP resource to support enable_instance variable
# Add this line to the aws_eip.medplum_dev_eip resource in main.tf:
# count = var.enable_instance && var.use_elastic_ip ? 1 : 0

# Cost optimization outputs
output "cost_status" {
  description = "Current cost status of the infrastructure"
  value = {
    instance_enabled   = var.enable_instance
    estimated_daily    = var.enable_instance ? "$7.06" : "$0.72"
    estimated_monthly  = var.enable_instance ? "$212" : "$22"
    instance_state     = var.enable_instance ? "running" : "stopped/disabled"
  }
}

output "scaling_instructions" {
  description = "Instructions for scaling up/down"
  value       = var.enable_instance ? "Instance is RUNNING. To save costs, run: terraform apply -var='enable_instance=false'" : "Instance is STOPPED. To scale up, run: terraform apply -var='enable_instance=true'"
}
