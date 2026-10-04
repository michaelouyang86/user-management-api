resource "aws_iam_role" "image_generate_upload_url" {
  name = "image-generate-upload-url-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "image_generate_upload_url_logs" {
  name = "image-generate-upload-url-logs"
  role = aws_iam_role.image_generate_upload_url.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/image-generate-upload-url:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "image_generate_upload_url_s3" {
  name = "image-generate-upload-url-s3"
  role = aws_iam_role.image_generate_upload_url.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject"
      ]
      Resource = "${var.users_s3_bucket_arn}/*"
    }]
  })
}