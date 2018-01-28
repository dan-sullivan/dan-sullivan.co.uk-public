# Actual lambdas moved into separate terraform configs/states

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
