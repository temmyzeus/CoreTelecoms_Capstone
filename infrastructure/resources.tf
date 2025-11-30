
resource "aws_s3_bucket" "data_lake_bucket" {
  bucket = "coretelecoms-data-lake-capstone"

  tags = {
    Name        = "CoreTelecomsDataLakeBucket"
    Environment = "Production"
  }
}

resource "snowflake_resource_monitor" "coretelecoms_wh_rm" {
  name = "CORETELECOMS_WAREHOUSE_RESOURCE_MONITOR"
  credit_quota = 200
  frequency = "MONTHLY"
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
  resource_monitor = snowflake_resource_monitor.coretelecoms_wh_rm.fully_qualified_name
}
