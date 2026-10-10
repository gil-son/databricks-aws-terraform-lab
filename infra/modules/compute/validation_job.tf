resource "databricks_notebook" "validate_bronze" {
  provider = databricks.workspace

  path     = "/Shared/${var.environment}/validate_bronze"
  language = "PYTHON"
  source   = "${path.module}/notebooks/validate_bronze.py"
}

resource "databricks_permissions" "validate_bronze_notebook" {
  provider = databricks.workspace

  notebook_path = databricks_notebook.validate_bronze.path

  access_control {
    service_principal_name = var.pipeline_application_id
    permission_level       = "CAN_READ"
  }
  access_control {
    user_name        = var.admin_user_email
    permission_level = "CAN_RUN"
  }
}

# run_as needs the creator of the job to hold the "Service Principal User" role on the target SP
resource "databricks_access_control_rule_set" "pipeline_sp_user" {
  provider = databricks.workspace

  name = "accounts/${var.account_id}/servicePrincipals/${var.pipeline_application_id}/ruleSets/default"

  grant_rules {
    principals = [
      "servicePrincipals/${var.deployer_application_id}",
      "users/${var.admin_user_email}",
    ]
    role = "roles/servicePrincipal.user"
  }
}

resource "databricks_job" "validate_bronze" {
  provider = databricks.workspace

  name = "databricks-${var.environment}-validate-bronze"

  # The job runs as the pipeline service principal, so it exercises the real (least-privilege) grants
  run_as {
    service_principal_name = var.pipeline_application_id
  }

  job_cluster {
    job_cluster_key = "validation"
    new_cluster {
      spark_version       = data.databricks_spark_version.lts.id
      node_type_id        = var.node_type_id
      driver_node_type_id = var.node_type_id
      num_workers         = 1
      data_security_mode  = "SINGLE_USER"
      policy_id           = databricks_cluster_policy.job.id
      custom_tags = {
        Environment = var.environment
      }
    }
  }

  task {
    task_key        = "validate_bronze"
    job_cluster_key = "validation"

    notebook_task {
      notebook_path = databricks_notebook.validate_bronze.path
      base_parameters = {
        catalog     = var.catalog_name
        data_bucket = var.data_bucket_name
      }
    }
  }

  depends_on = [databricks_permissions.job_policy, databricks_access_control_rule_set.pipeline_sp_user]
}

resource "databricks_permissions" "validate_bronze_job" {
  provider = databricks.workspace

  job_id = databricks_job.validate_bronze.id

  access_control {
    service_principal_name = var.pipeline_application_id
    permission_level       = "CAN_MANAGE_RUN"
  }
  access_control {
    user_name        = var.admin_user_email
    permission_level = "CAN_MANAGE_RUN"
  }
}
