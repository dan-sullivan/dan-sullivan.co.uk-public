resource "aws_route53_record" "dscouk-root" {
  zone_id = "${data.terraform_remote_state.dscouk_core.dscouk_r53_zone_id}"
  name    = "${terraform.workspace == "default" ? "" : "${terraform.workspace}."}dan-sullivan.co.uk"
  type    = "A"
  alias {
    name = "${aws_cloudfront_distribution.dscouk.domain_name}"
    zone_id = "${aws_cloudfront_distribution.dscouk.hosted_zone_id}"
    evaluate_target_health = false
  }

}
