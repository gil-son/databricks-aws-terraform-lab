output "workspace_url" {
  value = module.workspace.workspace_url
}

output "workspace_id" {
  value = module.workspace.workspace_id
}

output "data_bucket_name" {
  value = module.iam_databricks.data_bucket_name
}
