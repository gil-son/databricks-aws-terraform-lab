terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "terraform-deployer"
}

module "network" {
  source      = "../../modules/network"
  environment = "homol"
  enable_nat  = false
}

provider "databricks" {
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

module "iam_databricks" {
  source      = "../../modules/iam-databricks"
  environment = "homol"
  account_id  = var.databricks_account_id
}