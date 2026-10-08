output "credentials_id" {
  value = databricks_mws_credentials.this.credentials_id
}

output "cross_account_role_arn" {
  value = aws_iam_role.cross_account.arn
}

output "root_bucket_name" {
  value = aws_s3_bucket.root.bucket
}

output "unity_catalog_bucket_name" {
  value = aws_s3_bucket.unity_catalog.bucket
}

output "unity_catalog_role_arn" {
  value = aws_iam_role.unity_catalog.arn
}

output "data_bucket_name" {
  value = aws_s3_bucket.data.bucket
}
