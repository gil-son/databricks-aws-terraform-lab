variable "environment" {
  description = "Environment name (homol, prod) - used in resource names."
  type        = string
}

variable "uc_bucket_name" {
  description = "Unity Catalog S3 bucket, from the iam-databricks module"
  type        = string
}

variable "uc_role_arn" {
  description = "IAM role Unity Catalog assumes to access the bucket, from the iam-databricks module"
  type        = string
}

variable "catalogs" {
  description = "Catalogs to create. Each one stores its managed data under s3://<uc bucket>/<catalog name>."
  type        = list(string)
}

variable "schemas" {
  description = "Schemas created in every catalog (medallion layers)"
  type        = list(string)
  default     = ["bronze", "silver", "gold"]
}
