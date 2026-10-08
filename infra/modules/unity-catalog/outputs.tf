output "catalog_names" {
  value = [for c in databricks_catalog.this : c.name]
}

output "schema_full_names" {
  value = [for s in databricks_schema.this : "${s.catalog_name}.${s.name}"]
}

output "data_external_location_url" {
  value = "s3://${var.data_bucket_name}"
}
