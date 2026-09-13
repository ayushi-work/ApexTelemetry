output "alb_url" {
  description = "ApexTelemetry Application Load Balancer URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "ec2_a_id" {
  description = "EC2-A instance ID"
  value       = aws_instance.a.id
}

output "ec2_b_id" {
  description = "EC2-B instance ID"
  value       = aws_instance.b.id
}

output "ec2_a_public_ip" {
  description = "EC2-A public IP"
  value       = aws_instance.a.public_ip
}

output "ec2_b_public_ip" {
  description = "EC2-B public IP"
  value       = aws_instance.b.public_ip
}

output "ec2_a_availability_zone" {
  description = "EC2-A availability zone"
  value       = aws_instance.a.availability_zone
}

output "ec2_b_availability_zone" {
  description = "EC2-B availability zone"
  value       = aws_instance.b.availability_zone
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}