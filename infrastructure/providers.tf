
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.23.0"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.11.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
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
  profile                  = "terraform-ops"

  default_tags {
    tags = {
      "Application-Name" = "CoreTelecoms"
      "Environment"      = "production"
      "Managed-By"       = "Terraform"
    }
    }
  }

provider "snowflake" {
  preview_features_enabled = ["snowflake_file_format_resource", "snowflake_stage_resource"]
}
