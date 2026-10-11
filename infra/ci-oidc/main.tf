terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No backend.tf by design: local state, applied by hand by an IAM admin
}

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # GitHub Environments that may assume each role.
  # prod-plan = PR plans for prod (no reviewers), prod = real apply (reviewers).
  environments = {
    homol = ["homol"]
    prod  = ["prod", "prod-plan"]
  }

  # Existing customer-managed policies that the deployer role already uses
  policy_names = [
    "terraform-bootstrap-s3-policy",
    "terraform-network-policy",
    "terraform-iam-databricks-policy",
  ]

  role_policy_pairs = {
    for pair in setproduct(keys(local.environments), local.policy_names) :
    "${pair[0]}-${pair[1]}" => { env = pair[0], policy = pair[1] }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's certificate chain itself; the value is still required by the provider.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "trust" {
  for_each = local.environments

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for e in each.value : "repo:${var.github_repo}:environment:${e}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  for_each = local.environments

  name               = "github-actions-terraform-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.trust[each.key].json
}

resource "aws_iam_role_policy_attachment" "deployer_policies" {
  for_each = local.role_policy_pairs

  role       = aws_iam_role.github_actions[each.value.env].name
  policy_arn = "arn:aws:iam::${local.account_id}:policy/${each.value.policy}"
}
