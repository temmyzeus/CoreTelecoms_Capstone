
resource "aws_s3_bucket" "data_lake_bucket" {
  bucket = "coretelecoms-data-lake-capstone"

  tags = {
    Name        = "CoreTelecomsDataLakeBucket"
    Environment = "Production"
  }
}

# Create AWS IAM user with s3 upload priviledge and and save to SSM Parameter Store
resource "aws_iam_user" "etl_s3_raw_uploader" {
  name = "CoreTelecoms_ETL_S3_Raw_Uploader"
  path = "/production/core-telecoms/data-lake/airflow/"
  tags = {
    "Application" = "Airflow"
    Component     = "S3Uploader"
    Purpose       = "ETLDataIngestion"
  }
}

resource "aws_iam_access_key" "etl_s3_raw_uploader_key" {
  user = aws_iam_user.etl_s3_raw_uploader.name
}

resource "aws_iam_policy" "etl_s3_raw_uploader_policy" {
  name = "CoreTelecoms_ETL_S3_Raw_Uploader_Policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.data_lake_bucket.arn}",
          "${aws_s3_bucket.data_lake_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_ssm_parameter" "etl_s3_raw_uploader_access_key_id" {
  name        = "/production/core-telecoms/data-lake/s3-raw-uploader/access-key-id"
  description = "Access Key ID for CoreTelecoms ETL S3 Raw Uploader IAM User"
  type        = "SecureString"
  value       = aws_iam_access_key.etl_s3_raw_uploader_key.id
  tags = {
    environment = "production",
    project     = "CoreTelecoms_Capstone"
  }
}

resource "aws_ssm_parameter" "etl_s3_raw_uploader_secret_access_key" {
  name        = "/production/core-telecoms/data-lake/s3-raw-uploader/secret-access-key"
  description = "Secret Access Key for CoreTelecoms ETL S3 Raw Uploader IAM User"
  type        = "SecureString"
  value       = aws_iam_access_key.etl_s3_raw_uploader_key.secret
  tags = {
    environment = "production",
    project     = "CoreTelecoms_Capstone"
  }
}

resource "aws_ssm_parameter" "snowflake_user_login" {
  name        = "/production/core-telecoms/data-lake/snowflake/login"
  description = "Login for CoreTelecoms Snowflake User"
  type        = "SecureString"
  value       = snowflake_user.coretelecoms_etl_user.login_name
  tags = {
    environment = "production",
    project     = "CoreTelecoms_Capstone",
    application = "Snowflake"
  }
}

resource "aws_ssm_parameter" "snowflake_user_password" {
  name        = "/production/core-telecoms/data-lake/snowflake/password"
  description = "Password for CoreTelecoms Snowflake User"
  type        = "SecureString"
  value       = snowflake_user.coretelecoms_etl_user.password
  tags = {
    environment = "production",
    project     = "CoreTelecoms_Capstone",
    application = "Snowflake"
  }
}

resource "snowflake_resource_monitor" "coretelecoms_wh_rm" {
  name            = "CORETELECOMS_WAREHOUSE_RESOURCE_MONITOR"
  credit_quota    = 200
  frequency       = "MONTHLY"
  notify_triggers = [25, 50, 75, 90]
  start_timestamp = "2025-12-01 00:00" # Use current timestamp
}

resource "snowflake_warehouse" "coretelecoms_wh" {
  name                                = "CORETELECOMS_WAREHOUSE"
  warehouse_type                      = "STANDARD"
  generation                          = "2"
  warehouse_size                      = "MEDIUM"
  auto_resume                         = true
  auto_suspend                        = 300 # Suspend after 5 minutes of inactivity
  comment                             = "Data warehouse for the CoreTelecoms Capstone Projects, for unifying customer experience data and analytics."
  initially_suspended                 = true
  max_concurrency_level               = 4   # Allow up to 4 concurrent sql queries
  statement_queued_timeout_in_seconds = 120 # Cancel queries after being queued for 2 minutes
  statement_timeout_in_seconds        = 86400
  resource_monitor                    = snowflake_resource_monitor.coretelecoms_wh_rm.fully_qualified_name
}

resource "snowflake_database" "coretelecoms_wh_complaints_db" {
  name    = "CUSTOMER_COMPLAINTS"
  comment = "Database for storing customer complaints data for CoreTelecoms Capstone Project."
}

resource "random_password" "snowflake_user_password" {
  length           = 20
  special          = true
  override_special = ":."
}

resource "snowflake_user" "coretelecoms_etl_user" {
  name                 = "CORETELECOMS_ETL_USER"
  default_warehouse    = snowflake_warehouse.coretelecoms_wh.name
  login_name           = "CORETELECOMS_ETL_USER"
  password             = random_password.snowflake_user_password.result
  default_role         = "USERADMIN"
  must_change_password = false
  comment              = "ETL User for CoreTelecoms Capstone Project"
}

resource "snowflake_schema" "bronze" {
  name         = "BRONZE"
  database     = snowflake_database.coretelecoms_wh_complaints_db.name
  is_transient = true
  comment      = "Schema for storing customer complaints data for CoreTelecoms Capstone Project."
}

resource "snowflake_file_format" "example_file_format" {
  name        = "BRONZE_PARQUET_FORMAT"
  database    = snowflake_database.coretelecoms_wh_complaints_db.name
  schema      = snowflake_schema.bronze.name
  format_type = "PARQUET"
}

resource "snowflake_stage" "bronze_stage_call_logs" {
  name        = "CORE_TELECOMS_CALL_LOGS"
  url         = "s3://coretelecoms-data-lake-capstone/raw/call_logs/"
  database    = snowflake_database.coretelecoms_wh_complaints_db.name
  schema      = snowflake_schema.bronze.name
  credentials = "AWS_KEY_ID = '${aws_iam_access_key.etl_s3_raw_uploader_key.id}' AWS_SECRET_KEY = '${aws_iam_access_key.etl_s3_raw_uploader_key.secret}'"
  file_format = "TYPE = PARQUET"
  comment     = "Stage for Core Telecoms Call Logs data in Parquet format"
}

resource "snowflake_stage" "bronze_stage_social_media" {
  name        = "CORE_TELECOMS_SOCIAL_MEDIA"
  url         = "s3://coretelecoms-data-lake-capstone/raw/social_medias/"
  database    = snowflake_database.coretelecoms_wh_complaints_db.name
  schema      = snowflake_schema.bronze.name
  credentials = "AWS_KEY_ID = '${aws_iam_access_key.etl_s3_raw_uploader_key.id}' AWS_SECRET_KEY = '${aws_iam_access_key.etl_s3_raw_uploader_key.secret}'"
  file_format = "TYPE = PARQUET"
  comment     = "Stage for Core Telecoms Social Media data in Parquet format"
}

resource "snowflake_stage" "bronze_stage_customers" {
  name        = "CORE_TELECOMS_CUSTOMERS"
  url         = "s3://coretelecoms-data-lake-capstone/raw/customers/customers_dataset.parquet"
  database    = snowflake_database.coretelecoms_wh_complaints_db.name
  schema      = snowflake_schema.bronze.name
  credentials = "AWS_KEY_ID = '${aws_iam_access_key.etl_s3_raw_uploader_key.id}' AWS_SECRET_KEY = '${aws_iam_access_key.etl_s3_raw_uploader_key.secret}'"
  file_format = "TYPE = PARQUET"
  comment     = "Stage for Core Telecoms Customers data in Parquet format"
}
