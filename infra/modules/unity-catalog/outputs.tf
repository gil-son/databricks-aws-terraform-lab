output "catalog_names" {
  value = [for c in databricks_catalog.this : c.name]
}

output "schema_full_names" {
  value = [for s in databricks_schema.this : "${s.catalog_name}.${s.name}"]
}
