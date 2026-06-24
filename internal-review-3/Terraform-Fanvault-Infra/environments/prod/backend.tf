terraform {
  backend "s3" {
    bucket       = "fanvault-tfstate-prod-773384830607"
    key          = "environments/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
