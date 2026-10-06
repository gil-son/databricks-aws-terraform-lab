terraform {
  backend "s3" {
    bucket       = "terraform-state-gilson-databricks-lab"
    key          = "homol/terraform.tfstate"
    region       = "us-east-1"
    profile      = "terraform-deployer"
    use_lockfile = true
  }
}