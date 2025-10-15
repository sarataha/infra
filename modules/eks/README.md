# EKS Module

Creates an EKS cluster with managed node group and kubectl access configuration.

## What it does

- EKS cluster with specified Kubernetes version
- Managed node group with autoscaling
- Cluster security group
- CloudWatch log group for control plane logs
- KMS key for secrets encryption
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- EKS addons (VPC-CNI, CoreDNS, kube-proxy)
- IAM roles for kubectl access (admin and user)
- EKS access entries for API-based authentication

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| cluster_name | EKS cluster name | string | yes |
| cluster_role_arn | IAM role ARN for EKS cluster | string | yes |
| node_role_arn | IAM role ARN for node group | string | yes |
| vpc_id | VPC ID | string | yes |
| vpc_cidr | VPC CIDR block | string | yes |
| public_subnet_ids | List of subnet IDs for cluster (using private) | list(string) | yes |
| private_subnet_ids | List of private subnet IDs for nodes | list(string) | yes |
| kubernetes_version | Kubernetes version | string | yes |
| desired_size | Desired number of nodes | number | yes |
| max_size | Maximum number of nodes | number | yes |
| min_size | Minimum number of nodes | number | yes |
| instance_types | List of EC2 instance types | list(string) | yes |
| enable_public_access | Enable public API endpoint | bool | no (default: false) |
| public_access_cidrs | CIDRs allowed to access public endpoint | list(string) | no (default: ["0.0.0.0/0"]) |
| access_entries | Map of kubectl access configurations | map | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_name | EKS cluster name |
| cluster_arn | EKS cluster ARN |
| cluster_endpoint | EKS cluster endpoint |
| cluster_version | Kubernetes version |
| cluster_security_group_id | Cluster security group ID |
| cluster_certificate_authority_data | CA certificate (sensitive) |
| node_group_id | Node group ID |
| node_group_arn | Node group ARN |
| node_group_status | Node group status |
| kms_key_id | KMS key ID for encryption |
| kms_key_arn | KMS key ARN |
| cloudwatch_log_group_name | CloudWatch log group name |
| oidc_provider_arn | OIDC provider ARN |
| oidc_provider_url | OIDC provider URL |
| kubectl_access_role_arns | Map of kubectl access role ARNs |
| kubectl_access_role_names | Map of kubectl access role names |
