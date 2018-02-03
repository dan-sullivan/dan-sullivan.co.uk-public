
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

output "r53_zone" {
  value = "${aws_route53_zone.dscouk.zone_id}"
}


resource "aws_route53_record" "dscouk-root" {
  zone_id = "${aws_route53_zone.dscouk.zone_id}"
  name    = "dan-sullivan.co.uk"
  type    = "A"
  alias {
    name = "${aws_cloudfront_distribution.dscouk.domain_name}"
    zone_id = "${aws_cloudfront_distribution.dscouk.hosted_zone_id}"
    evaluate_target_health = false
  }

}

resource "aws_cloudfront_origin_access_identity" "dscouk" {
  comment = "dan-sullivan.co.uk"
}

# S3

data "aws_iam_policy_document" "dscouk_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::dan-sullivan.co.uk/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.dscouk.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::dan-sullivan.co.uk"]


    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.dscouk.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket" "dscouk" {
  bucket = "dan-sullivan.co.uk"
  acl    = "private"
  policy = "${data.aws_iam_policy_document.dscouk_s3_policy.json}"
}

output "dscouk_bucket_domain_name" {
  value = "${aws_s3_bucket.dscouk.bucket_domain_name}"
}

# SSL

# Get ARN of SSL Cert in acm
data "aws_acm_certificate" "dscouk" {
  provider = "aws.us-east-1"
  domain   = "dan-sullivan.co.uk"
  statuses = ["ISSUED"]
}

# API GATEWAY

# The API Gateway name
resource "aws_api_gateway_rest_api" "serve_dscouk_api" {
  name = "serve_dscouk_api"
}

resource "aws_api_gateway_domain_name" "api_dscouk" {
  domain_name = "api.dan-sullivan.co.uk"
  certificate_arn = "${data.aws_acm_certificate.dscouk.arn}"
}

resource "aws_route53_record" "dscouk_api" {
  zone_id = "${aws_route53_zone.dscouk.zone_id}"
  name    = "api.dan-sullivan.co.uk"
  type    = "A"
  alias {
    name = "${aws_api_gateway_domain_name.api_dscouk.cloudfront_domain_name}"
    zone_id = "${aws_api_gateway_domain_name.api_dscouk.cloudfront_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_resource" "dscouk_dummy_res" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.serve_dscouk_api.root_resource_id}"
  path_part   = "dummy"
}

resource "aws_api_gateway_method" "dscouk_dummy_method" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  resource_id = "${aws_api_gateway_resource.dscouk_dummy_res.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dscouk_dummy_integration" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  resource_id = "${aws_api_gateway_resource.dscouk_dummy_res.id}"
  http_method = "${aws_api_gateway_method.dscouk_dummy_method.http_method}"
  type        = "MOCK"
}

resource "aws_api_gateway_deployment" "dscouk_dummy" {
  depends_on = ["aws_api_gateway_integration.dscouk_dummy_integration"]
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  stage_name  = "production"
}

resource "aws_api_gateway_base_path_mapping" "serve_dscouk_production" {
  api_id      = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  stage_name  = "production"
  domain_name = "${aws_api_gateway_domain_name.api_dscouk.domain_name}"
}

output "api_id" {
  value = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
}

output "api_root_resource_id" {
  value = "${aws_api_gateway_rest_api.serve_dscouk_api.root_resource_id}"
}



# CLOUDFRONT 


resource "aws_cloudfront_distribution" "dscouk" {

  origin {
    # Funkyness to extract domain name from full invoke URL. Works but surely a better way?
    domain_name = "${element(split("/",aws_api_gateway_deployment.dscouk_dummy.invoke_url), 2)}"
    origin_path = "/production/dscouk"
    origin_id   = "dscouk-lambda-prod"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1"]
    }
  }

  origin {
    # Funkyness to extract domain name from full invoke URL. Works but surely a better way?
    domain_name = "${element(split("/",aws_api_gateway_deployment.dscouk_dummy.invoke_url), 2)}"
    origin_id   = "dscouk-lambda-dev"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1"]
    }
  }

  origin {
    # Needs to be the s3 bucket
    domain_name = "${aws_s3_bucket.dscouk.bucket_domain_name}"
    origin_id   = "dscouk-s3"
   
    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.dscouk.cloudfront_access_identity_path}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${terraform.workspace == "default" ? "" : "${terraform.workspace}."}dan-sullivan.co.uk distribution"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "dscouk-logs.s3.amazonaws.com"
    prefix          = "cf-${terraform.workspace == "default" ? "prod" : terraform.workspace}"
  }

  aliases = ["${terraform.workspace == "default" ? "" : "${terraform.workspace}."}dan-sullivan.co.uk"]

# Add cache behaviour for /pr* and /bt-* (for branch test future use)
# How to use this in API - still to work out. 

# Add a cache_behaviour for each uri. Default to the redirect lambda@edge
  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = "dscouk-lambda-prod"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = "${terraform.workspace == "default" ? 3600 : 60}"
    max_ttl                = "${terraform.workspace == "default" ? 86400 : 60}"

  }

  cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = "dscouk-lambda-dev"
    path_pattern = "pr*/*"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = "${terraform.workspace == "default" ? 3600 : 60}"
    max_ttl                = "${terraform.workspace == "default" ? 86400 : 60}"

  }

  # /s3 cache behavious 
  cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = "dscouk-s3"
    path_pattern = "s3/*"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = "${terraform.workspace == "default" ? 3600 : 60}"
    max_ttl                = "${terraform.workspace == "default" ? 86400 : 60}"

  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.dscouk.arn}"
    ssl_support_method = "sni-only"
  }
}
