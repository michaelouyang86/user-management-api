locals {
  user_lambda_environment = {
    TABLE_NAME = aws_dynamodb_table.users.name
    ALLOWED_ORIGIN = var.allowed_origin
  }

  image_lambda_environment = {
    BUCKET_NAME = aws_s3_bucket.user_management_api.bucket
    ALLOWED_ORIGIN = var.allowed_origin
  }
}

resource "aws_lambda_function" "user_get" {
  function_name = "user-get"

  runtime = "nodejs24.x"
  handler = "index.handler"

  role = module.iam.user_get_role_arn

  filename         = "../dist/user-get.zip"
  source_code_hash = filebase64sha256("../dist/user-get.zip")

  environment {
    variables = local.user_lambda_environment
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}


resource "aws_lambda_function" "user_get_by_id" {
  function_name = "user-get-by-id"

  runtime = "nodejs24.x"
  handler = "index.handler"

  role = module.iam.user_get_by_id_role_arn

  filename         = "../dist/user-get-by-id.zip"
  source_code_hash = filebase64sha256("../dist/user-get-by-id.zip")

  environment {
    variables = local.user_lambda_environment
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}


resource "aws_lambda_function" "user_create" {
  function_name = "user-create"

  runtime = "nodejs24.x"
  handler = "index.handler"

  role = module.iam.user_create_role_arn

  filename         = "../dist/user-create.zip"
  source_code_hash = filebase64sha256("../dist/user-create.zip")

  environment {
    variables = local.user_lambda_environment
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}


resource "aws_lambda_function" "user_update" {
  function_name = "user-update"

  runtime = "nodejs24.x"
  handler = "index.handler"

  role = module.iam.user_update_role_arn

  filename         = "../dist/user-update.zip"
  source_code_hash = filebase64sha256("../dist/user-update.zip")

  environment {
    variables = local.user_lambda_environment
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}


resource "aws_lambda_function" "user_delete" {
  function_name = "user-delete"

  runtime = "nodejs24.x"
  handler = "index.handler"

  role = module.iam.user_delete_role_arn

  filename         = "../dist/user-delete.zip"
  source_code_hash = filebase64sha256("../dist/user-delete.zip")

  environment {
    variables = local.user_lambda_environment
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}


resource "aws_lambda_function" "image_generate_download_url" {
  function_name = "image-generate-download-url"

  runtime = "nodejs24.x"
  handler = "index.handler"

  role = module.iam.image_generate_download_url_role_arn

  filename         = "../dist/image-generate-download-url.zip"
  source_code_hash = filebase64sha256("../dist/image-generate-download-url.zip")

  environment {
    variables = local.image_lambda_environment
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}


resource "aws_lambda_function" "image_generate_upload_url" {
  function_name = "image-generate-upload-url"

  runtime = "nodejs24.x"
  handler = "index.handler"

  role = module.iam.image_generate_upload_url_role_arn

  filename         = "../dist/image-generate-upload-url.zip"
  source_code_hash = filebase64sha256("../dist/image-generate-upload-url.zip")

  environment {
    variables = local.image_lambda_environment
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}