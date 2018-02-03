# Execution role to attach to the lambda
# TODO: Move into aws_iam_policy_document?
resource "aws_iam_role" "lambda_exec_role_serve_dscouk" {
  name = "lambda_exec_role_serve_dscouk${terraform.workspace == "default" ? "" : "_${terraform.workspace}"}"

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

output "lambda_exec_role" {
  value = "${aws_iam_role.lambda_exec_role_serve_dscouk.arn}"
}

# Upload the Lambda zip
resource "aws_lambda_function" "serve_dscouk" {
  function_name    = "serve_dscouk${terraform.workspace == "default" ? "" : "_${terraform.workspace}"}"
  handler          = "serve_dscouk.handler"
  runtime          = "python3.6"
  filename         = "zips/serve_dscouk.zip"
  source_code_hash = "${base64sha256(file("zips/serve_dscouk.zip"))}"
  role             = "${aws_iam_role.lambda_exec_role_serve_dscouk.arn}"
}

#TODO: Tighten up the source ARN once multiple workspaces are working.
resource "aws_lambda_permission" "allow_api_gateway" {
  function_name = "${aws_lambda_function.serve_dscouk.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-2:${data.aws_caller_identity.current.account_id}:*/*/GET/*"
}
