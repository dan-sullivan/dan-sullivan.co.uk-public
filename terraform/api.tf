# The API Gateway name
resource "aws_api_gateway_rest_api" "serve_dscouk_api" {
  name = "serve_dscouk_api"
}

# A resource on the API gateway - this is an endpoint. /dscouk in this case
resource "aws_api_gateway_resource" "serve_dscouk_res_dscouk" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.serve_dscouk_api.root_resource_id}"
  path_part   = "dscouk"
}

resource "aws_api_gateway_resource" "serve_dscouk_res_dscouk_res" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  parent_id   = "${aws_api_gateway_resource.serve_dscouk_res_dscouk.id}"
  path_part   = "{proxy+}"
}

# Set up the methods used for the endpoint
#------ DSCOUK GET ------
resource "aws_api_gateway_method" "serve_dscouk_method_get" {
  rest_api_id   = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  resource_id   = "${aws_api_gateway_resource.serve_dscouk_res_dscouk_res.id}"
  http_method   = "GET"
  authorization = "NONE"
}


#------ DSCOUK GET TO LAMBDA ------
resource "aws_api_gateway_integration" "request_method_integration" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  resource_id = "${aws_api_gateway_resource.serve_dscouk_res_dscouk_res.id}"
  http_method = "${aws_api_gateway_method.serve_dscouk_method_get.http_method}"
  type        = "AWS_PROXY"
  uri         = "arn:aws:apigateway:eu-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:serve_dscouk/invocations"

  # HTTP Method from API Gateway to the Lambda. Must be a POST.
  integration_http_method = "POST"
}

#------ DSCOUK GET LAMBDA RESPONSE MAP ------
resource "aws_api_gateway_method_response" "response_method" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  resource_id = "${aws_api_gateway_resource.serve_dscouk_res_dscouk_res.id}"
  http_method = "${aws_api_gateway_method.serve_dscouk_method_get.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}


#------LAMBDA TO DSCOUK GET ------
resource "aws_api_gateway_integration_response" "response_method_integration" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  resource_id = "${aws_api_gateway_resource.serve_dscouk_res_dscouk_res.id}"

  # Always populate the http_method with a resource rather than entering the 
  # method manually to avoid a "Invalid Method identifier specified" error
  # https://github.com/terraform-providers/terraform-provider-aws/issues/815
  http_method = "${aws_api_gateway_method.serve_dscouk_method_get.http_method}"

  status_code = "${aws_api_gateway_method_response.response_method.status_code}"

  response_templates = {
    "application/xml" = <<EOF
#set($inputRoot = $input.path('$'))
<?xml version="1.0" encoding="UTF-8"?>
<message>
    $inputRoot.body
</message>
EOF
  }
}

resource "aws_lambda_permission" "allow_api_gateway" {
  function_name = "${aws_lambda_function.serve_dscouk.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-2:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.serve_dscouk_api.id}/*/GET/*"
}

resource "aws_api_gateway_deployment" "serve_dscouk_api_deployment" {
  rest_api_id = "${aws_api_gateway_rest_api.serve_dscouk_api.id}"
  stage_name  = "production"
  description = "Serve dan-sullivan.co.uk lambda page"

  # Add depencies for your gateway methods to ensure the methods are created
  # before attempting the deployment. Avoids error:
  # "The REST API doesn't contain any methods"
  # https://github.com/hashicorp/terraform/issues/7588
  depends_on = ["aws_api_gateway_method.serve_dscouk_method_get"]
}
