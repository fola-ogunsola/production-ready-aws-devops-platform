mock_provider "aws" {}

run "creates_two_az_vpc" {
  command = plan

  variables {
    name_prefix          = "test-dev"
    vpc_cidr             = "10.20.0.0/16"
    availability_zones   = ["eu-west-1a", "eu-west-1b"]
    public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
    private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.20.0.0/16"
    error_message = "The VPC CIDR must match the test input."
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "The VPC must create two public subnets."
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "The VPC must create two private subnets."
  }

  assert {
    condition     = aws_subnet.public["eu-west-1a"].map_public_ip_on_launch == false
    error_message = "Public subnets must not automatically assign public IPv4 addresses."
  }

  assert {
    condition     = aws_subnet.private["eu-west-1a"].map_public_ip_on_launch == false
    error_message = "Private subnets must not automatically assign public IPv4 addresses."
  }

  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "VPC flow logs must be enabled by default."
  }

}
