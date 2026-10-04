resource "aws_iam_role" "user_delete" {
  name = "user-delete-role"

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

resource "aws_iam_role_policy" "user_delete_logs" {
  name = "user-delete-logs"
  role = aws_iam_role.user_delete.id

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
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/user-delete:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "user_delete_dynamodb" {
  name = "user-delete-dynamodb"
  role = aws_iam_role.user_delete.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:DeleteItem"
      ]
      Resource = var.users_dynamodb_table_arn
    }]
  })
}