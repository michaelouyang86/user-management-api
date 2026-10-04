terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "iam" {
  source = "./iam"

  aws_region = var.aws_region
  users_dynamodb_table_arn = aws_dynamodb_table.users.arn
  users_s3_bucket_arn = aws_s3_bucket.user_management_api.arn
}