resource "aws_iam_role" "user_get_by_id" {
  name = "user-get-by-id-role"

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

resource "aws_iam_role_policy" "user_get_by_id_logs" {
  name = "user-get-by-id-logs"
  role = aws_iam_role.user_get_by_id.id

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
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/user-get-by-id:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "user_get_by_id_dynamodb" {
  name = "user-get-by-id-dynamodb"
  role = aws_iam_role.user_get_by_id.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem"
      ]
      Resource = var.users_dynamodb_table_arn
    }]
  })
}