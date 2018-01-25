# Create the Lambda function, uploading our code
# TODO: Create a null resource that zips up our code
# ZIPFILE=$(pwd)/serve_dscouk.zip; pushd $(pwd); cd ../; zip -r $ZIPFILE ./dist; popd; zip $ZIPFILE serve_dscouk.py
resource "aws_lambda_function" "serve_dscouk" {
  function_name    = "serve_dscouk"
  handler          = "serve_dscouk.handler"
  runtime          = "python3.6"
  filename         = "serve_dscouk.zip"
  source_code_hash = "${base64sha256(file("serve_dscouk.zip"))}"
  role             = "${aws_iam_role.lambda_exec_role_serve_dscouk.arn}"
}

# Execution role to attach to the lambda
# TODO: Move into aws_iam_policy_document?
resource "aws_iam_role" "lambda_exec_role_serve_dscouk" {
  name = "lambda_exec_role_serve_dscouk"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

