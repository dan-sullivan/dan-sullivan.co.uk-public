terraform {
  required_version = ">= 0.10.1"
}

provider "aws" {
  region = "eu-west-2"
}

# Use aws_caller_identity to get my AWS account ID for reference 
# Used here instead of hardcoding or setting a var for the account ID in ARNs
data "aws_caller_identity" "current" {}
