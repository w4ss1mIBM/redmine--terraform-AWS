provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "agyla-redmine-tf-backend-state" # Replace with a unique bucket name

  force_destroy = false # Set to true to allow Terraform to empty and delete the bucket on terraform destroy

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "TerraformStateBucket"
    Environment = "Production"
  }
}

#Enable MFA Delete/Versionning (Note: This requires using the AWS CLI to manage versioning)
resource "aws_s3_bucket_versioning" "state_with_mfa" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status   = "Enabled"
  }
}
resource "aws_dynamodb_table" "tf_locks" {
  name           = "redmineTfLockState"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform Locks Table"
  }
}
