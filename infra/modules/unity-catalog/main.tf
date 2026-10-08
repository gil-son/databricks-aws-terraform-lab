locals {
  catalog_schemas = {
    for pair in setproduct(var.catalogs, var.schemas) :
    "${pair[0]}.${pair[1]}" => { catalog = pair[0], schema = pair[1] }
  }
}

resource "databricks_storage_credential" "this" {
  provider = databricks.workspace

  name    = "databricks-${var.environment}-uc-credential"
  comment = "Managed by Terraform"

  aws_iam_role {
    role_arn = var.uc_role_arn
  }
}

resource "databricks_external_location" "this" {
  provider = databricks.workspace

  name            = "databricks-${var.environment}-uc-location"
  url             = "s3://${var.uc_bucket_name}"
  credential_name = databricks_storage_credential.this.id
  comment         = "Managed by Terraform"
}

# Lets Unity Catalog govern reads of raw/ and writes of export/ in the data bucket
resource "databricks_external_location" "data" {
  provider = databricks.workspace

  name            = "databricks-${var.environment}-data-location"
  url             = "s3://${var.data_bucket_name}"
  credential_name = databricks_storage_credential.this.id
  comment         = "Managed by Terraform"
}

resource "databricks_catalog" "this" {
  provider = databricks.workspace
  for_each = toset(var.catalogs)

  name         = each.key
  storage_root = "s3://${var.uc_bucket_name}/${each.key}"
  comment      = "Managed by Terraform"

  # The path must be covered by the external location, which must exist first
  depends_on = [databricks_external_location.this]
}

resource "databricks_schema" "this" {
  provider = databricks.workspace
  for_each = local.catalog_schemas

  catalog_name = databricks_catalog.this[each.value.catalog].name
  name         = each.value.schema
  comment      = "Managed by Terraform"
}
