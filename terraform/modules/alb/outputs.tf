output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "alb_hosted_zone_id" {
  description = "Route 53 hosted-zone ID of the Application Load Balancer."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the ECS-compatible IP target group."
  value       = aws_lb_target_group.this.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, or null when disabled."
  value       = var.https_listener_enabled ? aws_lb_listener.https[0].arn : null
}

output "http_listener_arn" {
  description = "ARN of the HTTP redirect listener, or null when disabled."
  value       = var.enable_http_listener ? aws_lb_listener.http[0].arn : null
}
