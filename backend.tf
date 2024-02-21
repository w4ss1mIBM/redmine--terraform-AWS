# Specific provider name according to the use case has to given!
provider "aws" {
  # Write the region name below in which your environment has to be deployed!
  region = var.region
}
terraform {
  backend "s3" {
    bucket         = "agyla-redmine-tf-backend-state" # Use the bucket name specified above
    key            = "state/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "redmineTfLockState" # Use the DynamoDB table name specified above
    encrypt        = true
  }
}