# Outputs
output "vpc_id" {
  value = aws_vpc.redmine_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}


output "nat_gateway_ip" {
  value = aws_nat_gateway.my_nat_gateway[0].allocation_id
}
# Aurora
output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}

output "aurora_cluster_reader_endpoint" {
  value = aws_rds_cluster.aurora_cluster.reader_endpoint
}

output "aurora_cluster_id" {
  value = aws_rds_cluster.aurora_cluster.id
}

# output "aurora_instance_endpoint" {
#   value = aws_rds_cluster_instance.aurora_redmine_db_instance.endpoint
# }

# alb
output "alb_dns_name" {
  value = aws_lb.alb_redmine.dns_name
}

output "alb_listener_rule_arn" {
  value = aws_lb_listener_rule.alb_listener_rule.id
}



