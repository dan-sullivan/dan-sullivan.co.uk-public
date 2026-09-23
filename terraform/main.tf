terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "dscouk-state"
    key    = "prod/terraform.state"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Use core state file as a data source
data "terraform_remote_state" "dscouk_core" {
  backend = "s3"
  config = {
    bucket = "dscouk-state"
    key    = "prod/terraform_core.state"
    region = "eu-west-2"
  }
}

# Use aws_caller_identity to get my AWS account ID for reference 
# Used here instead of hardcoding or setting a var for the account ID in ARNs
data "aws_caller_identity" "current" {}
