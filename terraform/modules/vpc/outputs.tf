output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Primary IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the VPC internet gateway."
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.public :
    availability_zone => subnet.id
  }
}

output "private_subnet_ids" {
  description = "Private subnet IDs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.private :
    availability_zone => subnet.id
  }
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDRs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.public :
    availability_zone => subnet.cidr_block
  }
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDRs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.private :
    availability_zone => subnet.cidr_block
  }
}

output "database_subnet_ids" {
  description = "Dedicated database subnet IDs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.database :
    availability_zone => subnet.id
  }
}

output "database_subnet_cidrs" {
  description = "Dedicated database subnet CIDRs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.database :
    availability_zone => subnet.cidr_block
  }
}
