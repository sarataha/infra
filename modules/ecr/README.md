# ECR Module

Creates an ECR repository for container images.

## What it does

- Creates private ECR repository
- Configures image scanning on push
- Sets up lifecycle policy to manage image retention
- Enables encryption

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| repository_name | Name of ECR repository | string | yes |
| environment | Environment name for lifecycle policy | string | yes |
| image_tag_mutability | Image tag mutability setting | string | no (default: MUTABLE) |
| scan_on_push | Enable image scanning on push | bool | no (default: true) |
| max_image_count | Max images to keep in lifecycle policy | number | no (default: 10) |

## Outputs

| Name | Description |
|------|-------------|
| repository_url | ECR repository URL |
| repository_arn | ECR repository ARN |
| repository_name | ECR repository name |
