output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs keyed by availability zone."
  value = {
    for availability_zone, route_table in aws_route_table.private :
    availability_zone => route_table.id
  }
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by availability zone."
  value = {
    for availability_zone, nat_gateway in aws_nat_gateway.this :
    availability_zone => nat_gateway.id
  }
}

output "nat_gateway_public_ips" {
  description = "Elastic IP addresses assigned to NAT gateways."
  value = {
    for availability_zone, nat_gateway in aws_nat_gateway.this :
    availability_zone => aws_eip.nat[availability_zone].public_ip
  }
}

output "s3_vpc_endpoint_id" {
  description = "ID of the optional S3 gateway endpoint."
  value       = var.enable_s3_gateway_endpoint ? aws_vpc_endpoint.s3[0].id : null
}
