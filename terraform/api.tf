# A resource on the API gateway - this is an endpoint. /dscouk in this case
resource "aws_api_gateway_resource" "serve_dscouk_res_dscouk" {
  rest_api_id = "${data.terraform_remote_state.dscouk_core.api_id}"
  parent_id = "${data.terraform_remote_state.dscouk_core.api_root_resource_id}"
  path_part  = "${terraform.workspace == "default" ? "dscouk" : terraform.workspace}"
}

resource "aws_api_gateway_resource" "serve_dscouk_res_dscouk_res" {
  rest_api_id = "${data.terraform_remote_state.dscouk_core.api_id}"
  parent_id   = "${aws_api_gateway_resource.serve_dscouk_res_dscouk.id}"
  path_part   = "{proxy+}"
}

# Set up the methods used for the endpoint
#------ DSCOUK GET ------
resource "aws_api_gateway_method" "serve_dscouk_method_get" {
  rest_api_id   = "${data.terraform_remote_state.dscouk_core.api_id}"
  resource_id   = "${aws_api_gateway_resource.serve_dscouk_res_dscouk_res.id}"
  http_method   = "GET"
  authorization = "NONE"
}


#------ DSCOUK GET TO LAMBDA ------
resource "aws_api_gateway_integration" "request_method_integration" {
  rest_api_id = "${data.terraform_remote_state.dscouk_core.api_id}"
  resource_id = "${aws_api_gateway_resource.serve_dscouk_res_dscouk_res.id}"
  http_method = "${aws_api_gateway_method.serve_dscouk_method_get.http_method}"
  type        = "AWS_PROXY"
  uri         = "arn:aws:apigateway:eu-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:serve_dscouk${terraform.workspace == "default" ? "" : "_${terraform.workspace}"}/invocations"

  # HTTP Method from API Gateway to the Lambda. Must be a POST.
  integration_http_method = "POST"
}

#------ DSCOUK GET LAMBDA RESPONSE MAP ------
resource "aws_api_gateway_method_response" "response_method" {
  rest_api_id = "${data.terraform_remote_state.dscouk_core.api_id}"
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
  rest_api_id = "${data.terraform_remote_state.dscouk_core.api_id}"
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

resource "aws_api_gateway_deployment" "serve_dscouk_api_deployment" {
  rest_api_id = "${data.terraform_remote_state.dscouk_core.api_id}"
  stage_name  = "${terraform.workspace == "default" ? "production" : terraform.workspace}"
  description = "Serve dan-sullivan.co.uk lambda page"

  depends_on = ["aws_api_gateway_integration_response.response_method_integration"]
}
