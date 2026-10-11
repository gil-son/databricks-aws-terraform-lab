variable "github_repo" {
  description = "GitHub repository allowed to assume the roles (owner/name)"
  type        = string
  default     = "gil-son/databricks-aws-terraform-lab"
}

variable "aws_profile" {
  description = "AWS profile of an IAM admin identity (NOT terraform-deployer)"
  type        = string
}
