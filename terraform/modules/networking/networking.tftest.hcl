mock_provider "aws" {}

run "creates_single_nat_and_s3_endpoint" {
  command = plan

  variables {
    name_prefix                = "test-dev"
    vpc_id                     = "vpc-0123456789abcdef0"
    internet_gateway_id        = "igw-0123456789abcdef0"
    availability_zones         = ["eu-west-1a", "eu-west-1b"]
    public_subnet_ids          = { "eu-west-1a" = "subnet-public-a", "eu-west-1b" = "subnet-public-b" }
    private_subnet_ids         = { "eu-west-1a" = "subnet-private-a", "eu-west-1b" = "subnet-private-b" }
    enable_nat_gateway         = true
    single_nat_gateway         = true
    enable_s3_gateway_endpoint = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Development networking must create only one NAT gateway in single-NAT mode."
  }

  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "Private route tables must exist in both availability zones."
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 1
    error_message = "The S3 gateway endpoint must be created when enabled."
  }
}

run "creates_multi_az_nat" {
  command = plan

  variables {
    name_prefix                = "test-prod"
    vpc_id                     = "vpc-0123456789abcdef0"
    internet_gateway_id        = "igw-0123456789abcdef0"
    availability_zones         = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    public_subnet_ids          = { "eu-west-1a" = "subnet-public-a", "eu-west-1b" = "subnet-public-b", "eu-west-1c" = "subnet-public-c" }
    private_subnet_ids         = { "eu-west-1a" = "subnet-private-a", "eu-west-1b" = "subnet-private-b", "eu-west-1c" = "subnet-private-c" }
    enable_nat_gateway         = true
    single_nat_gateway         = false
    enable_s3_gateway_endpoint = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "Production networking must create a NAT gateway in each availability zone."
  }

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "The public route table must have a default route to the internet gateway."
  }
}
