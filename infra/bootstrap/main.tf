terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
# No backend.tf here, by design — this module uses LOCAL state
# Runs once, on your machine, and is never reapplied
}

provider "aws" {
  region  = "us-east-1"
  profile = "terraform-deployer"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state"
  type        = string
  default     = "terraform-state-gilson-databricks-lab"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  # Extra protection: prevents accidental deletion of this specific bucket
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}