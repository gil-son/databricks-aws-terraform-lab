variable "environment" {
  description = "Environment name (homol, prod) - used in resource names."
  type        = string
}

variable "account_id" {
  description = "Databricks account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region of the workspace"
  type        = string
  default     = "us-east-1"
}

variable "credentials_id" {
  description = "Databricks credentials ID (cross-account role), from the iam-databricks module"
  type        = string
}

variable "root_bucket_name" {
  description = "Workspace root S3 bucket, from the iam-databricks module"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID, from the network module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (at least two, in different AZs), from the network module"
  type        = list(string)
}

variable "security_group_id" {
  description = "Databricks security group ID, from the network module"
  type        = string
}
