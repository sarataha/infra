# VPC Module

Creates a multi-AZ VPC with public and private subnets.

## What it does

- Creates VPC with configurable CIDR
- Public subnets in 2 availability zones
- Private subnets in 2 availability zones
- Internet gateway for public subnets
- NAT gateways in each AZ for private subnet internet access
- Route tables for public and private subnets

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| vpc_cidr | CIDR block for VPC | string | yes |
| availability_zones | List of AZs to use | list(string) | yes |
| public_subnet_cidrs | CIDR blocks for public subnets | list(string) | yes |
| private_subnet_cidrs | CIDR blocks for private subnets | list(string) | yes |
| project_name | Project name for tagging | string | yes |
| environment | Environment name | string | yes |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| nat_gateway_ids | List of NAT gateway IDs |
| internet_gateway_id | Internet gateway ID |
#Updated
