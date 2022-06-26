resource "aws_s3_bucket" "state" {
  bucket        = var.bucket_name
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "state" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}

resource "aws_kms_key" "state" {
  description             = "Terraform state key"
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}