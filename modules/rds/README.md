# RDS Module

Creates a PostgreSQL RDS instance with Multi-AZ deployment.

## What it does

- PostgreSQL 17.6 RDS instance
- Multi-AZ deployment for high availability
- DB subnet group in private subnets
- Security group allowing access from VPC
- Automated backups with 7 day retention
- Encryption at rest
- Master password stored in AWS Secrets Manager

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| db_name | Database name | string | yes |
| db_username | Master username | string | yes |
| vpc_id | VPC ID | string | yes |
| vpc_cidr | VPC CIDR block for security group | string | yes |
| private_subnet_ids | List of private subnet IDs | list(string) | yes |
| project_name | Project name for resource naming | string | yes |
| environment | Environment name | string | yes |
| instance_class | RDS instance class | string | no (default: db.t3.micro) |
| allocated_storage | Storage in GB | number | no (default: 20) |
| multi_az | Enable Multi-AZ | bool | no (default: true) |

## Outputs

| Name | Description |
|------|-------------|
| db_instance_endpoint | RDS instance endpoint |
| db_instance_arn | RDS instance ARN |
| db_instance_id | RDS instance ID |
| db_name | Database name |
| db_secret_arn | Secrets Manager ARN for DB credentials |
| security_group_id | Security group ID for RDS |
