output "user_create_role_arn" {
  value = aws_iam_role.user_create.arn
}

output "user_get_role_arn" {
  value = aws_iam_role.user_get.arn
}

output "user_get_by_id_role_arn" {
  value = aws_iam_role.user_get_by_id.arn
}

output "user_update_role_arn" {
  value = aws_iam_role.user_update.arn
}

output "user_delete_role_arn" {
  value = aws_iam_role.user_delete.arn
}

output "image_generate_download_url_role_arn" {
  value = aws_iam_role.image_generate_download_url.arn
}

output "image_generate_upload_url_role_arn" {
  value = aws_iam_role.image_generate_upload_url.arn
}