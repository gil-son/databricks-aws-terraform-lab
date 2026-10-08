resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.account_id
  storage_configuration_name = "databricks-${var.environment}-storage"
  bucket_name                = var.root_bucket_name
}

resource "databricks_mws_networks" "this" {
  account_id         = var.account_id
  network_name       = "databricks-${var.environment}-network"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.security_group_id]
}

resource "databricks_mws_workspaces" "this" {
  account_id               = var.account_id
  workspace_name           = "databricks-${var.environment}"
  aws_region               = var.aws_region
  credentials_id           = var.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}
