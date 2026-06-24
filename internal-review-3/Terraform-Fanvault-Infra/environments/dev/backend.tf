terraform {
  backend "s3" {
    bucket       = "fanvault-tfstate-dev-773384830607"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}