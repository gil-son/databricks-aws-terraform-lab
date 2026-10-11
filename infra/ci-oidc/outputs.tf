output "role_arns" {
  description = "Put each one in the AWS_ROLE_ARN variable of the matching GitHub Environment"
  value       = { for k, r in aws_iam_role.github_actions : k => r.arn }
}