variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.xlarge" # 4 vCPUs, 16 GB RAM
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 100
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this to your IP for better security
}

variable "allowed_app_cidr" {
  description = "CIDR blocks allowed to access applications"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this to your IP for better security
}

variable "use_elastic_ip" {
  description = "Whether to use an Elastic IP"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repository URL for Medplum"
  type        = string
  default     = "https://github.com/medplum/medplum.git"
}
