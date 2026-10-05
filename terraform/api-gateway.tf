locals {
  openapi = yamldecode(
    file("${path.module}/../openapi.yaml")
  )

  lambda_integration_uri = {
    user_get                    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.user_get.arn}/invocations"
    user_get_by_id              = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.user_get_by_id.arn}/invocations"
    user_create                 = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.user_create.arn}/invocations"
    user_update                 = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.user_update.arn}/invocations"
    user_delete                 = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.user_delete.arn}/invocations"
    image_generate_download_url = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.image_generate_download_url.arn}/invocations"
    image_generate_upload_url   = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.image_generate_upload_url.arn}/invocations"
  }

  # API Gateway CORS preflight
  #
  # Browser:
  #   OPTIONS /users
  #
  # API Gateway:
  #   MOCK integration
  #   -> 200 + CORS headers
  #
  # No Lambda invocation is required.
  cors_options = {
    options = {
      summary = "CORS preflight"

      responses = {
        "200" = {
          description = "CORS preflight response"

          headers = {
            Access-Control-Allow-Origin = {
              schema = {
                type = "string"
              }
            }

            Access-Control-Allow-Methods = {
              schema = {
                type = "string"
              }
            }

            Access-Control-Allow-Headers = {
              schema = {
                type = "string"
              }
            }
          }
        }
      }

      "x-amazon-apigateway-integration" = {
        type = "MOCK"

        requestTemplates = {
          "application/json" = "{\"statusCode\": 200}"
        }

        responses = {
          default = {
            statusCode = "200"

            responseParameters = {
              "method.response.header.Access-Control-Allow-Origin"  = "'${var.allowed_origin}'"
              "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE'"
              "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
            }

            responseTemplates = {
              "application/json" = ""
            }
          }
        }
      }
    }
  }

  openapi_with_integrations = merge(
    local.openapi,
    {
      paths = merge(
        local.openapi.paths,

        {
          "/users" = merge(
            local.openapi.paths["/users"],

            {
              # CORS preflight
              options = local.cors_options.options

              get = merge(
                local.openapi.paths["/users"].get,
                {
                  "x-amazon-apigateway-integration" = {
                    type       = "AWS_PROXY"
                    httpMethod = "POST"
                    uri        = local.lambda_integration_uri.user_get
                  }
                }
              )

              post = merge(
                local.openapi.paths["/users"].post,
                {
                  "x-amazon-apigateway-integration" = {
                    type       = "AWS_PROXY"
                    httpMethod = "POST"
                    uri        = local.lambda_integration_uri.user_create
                  }
                }
              )
            }
          )

          "/users/{userId}" = merge(
            local.openapi.paths["/users/{userId}"],

            {
              # CORS preflight
              options = local.cors_options.options

              get = merge(
                local.openapi.paths["/users/{userId}"].get,
                {
                  "x-amazon-apigateway-integration" = {
                    type       = "AWS_PROXY"
                    httpMethod = "POST"
                    uri        = local.lambda_integration_uri.user_get_by_id
                  }
                }
              )

              put = merge(
                local.openapi.paths["/users/{userId}"].put,
                {
                  "x-amazon-apigateway-integration" = {
                    type       = "AWS_PROXY"
                    httpMethod = "POST"
                    uri        = local.lambda_integration_uri.user_update
                  }
                }
              )

              delete = merge(
                local.openapi.paths["/users/{userId}"].delete,
                {
                  "x-amazon-apigateway-integration" = {
                    type       = "AWS_PROXY"
                    httpMethod = "POST"
                    uri        = local.lambda_integration_uri.user_delete
                  }
                }
              )
            }
          )

          "/images/url" = merge(
            local.openapi.paths["/images/url"],

            {
              # CORS preflight
              options = local.cors_options.options

              get = merge(
                local.openapi.paths["/images/url"].get,
                {
                  "x-amazon-apigateway-integration" = {
                    type       = "AWS_PROXY"
                    httpMethod = "POST"
                    uri        = local.lambda_integration_uri.image_generate_download_url
                  }
                }
              )

              post = merge(
                local.openapi.paths["/images/url"].post,
                {
                  "x-amazon-apigateway-integration" = {
                    type       = "AWS_PROXY"
                    httpMethod = "POST"
                    uri        = local.lambda_integration_uri.image_generate_upload_url
                  }
                }
              )
            }
          )
        }
      )
    }
  )
}

# Create the API Gateway REST API using the OpenAPI specification with Lambda integrations
resource "aws_api_gateway_rest_api" "user_management" {
  name = "user-management-api"

  body = jsonencode(local.openapi_with_integrations)

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create a deployment for the API Gateway
resource "aws_api_gateway_deployment" "user_management" {
  rest_api_id = aws_api_gateway_rest_api.user_management.id

  triggers = {
    redeployment = sha1(
      jsonencode(local.openapi_with_integrations)
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create a stage for the API Gateway deployment
resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.user_management.id
  deployment_id = aws_api_gateway_deployment.user_management.id
  stage_name    = "dev"
}

# Lambda permissions for API Gateway to invoke the Lambda functions
resource "aws_lambda_permission" "user_get" {
  statement_id = "AllowApiGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.user_get.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/GET/users"
}

resource "aws_lambda_permission" "user_get_by_id" {
  statement_id = "AllowApiGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.user_get_by_id.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/GET/users/*"
}

resource "aws_lambda_permission" "user_create" {
  statement_id = "AllowApiGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.user_create.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/POST/users"
}

resource "aws_lambda_permission" "user_update" {
  statement_id = "AllowApiGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.user_update.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/PUT/users/*"
}

resource "aws_lambda_permission" "user_delete" {
  statement_id = "AllowApiGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.user_delete.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/DELETE/users/*"
}

resource "aws_lambda_permission" "image_generate_download_url" {
  statement_id = "AllowApiGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.image_generate_download_url.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/GET/images/url"
}

resource "aws_lambda_permission" "image_generate_upload_url" {
  statement_id = "AllowApiGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.image_generate_upload_url.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/POST/images/url"
}