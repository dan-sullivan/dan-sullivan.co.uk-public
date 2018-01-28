
resource "aws_cloudfront_origin_access_identity" "dscouk" {
  comment = "${terraform.workspace == "default" ? "" : "${terraform.workspace}."}dan-sullivan.co.uk"
}

data "aws_iam_policy_document" "dscouk_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${terraform.workspace == "default" ? "" : "${terraform.workspace}."}dan-sullivan.co.uk/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.dscouk.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${terraform.workspace == "default" ? "" : "${terraform.workspace}."}dan-sullivan.co.uk"]


    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.dscouk.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket" "dscouk" {
  bucket = "${terraform.workspace == "default" ? "" : "${terraform.workspace}."}dan-sullivan.co.uk"
  acl    = "private"
  policy = "${data.aws_iam_policy_document.dscouk_s3_policy.json}"
}
