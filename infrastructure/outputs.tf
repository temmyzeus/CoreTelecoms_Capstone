# Output the SSM parameter names (not the actual secrets)
output "etl_s3_raw_uploader_secret_key_parameter_name" {
  value       = aws_ssm_parameter.etl_s3_raw_uploader_secret_access_key.name
  description = "The name of the SSM parameter storing the secret access key for the ETL S3 Raw Uploader IAM user"
}

output "etl_s3_raw_uploader_access_key_parameter_name" {
  value       = aws_ssm_parameter.etl_s3_raw_uploader_access_key_id.name
  description = "The name of the SSM parameter storing the access key ID for the ETL S3 Raw Uploader IAM user"
}
