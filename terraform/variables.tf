variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "allowed_origin" {
  description = "Frontend origin allowed to access the API"
  type        = string
}