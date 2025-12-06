# Medplum AWS Terraform Configuration

aws_region     = "ap-south-2"
instance_type  = "t3.xlarge" # 4 vCPUs, 16 GB RAM
volume_size    = 100
key_pair_name  = "medplum-dev-keypair" # EC2 SSH key pair name
use_elastic_ip = true

# Security: Allow access from anywhere (use 0.0.0.0/0)
# For better security, replace with your specific IPv4 address later
allowed_ssh_cidr = ["0.0.0.0/0"]
allowed_app_cidr = ["0.0.0.0/0"]

# GitHub repository
github_repo = "https://github.com/healthsailjourney/medplum"
