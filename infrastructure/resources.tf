
resource "aws_s3_bucket" "data_lake_bucket" {
  bucket = "coretelecoms-data-lake-capstone"

  tags = {
    Name        = "CoreTelecomsDataLakeBucket"
    Environment = "Production"
  }
}
