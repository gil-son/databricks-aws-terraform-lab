data "databricks_spark_version" "lts" {
  provider          = databricks.workspace
  long_term_support = true
}

locals {
  common_rules = {
    spark_version             = { type = "fixed", value = data.databricks_spark_version.lts.id }
    node_type_id              = { type = "fixed", value = var.node_type_id }
    driver_node_type_id       = { type = "fixed", value = var.node_type_id }
    data_security_mode        = { type = "fixed", value = "SINGLE_USER" }
    "custom_tags.Environment" = { type = "fixed", value = var.environment }
  }
}

# Job clusters: ephemeral, created and destroyed by the job
resource "databricks_cluster_policy" "job" {
  provider = databricks.workspace

  name = "databricks-${var.environment}-job-policy"
  definition = jsonencode(merge(local.common_rules, {
    cluster_type = { type = "fixed", value = "job" }
    num_workers  = { type = "range", maxValue = var.max_workers, defaultValue = 1 }
  }))
}

# All-purpose clusters: short auto-termination, capped size
resource "databricks_cluster_policy" "interactive" {
  provider = databricks.workspace

  name = "databricks-${var.environment}-interactive-policy"
  definition = jsonencode(merge(local.common_rules, {
    cluster_type            = { type = "fixed", value = "all-purpose" }
    autotermination_minutes = { type = "range", maxValue = var.interactive_autotermination_minutes, defaultValue = var.interactive_autotermination_minutes }
    "autoscale.min_workers" = { type = "range", maxValue = 1, defaultValue = 1 }
    "autoscale.max_workers" = { type = "range", maxValue = var.max_workers, defaultValue = var.max_workers }
  }))
}

resource "databricks_permissions" "job_policy" {
  provider = databricks.workspace

  cluster_policy_id = databricks_cluster_policy.job.id

  access_control {
    service_principal_name = var.pipeline_application_id
    permission_level       = "CAN_USE"
  }
  access_control {
    user_name        = var.admin_user_email
    permission_level = "CAN_USE"
  }
}

resource "databricks_permissions" "interactive_policy" {
  provider = databricks.workspace

  cluster_policy_id = databricks_cluster_policy.interactive.id

  access_control {
    service_principal_name = var.pipeline_application_id
    permission_level       = "CAN_USE"
  }
  access_control {
    user_name        = var.admin_user_email
    permission_level = "CAN_USE"
  }
}
