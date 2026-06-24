terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "fanvault-v2-tfstate-899071933396"
    key            = "fanvault-v2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fanvault-v2-tfstate-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
