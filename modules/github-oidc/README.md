# GitHub OIDC Module

Generic module for creating GitHub Actions IAM roles with OIDC authentication.

## What it does

- References existing GitHub OIDC provider (created by bootstrap script)
- Creates IAM role with trust policy for specific GitHub repo
- Attaches custom IAM policy based on provided statements
- Reusable for any GitHub Actions workflow (ECR push, Terraform, etc.)

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| role_name | Name of the IAM role to create | string | yes |
| github_org | GitHub organization or username | string | yes |
| github_repo | GitHub repository name | string | yes |
| policy_statements | List of IAM policy statements | list(object) | yes |
| tags | Tags to apply to resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| oidc_provider_arn | GitHub OIDC provider ARN |
| role_arn | IAM role ARN for GitHub Actions |
| role_name | IAM role name for GitHub Actions |
