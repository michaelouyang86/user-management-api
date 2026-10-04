# User Management API

A serverless REST API for managing users and their profile images, built on AWS Lambda, API Gateway, DynamoDB and S3, and deployed with Terraform.

## Features

* Create, list, get, update and delete users
* Upload and download images through presigned S3 URLs, so files never pass through Lambda
* One Lambda function and one least-privilege IAM role per endpoint

## Documentation

| Document | Contents |
|---|---|
| [`openapi.yaml`](openapi.yaml) | API spec: endpoints, request/response schemas, status codes |
| [`docs/infrastructure.md`](docs/infrastructure.md) | AWS resources, naming, IAM and Terraform layout |
| [`CLAUDE.md`](CLAUDE.md) | Tech stack, directory structure and coding rules |

To browse the API, paste `openapi.yaml` into [Swagger Editor](https://editor.swagger.io).

## Prerequisites

* Node.js and npm
* Terraform `>= 1.6.0`
* AWS credentials configured for the target account (e.g. `aws configure`)

## Getting started

Install dependencies:

```bash
npm install
```

Build and package the Lambda functions (writes `dist/<function>.zip`):

```bash
npm run build
npm run package
```

## Deployment

1. Set the variables in `terraform/terraform.tfvars`:

   ```hcl
   aws_region     = "<aws-region>"        # e.g. ap-east-2
   allowed_origin = "<frontend-origin>"   # e.g. https://example.cloudfront.net
   ```

2. Deploy:

   ```bash
   cd terraform
   terraform init
   terraform apply
   ```

The API is published on the `dev` stage:

```text
https://<rest-api-id>.execute-api.<aws-region>.amazonaws.com/dev
```

### Updating function code

Terraform ignores code changes to existing Lambda functions after the first apply. Upload a new build with the AWS CLI instead:

```bash
npm run build && npm run package
aws lambda update-function-code --function-name <function> --zip-file fileb://dist/<function>.zip
```

## Image upload flow

1. `POST /images/url` with `{ "content_type": "image/jpeg" }` returns an `image_key` and a presigned `upload_url`.
2. The client sends a `PUT` request with the file to `upload_url`, using the same `Content-Type` header.
3. Store the `image_key` on a user with `POST /users` or `PUT /users/{userId}`.
4. `GET /images/url?key=<image_key>` returns a presigned `download_url`.

Presigned URLs expire after 5 minutes.
