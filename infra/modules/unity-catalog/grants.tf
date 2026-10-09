# Identity the pipeline (jobs, CI) runs as. Created at workspace level; with identity
# federation it is also visible to Unity Catalog grants.
resource "databricks_service_principal" "pipeline" {
  provider = databricks.workspace

  display_name = "databricks-${var.environment}-pipeline"
}

locals {
  admin_user = var.admin_user_email
  pipeline   = databricks_service_principal.pipeline.application_id
}

resource "databricks_grants" "catalog" {
  provider = databricks.workspace
  for_each = toset(var.catalogs)

  catalog = databricks_catalog.this[each.key].name

  grant {
    principal  = local.admin_user
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal  = local.pipeline
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "schema" {
  provider = databricks.workspace
  for_each = local.catalog_schemas

  schema = "${databricks_schema.this[each.key].catalog_name}.${databricks_schema.this[each.key].name}"

  grant {
    principal  = local.admin_user
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal  = local.pipeline
    privileges = ["USE_SCHEMA", "SELECT", "MODIFY", "CREATE_TABLE"]
  }
}

# Pipeline reads raw/ and writes export/ through the data location
resource "databricks_grants" "data_location" {
  provider = databricks.workspace

  external_location = databricks_external_location.data.id

  grant {
    principal  = local.admin_user
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal  = local.pipeline
    privileges = ["READ_FILES", "WRITE_FILES"]
  }
}