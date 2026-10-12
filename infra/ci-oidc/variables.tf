variable "github_repo" {
  description = "Repository as it appears in the OIDC sub claim: owner@ownerId/name@repoId (GitHub includes the numeric IDs)"
  type        = string
  default     = "gil-son@72712095/databricks-aws-terraform-lab@1396238251"
}

variable "aws_profile" {
  description = "AWS profile of an IAM admin identity (NOT terraform-deployer)"
  type        = string
}
