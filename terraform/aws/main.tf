terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "medplum_dev_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "medplum-dev-vpc"
    Environment = "development"
    Project     = "medplum"
  }
}

resource "aws_internet_gateway" "medplum_igw" {
  vpc_id = aws_vpc.medplum_dev_vpc.id

  tags = {
    Name = "medplum-dev-igw"
  }
}

resource "aws_subnet" "medplum_public_subnet" {
  vpc_id                  = aws_vpc.medplum_dev_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "medplum-dev-public-subnet"
  }
}

resource "aws_route_table" "medplum_public_rt" {
  vpc_id = aws_vpc.medplum_dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.medplum_igw.id
  }

  tags = {
    Name = "medplum-dev-public-rt"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.medplum_public_subnet.id
  route_table_id = aws_route_table.medplum_public_rt.id
}

# Security Group
resource "aws_security_group" "medplum_dev_sg" {
  name        = "medplum-dev-sg"
  description = "Security group for Medplum development instance"
  vpc_id      = aws_vpc.medplum_dev_vpc.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # Medplum API Server
  ingress {
    description = "Medplum API"
    from_port   = 8103
    to_port     = 8103
    protocol    = "tcp"
    cidr_blocks = var.allowed_app_cidr
  }

  # Medplum Web App
  ingress {
    description = "Medplum Web App"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_app_cidr
  }

  # VS Code Server / Remote Development
  ingress {
    description = "VS Code Server"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_app_cidr
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "medplum-dev-sg"
  }
}

# IAM Role for EC2 Instance (optional, for AWS service access)
resource "aws_iam_role" "medplum_ec2_role" {
  name = "medplum-dev-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "medplum-dev-ec2-role"
  }
}

resource "aws_iam_instance_profile" "medplum_profile" {
  name = "medplum-dev-instance-profile"
  role = aws_iam_role.medplum_ec2_role.name
}

# EC2 Instance
resource "aws_instance" "medplum_dev" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.medplum_public_subnet.id
  vpc_security_group_ids = [aws_security_group.medplum_dev_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.medplum_profile.name

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    github_repo = var.github_repo
  })

  tags = {
    Name        = "medplum-dev-instance"
    Environment = "development"
    Project     = "medplum"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Elastic IP (optional, for static IP)
resource "aws_eip" "medplum_dev_eip" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.medplum_dev.id
  domain   = "vpc"

  tags = {
    Name = "medplum-dev-eip"
  }
}
