output "job_policy_id" {
  value = databricks_cluster_policy.job.id
}

output "interactive_policy_id" {
  value = databricks_cluster_policy.interactive.id
}

output "validation_job_id" {
  value = databricks_job.validate_bronze.id
}
