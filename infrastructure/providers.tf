
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.23.0"
    }
  }

  backend "s3" {
    region                   = ""
    bucket                   = ""
    key                      = "coretelecoms/development/terraform.tfstate"
    shared_credentials_files = ["~/.aws/credentials"]
    max_retries              = 3
  }
}

provider "aws" {
  region                   = "eu-north-1"
  shared_credentials_files = ["~/.aws/credentials"]

  default_tags {
    tags = {
      "Application-Name" = "CoreTelecoms"
      "Environment"      = "development"
    }
  }
}
