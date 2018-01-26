
terraform {
  required_version = ">= 0.10.1"
  backend "s3" {
    bucket = "dscouk-state"
    key    = "prod-lambda/terraform.state"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"
}

# Use main state file as a data source
data "terraform_remote_state" "dscouk_main" {
  backend = "s3"
  config {
    bucket = "dscouk-state"
    key    = "prod/terraform.state"
    region = "eu-west-2"
  }
}

data "aws_caller_identity" "current" {}

# Upload the Lambda zip
resource "aws_lambda_function" "serve_dscouk" {
  function_name    = "serve_dscouk"
  handler          = "serve_dscouk.handler"
  runtime          = "python3.6"
  filename         = "zips/serve_dscouk.zip"
  source_code_hash = "${base64sha256(file("zips/serve_dscouk.zip"))}"
  role             = "${data.terraform_remote_state.dscouk_main.lambda_exec_role}"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  function_name = "${aws_lambda_function.serve_dscouk.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-2:${data.aws_caller_identity.current.account_id}:${data.terraform_remote_state.dscouk_main.api_id}/*/GET/*"
}

