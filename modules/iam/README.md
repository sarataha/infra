# IAM Module

Creates IAM roles for EKS cluster and node groups.

## What it does

- EKS cluster IAM role with required policies
- EKS node group IAM role with required policies
- Trust policies for EKS service

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project_name | Project name for resource naming | string | yes |
| environment | Environment name | string | yes |

## Outputs

| Name | Description |
|------|-------------|
| eks_cluster_role_arn | ARN of EKS cluster IAM role |
| eks_cluster_role_name | Name of EKS cluster IAM role |
| eks_node_role_arn | ARN of EKS node group IAM role |
| eks_node_role_name | Name of EKS node group IAM role |
