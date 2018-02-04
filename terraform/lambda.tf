
# Upload the Lambda zip
resource "aws_lambda_function" "serve_dscouk" {
  function_name    = "serve_dscouk${terraform.workspace == "default" ? "" : "_${terraform.workspace}"}"
  handler          = "serve_dscouk.handler"
  runtime          = "python3.6"
  filename         = "zips/serve_dscouk.zip"
  source_code_hash = "${base64sha256(file("zips/serve_dscouk.zip"))}"
  role             = "${data.terraform_remote_state.dscouk_core.lambda_exec_role}"
}

#TODO: Tighten up the source ARN once multiple workspaces are working.
resource "aws_lambda_permission" "allow_api_gateway" {
  function_name = "${aws_lambda_function.serve_dscouk.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-2:${data.aws_caller_identity.current.account_id}:*/*/GET/*"
}
