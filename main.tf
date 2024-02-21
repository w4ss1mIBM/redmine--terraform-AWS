

# VPC
resource "aws_vpc" "redmine_vpc" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name}-${var.environment}"
    Environment = var.environment
    Owners      = var.owners
  }
}

# Subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnets)
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = element(var.azs, count.index)
  vpc_id                  = aws_vpc.redmine_vpc.id
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet ${count.index + 1}"

  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnets)
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(var.azs, count.index)
  vpc_id            = aws_vpc.redmine_vpc.id

  tags = {
    Name = "Private Subnet ${count.index + 1}"

  }
}

# Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.redmine_vpc.id

  tags = {
    Name = "IGW for ${var.name}-${var.environment}"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  count         = var.enable_nat_gateway ? 1 : 0
  subnet_id     = aws_subnet.public_subnets[0].id
  allocation_id = aws_eip.my_eip[0].id
  tags = {
    Name = "NATGATEWAY REDMINE"
  }
}

# Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.redmine_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "Public Route Table for ${var.name}-${var.environment}"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.redmine_vpc.id

  tags = {
    Name = "Private Route Table for ${var.name}-${var.environment}"
  }
}

resource "aws_route" "private_route_to_nat" {
  count                  = var.enable_nat_gateway && var.single_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway[0].id
}

# Associate Subnets with Route Tables
resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_association" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

# Elastic IPs for NAT Gateway
resource "aws_eip" "my_eip" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  tags = {
    Name = "EIP FOR NATGATEWAY REDMINE"
  }
}

# Security Groups
resource "aws_security_group" "ec2_sg_redmine" {
  name        = "ec2_sg_redmine"
  description = "Security Group for EC2 instance"
  vpc_id      = aws_vpc.redmine_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_redmine.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to any IP address
  }
  tags = {
    Name = "Security Group for ECS Redmine"
  }

}

resource "aws_security_group" "alb_sg_redmine" {
  name        = "alb_sg_redmine"
  description = "Security Group for ALB"
  vpc_id      = aws_vpc.redmine_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from any IP address (Internet)
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "https"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from any IP address (Internet)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to any IP address
  }
  tags = {
    Name = "Security Group for ALB Redmine"
  }
}

resource "aws_security_group" "aurora_sg_redmine" {
  name        = "aurora_sg_redmine"
  description = "Security Group for Aurora Database"
  vpc_id      = aws_vpc.redmine_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg_redmine.id]
  }

  tags = {
    Name = "Security Group for AURORA Redmine"
  }
}


# Aurora Cluster
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "aurora-cluster-redmine"
  engine                  = "aurora-mysql"
  engine_mode             = "serverless"
  master_username         = var.db_username
  master_password         = var.db_password
  database_name           = var.db_name
  port                    = 3306
  engine_version          = "5.7.mysql_aurora.2.11.3"
  availability_zones      = var.azs
  storage_encrypted       = true
  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  skip_final_snapshot     = true
  apply_immediately       = true

  # Aurora Cluster Parameters (Optional, adjust as needed)
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name

  vpc_security_group_ids = [aws_security_group.aurora_sg_redmine.id] # Associate with the Aurora Security Group

  scaling_configuration {
    auto_pause               = true #Aurora Serverless can automatically pause during periods of inactivity to save costs
    max_capacity             = 32
    min_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"

  }


}

# Aurora Cluster Subnet Group
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "aurora-subnet-group-redmine"
  subnet_ids = aws_subnet.private_subnets[*].id
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_cloudwatch_ssm_role" {
  name = "ec2_cloudwatch_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_cloudwatch_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_cloudwatch_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_read_only_access" {
  role       = aws_iam_role.ec2_cloudwatch_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
#EC2 instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_cloudwatch_ssm_profile"
  role = aws_iam_role.ec2_cloudwatch_ssm_role.name
}



#EC2 instance creation 
resource "aws_instance" "redmine_server" {
  ami                     = "ami-0c7217cdde317cfec" 
  instance_type           = "c5.xlarge"
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile.name
  key_name                = "redmine" # Specify your SSH key name
  subnet_id               = aws_subnet.private_subnets[0].id # Updated to reflect correct variable name
  user_data               = file("user-data-script.sh") # Path to your user data script
  vpc_security_group_ids  = [aws_security_group.ec2_sg_redmine.id] # Attach to security group

  metadata_options {
    http_tokens                      = "required" # Enable IMDSv2
    http_endpoint                    = "enabled"
    http_put_response_hop_limit      = 2
    instance_metadata_tags           = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
  }

  tags = {
    Name = "RedmineServer"
  }
  # Ensure EC2 creation waits for SSM Parameters to be created
  depends_on = [
    aws_ssm_parameter.db_name,
    aws_ssm_parameter.db_host,
    aws_ssm_parameter.db_user,
    aws_ssm_parameter.db_password,
    aws_ssm_parameter.db_encoding
  ]
}

# Application Load Balancer (ALB)
resource "aws_lb" "alb_redmine" {
  name               = "alb-redmine"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_redmine.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

  enable_http2                     = true
  idle_timeout                     = 60
  enable_cross_zone_load_balancing = true
  depends_on = [ aws_instance.redmine_server ]

  tags = {
    Name = "ALB for Redmine ec2"
  }
}

# ALB Listener
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb_redmine.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.redmine_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_redmine_target_group.arn
  }

}

resource "aws_route53_record" "redmine_dns" {
  zone_id = "Z102951624MF09YXAHFSF"
  name    = "redmine.argocd-agyla.cloud"
  type    = "A"

  alias {
    name                   = aws_lb.alb_redmine.dns_name
    zone_id                = aws_lb.alb_redmine.zone_id
    evaluate_target_health = true
  }
  depends_on = [ aws_instance.redmine_server ]

}
# resource "aws_acm_certificate" "redmine_cert" {
#   domain_name       = "redmine.agyla.cloud"
#   validation_method = "DNS"

#   tags = {
#     Name = "redmineeCertificate"
#   }
#   depends_on = [ aws_route53_record.redmine_dns ]
#   lifecycle {
#     create_before_destroy = true
#   }
# }
data "aws_acm_certificate" "redmine_cert" {
  domain   = "argocd-agyla.cloud"
  statuses = ["ISSUED"]
  most_recent = true
}


# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.redmine_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }


resource "aws_route53_record" "alb_record" {
  zone_id = var.route53_zone_id  # Replace with your Route 53 hosted zone ID
  name    = "agyla-redmine.com" # The domain name you want to associate with the ALB
  type    = "A"
  alias {
    name                   = aws_lb.alb_redmine.dns_name
    zone_id                = aws_lb.alb_redmine.zone_id
    evaluate_target_health = true
  }
}

# ALB Target Group
resource "aws_lb_target_group" "ec2_redmine_target_group" {
  name        = "ec2-redmine"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance" # Ensure this is set to 'instance'
  vpc_id      = aws_vpc.redmine_vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

# ALB Listener Rule
resource "aws_lb_listener_rule" "alb_listener_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_redmine_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}


# Attach EC2 instance to Target Group
resource "aws_lb_target_group_attachment" "tg_ec2_attachment" {
  target_group_arn = aws_lb_target_group.ec2_redmine_target_group.arn
  target_id        = aws_instance.redmine_server.id
  port             = 80
}







#Store Parameters in SSM Parameter Store
resource "aws_ssm_parameter" "db_name" {
  name  = "/redmine/db/name"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/redmine/db/host"
  type  = "String"
  value = aws_rds_cluster.aurora_cluster.endpoint
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/redmine/db/user"
  type  = "String"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/redmine/db/password"
  type      = "SecureString"
  value     = var.db_password
  key_id = "alias/aws/ssm" 
}

resource "aws_ssm_parameter" "db_encoding" {
  name  = "/redmine/db/encoding"
  type  = "String"
  value = "utf8" # Assuming utf8 encoding, replace with random_string.db_encoding.result if needed
}


#Create an SNS Topic
resource "aws_sns_topic" "alarm_topic" {
  name = "redmine-cpu-ram-alarm-topic"
}
#Subscribe Your Email to the SNS Topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol  = "email"
  endpoint  = "wassimsuilah@gmail.com"
}

#Create CloudWatch Alarms for CPU and RAM Usage


#CPU Usage Alarm
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "high-cpu-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2" # Change to AWS/EC2 for EC2 instances, AWS/RDS for RDS instances, etc.
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ec2 cpu utilization"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]

  dimensions = {
    InstanceId = aws_instance.redmine_server.id 
  }
}

#RAM Usage Alarm
resource "aws_cloudwatch_metric_alarm" "ram_alarm" {
  alarm_name          = "high-ram-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent" # Ensure this matches the metric sent by your CloudWatch Agent
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors memory utilization"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]

  dimensions = {
    InstanceId = aws_instance.redmine_server.id 
  }
}

