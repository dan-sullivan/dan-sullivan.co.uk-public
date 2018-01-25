resource "aws_route53_zone" "dscouk" {  
  name = "dan-sullivan.co.uk."
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
