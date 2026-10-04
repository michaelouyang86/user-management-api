resource "aws_dynamodb_table" "users" {
  name         = "user-management-users"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}