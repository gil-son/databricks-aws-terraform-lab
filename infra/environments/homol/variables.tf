variable "databricks_account_id" {
  description = "Databricks Account ID"
  type        = string
}

variable "databricks_client_id" {
  description = "Databricks service principal client ID"
  type        = string
}

variable "databricks_client_secret" {
  description = "Databricks service principal client secret"
  type        = string
  sensitive   = true
}

variable "enable_nat" {
  description = "Enable the NAT Gateway. Must be true for the workspace to work; set false to save cost when idle."
  type        = bool
  default     = false
}
