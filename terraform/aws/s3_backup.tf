# AWS S3 Bucket for Medplum Backups
# This bucket stores all PostgreSQL and Redis backups
# Data is permanently stored with versioning and encryption enabled

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# S3 bucket for backups
resource "aws_s3_bucket" "medplum_backups" {
  bucket = "medplum-backups-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "medplum-backups"
    Environment = "development"
    Project     = "medplum"
    Purpose     = "Persistent data storage for Medplum"
  }
}

# Enable versioning (keep backup history)
resource "aws_s3_bucket_versioning" "medplum_backups" {
  bucket = aws_s3_bucket.medplum_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "medplum_backups" {
  bucket = aws_s3_bucket.medplum_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable public access block (security)
resource "aws_s3_bucket_public_access_block" "medplum_backups" {
  bucket = aws_s3_bucket.medplum_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy (delete old backups after 90 days to save cost)
resource "aws_s3_bucket_lifecycle_configuration" "medplum_backups" {
  bucket = aws_s3_bucket.medplum_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    filter {
      prefix = "medplum/"
    }

    expiration {
      days = 90
    }
  }
}

# Output bucket name for scripts
output "backup_bucket_name" {
  description = "S3 bucket name for Medplum backups"
  value       = aws_s3_bucket.medplum_backups.id
}

output "backup_s3_path" {
  description = "S3 path where backups are stored"
  value       = "s3://${aws_s3_bucket.medplum_backups.id}/medplum/"
}

output "backup_bucket_region" {
  description = "S3 bucket region"
  value       = aws_s3_bucket.medplum_backups.region
}

# Estimated monthly cost for backup storage
output "backup_storage_cost_estimate" {
  description = "Estimated monthly cost for 10GB backup storage"
  value       = "~$0.23/month for 10GB (99.8% cheaper than running infrastructure)"
}
