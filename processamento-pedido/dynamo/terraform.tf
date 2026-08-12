terraform {
  backend "s3" {
    bucket  = "tfstate-gabriel-dev"
    key     = "processamento_pedido/terraform_dynamo/terraform.tfstate"
    region  = "sa-east-1"
    profile = "gabriel_dev"
    encrypt = true
  }

  // Setting aws provider and its version
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  //Setting the version of terraform
  required_version = ">= 1.2"
}

provider "aws" {
  region  = "sa-east-1"
  profile = "gabriel_dev"
}