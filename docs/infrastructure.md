# Infrastructure Specification

AWS infrastructure for the User Management API, managed by Terraform in `terraform/`. This document is the source of truth for generating or changing Terraform config. API paths, methods and payloads are defined only in `openapi.yaml`.

## Terraform setup

* **Terraform version:** `>= 1.6.0`
* **AWS provider:** `hashicorp/aws`, `~> 6.0`, `region = var.aws_region`
* **Working directory:** `terraform/`; all paths to project files are relative to it (`../openapi.yaml`, `../dist/<function>.zip`)
* **Account ID:** `data "aws_caller_identity" "current"` (declared in both the root module and the `iam` module)

### Input variables

| Variable | Type | Purpose | Value in `terraform.tfvars` |
|---|---|---|---|
| `aws_region` | `string` | Region for all resources | Region you are deploying to |
| `allowed_origin` | `string` | Frontend origin allowed by CORS (API Gateway, Lambda responses, S3) | CloudFront distribution URL |

## Functions

One Lambda function, one IAM role and one API Gateway integration per operation.

| Function | Method + path (`openapi.yaml`) | AWS permission | Resource | Env vars |
|---|---|---|---|---|
| `user-get` | `GET /users` | `dynamodb:Scan` | users table | `TABLE_NAME`, `ALLOWED_ORIGIN` |
| `user-create` | `POST /users` | `dynamodb:PutItem` | users table | `TABLE_NAME`, `ALLOWED_ORIGIN` |
| `user-get-by-id` | `GET /users/{userId}` | `dynamodb:GetItem` | users table | `TABLE_NAME`, `ALLOWED_ORIGIN` |
| `user-update` | `PUT /users/{userId}` | `dynamodb:UpdateItem` | users table | `TABLE_NAME`, `ALLOWED_ORIGIN` |
| `user-delete` | `DELETE /users/{userId}` | `dynamodb:DeleteItem` | users table | `TABLE_NAME`, `ALLOWED_ORIGIN` |
| `image-generate-download-url` | `GET /images/url` | `s3:GetObject` | `<bucket_arn>/*` | `BUCKET_NAME`, `ALLOWED_ORIGIN` |
| `image-generate-upload-url` | `POST /images/url` | `s3:PutObject` | `<bucket_arn>/*` | `BUCKET_NAME`, `ALLOWED_ORIGIN` |

Presigned URLs are signed with the function's role, so the role's S3 permission is what authorizes the client's later GET/PUT.

## Naming conventions

For a function named `<function>` (kebab-case, e.g. `user-get-by-id`); Terraform resource labels use the snake_case form (`user_get_by_id`):

| Item | Name |
|---|---|
| Lambda function | `<function>` |
| IAM role | `<function>-role` |
| IAM inline policies | `<function>-logs`, `<function>-dynamodb` or `<function>-s3` |
| IAM module output | `<function_snake>_role_arn` |
| Deployment package | `dist/<function>.zip` |
| DynamoDB table | `user-management-users` |
| S3 bucket | `user-management-api-<account_id>-<region>-an` |
| REST API | `user-management-api` |
| Stage | `dev` |

## DynamoDB (`dynamodb.tf`)

* **Resource:** `aws_dynamodb_table.users`
* **Name:** `user-management-users`
* **Billing mode:** `PAY_PER_REQUEST`
* **Partition key:** `user_id` (`S`); no sort key, no indexes

## S3 (`s3.tf`)

* **Resource:** `aws_s3_bucket.user_management_api`
* **Name:** `format("user-management-api-%s-%s-an", data.aws_caller_identity.current.account_id, var.aws_region)`
* **Namespace:** `bucket_namespace = "account-regional"`
* **CORS** (`aws_s3_bucket_cors_configuration`), required because browsers use the presigned URLs directly:
  * `allowed_origins = [var.allowed_origin]`
  * `allowed_methods = ["GET", "PUT"]`
  * `allowed_headers = ["Content-Type"]`
  * `max_age_seconds = 3600`

## Lambda (`lambda.tf`)

One `aws_lambda_function` per function:

* **Runtime:** `nodejs24.x`
* **Handler:** `index.handler`
* **Role:** `module.iam.<function_snake>_role_arn`
* **Package:** `filename = "../dist/<function>.zip"`, `source_code_hash = filebase64sha256("../dist/<function>.zip")`
* **Lifecycle:** `ignore_changes = [filename, source_code_hash]` (code is deployed outside Terraform after the first apply)
* **Environment:** shared locals, chosen per the Functions table:
  * `user_lambda_environment` = `{ TABLE_NAME = aws_dynamodb_table.users.name, ALLOWED_ORIGIN = var.allowed_origin }`
  * `image_lambda_environment` = `{ BUCKET_NAME = aws_s3_bucket.user_management_api.bucket, ALLOWED_ORIGIN = var.allowed_origin }`

The zip files must exist (`npm run build && npm run package`) before `terraform plan`.

## IAM (`iam/` module)

* **Called from** `main.tf` as `module "iam"` with inputs `aws_region`, `users_dynamodb_table_arn`, `users_s3_bucket_arn`
* **Outputs:** one `<function_snake>_role_arn` per function (`iam/outputs.tf`)
* **Files:** one `iam/iam-<function>.tf` per function containing:
  1. `aws_iam_role` `<function>-role` — trust policy `Principal.Service = "lambda.amazonaws.com"`, `Action = "sts:AssumeRole"`
  2. `aws_iam_role_policy` `<function>-logs`:
     * `logs:CreateLogGroup` on `arn:aws:logs:<region>:<account_id>:*`
     * `logs:CreateLogStream`, `logs:PutLogEvents` on `arn:aws:logs:<region>:<account_id>:log-group:/aws/lambda/<function>:*`
  3. `aws_iam_role_policy` `<function>-dynamodb` or `<function>-s3` — only the single action from the Functions table, on `var.users_dynamodb_table_arn` or `"${var.users_s3_bucket_arn}/*"`

No managed policies and no wildcard actions.

## API Gateway (`api-gateway.tf`)

### REST API

* **Resource:** `aws_api_gateway_rest_api.user_management`, name `user-management-api`
* **Endpoint type:** `REGIONAL`
* **Body:** `jsonencode(local.openapi_with_integrations)`, where `local.openapi = yamldecode(file("${path.module}/../openapi.yaml"))` and each operation is `merge()`d with its integration block. `openapi.yaml` itself contains no AWS extensions.

### Lambda integration (every operation)

```hcl
"x-amazon-apigateway-integration" = {
  type       = "AWS_PROXY"
  httpMethod = "POST"
  uri        = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/<lambda_arn>/invocations"
}
```

URIs are kept in `local.lambda_integration_uri`, keyed by snake_case function name.

### CORS preflight (every path)

An `options` operation (`local.cors_options.options`) is injected into each path:

* **Integration:** `type = "MOCK"`, request template `{"statusCode": 200}`
* **Method response 200** declares headers `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`
* **Integration response values:**
  * `Access-Control-Allow-Origin: '${var.allowed_origin}'`
  * `Access-Control-Allow-Methods: 'GET,POST,PUT,DELETE'`
  * `Access-Control-Allow-Headers: 'Content-Type'`

Non-preflight responses get the same CORS headers from the Lambda (`src/shared/cors.ts`), so these values must stay in sync.

### Deployment and stage

* `aws_api_gateway_deployment.user_management`: `triggers.redeployment = sha1(jsonencode(local.openapi_with_integrations))`, `lifecycle.create_before_destroy = true`
* `aws_api_gateway_stage.dev`: `stage_name = "dev"`

### Invoke permissions

One `aws_lambda_permission` per function:

* `statement_id = "AllowApiGatewayInvoke"`
* `action = "lambda:InvokeFunction"`
* `principal = "apigateway.amazonaws.com"`
* `source_arn = "${aws_api_gateway_rest_api.user_management.execution_arn}/*/<METHOD>/<path>"`, with path parameters replaced by `*` (e.g. `/*/GET/users/*`)

## Adding a new function

1. Add the IAM file `iam/iam-<function>.tf` and its output in `iam/outputs.tf`.
2. Add the `aws_lambda_function` in `lambda.tf` using the matching environment local.
3. Add its URI to `local.lambda_integration_uri` and merge its integration into the path in `local.openapi_with_integrations`; if the path is new, also add the `options` preflight.
4. Add its `aws_lambda_permission`, scoped to method and path.
5. Add a row to the Functions table above.
