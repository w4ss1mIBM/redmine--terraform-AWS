# generic variables defined

# AWS Region
variable "region" {
  description = "Region in which AWS Resources to be created"
  type        = string
  default     = "us-east-1"
}
# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
  default     = "prod"
}
# Business Division
variable "owners" {
  description = "organization this Infrastructure belongs"
  type        = string
  default     = "agylas"
}
# Bucket Name S3
variable "BucketName" {
  description = "Bucket Name S3 BACKEND"
  type        = string
  default     = "redmine-tf-backend-state"
}
# Dynamo Db Table Name
variable "DynamoTableName" {
  description = "Dynamo Db Table Name"
  type        = string
  default     = "redmineTfLockState"
}
# VPC variables defined as below
# VPC Name
variable "name" {
  description = "VPC Name"
  type        = string
  default     = "redmine"
}

# VPC CIDR Block
variable "cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

# VPC Availability Zones
variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# VPC Public Subnets
variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]

}

# VPC Private Subnets
variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

}


# VPC Enable NAT Gateway (True or False) 
variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = true
}

# VPC Single NAT Gateway (True or False)
variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = true
}
variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "adminadmin"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "redminedb"
}

variable "route53_zone_id" {
  description = "route53_zone_id"
  type        = string
  default     = "Z102951624MF09YXAHFSF"
}
