
terraform {
  required_version = ">= 0.10.1"
  backend "s3" {
    bucket = "dscouk-state"
    key    = "prod/terraform_core.state"
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

# Use aws_caller_identity to get my AWS account ID for reference 
# Used here instead of hardcoding or setting a var for the account ID in ARNs
data "aws_caller_identity" "current" {}

# dan-sullivan.co.uk zone
resource "aws_route53_zone" "dscouk" {  
  name = "dan-sullivan.co.uk."
}


output "dscouk_r53_zone_id" {
  value = "${aws_route53_zone.dscouk.zone_id}"
}

