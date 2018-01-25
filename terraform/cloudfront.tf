resource "aws_cloudfront_distribution" "dscouk" {
  origin {
    # Funkyness to extract domain name from full invoke URL. Works but surely a better way?
    domain_name = "${element(split("/",aws_api_gateway_deployment.serve_dscouk_api_deployment.invoke_url), 2)}"
    origin_path = "/production/dscouk"
    origin_id   = "dscouk-lambda"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1"]
    }
  }
 # origin {
 #   # Needs to be the s3 bucket for the lambda
 #   domain_name = "${aws_s3_bucket.b.bucket_domain_name}"
 #   origin_id   = "dscouk-s3"
 # }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "dan-sullivan.co.uk distribution"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "dscouk-logs.s3.amazonaws.com"
    prefix          = "cf-prod"
  }

  aliases = ["dan-sullivan.co.uk"]

# Add a cache_behaviour for each uri. Default to the redirect lambda@edge
  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = "dscouk-lambda"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
