# Redmine on AWS with Terraform

This project contains Terraform configurations to deploy a Redmine application on AWS, leveraging services like Amazon EC2, RDS (Aurora), Application Load Balancer (ALB), S3, and DynamoDB for a scalable, secure, and highly available environment.

## Architecture Overview

The designed architecture aims for high availability and scalability, incorporating:

- **Amazon VPC**: Hosting infrastructure components, ensuring isolated networking.
- **Amazon EC2**: Running the Redmine application in a secure and scalable manner.
- **Amazon RDS Aurora**: Providing a reliable and high-performance database service.
- **Application Load Balancer (ALB)**: Balancing incoming traffic to maintain smooth application access.
- **Amazon S3**: Storing Terraform state files securely and durably.
- **Amazon DynamoDB**: Managing Terraform state locking to prevent state corruption.

### High-Level Diagram

[User] --> [ALB] --> [EC2 Instances: Redmine]
                    [RDS: Aurora MySQL] <--|
                    [S3: Terraform State] <-- Management & State Storage
                    [DynamoDB: State Lock] <--|


## Prerequisites

- AWS Account
- Terraform installed on your machine
- AWS CLI configured
- An SSH Key Pair for EC2 access

## Deployment Steps

1. **Clone the Repository**

   ```bash
   git clone https://git.software-factory.agyla.cloud/wassim.souilah/redmine-v2
