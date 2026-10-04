resource "aws_s3_bucket" "user_management_api" {
  bucket = format(
    "user-management-api-%s-%s-an",
    data.aws_caller_identity.current.account_id,
    var.aws_region
  )

  bucket_namespace = "account-regional"
}

resource "aws_s3_bucket_cors_configuration" "user_management_api" {
  bucket = aws_s3_bucket.user_management_api.id

  cors_rule {
    allowed_origins = [
      var.allowed_origin
    ]

    allowed_methods = [
      "GET",
      "PUT"
    ]

    allowed_headers = ["Content-Type"]

    max_age_seconds = 3600
  }
}