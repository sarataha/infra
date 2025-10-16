locals {
  parsed_path   = path_relative_to_include()
  path_parts    = split("/", local.parsed_path)
  environment   = length(local.path_parts) > 0 ? local.path_parts[0] : "dev"

  project_name = "pawapay"
  aws_region   = "us-east-1"

  state_bucket_name      = "${local.project_name}-terraform-state-${get_aws_account_id()}"
  state_lock_table_name  = "${local.project_name}-terraform-locks"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project_name}"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = local.state_bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = local.state_lock_table_name

    s3_bucket_tags = {
      Name        = "Terraform State Bucket"
      Environment = local.environment
      Project     = local.project_name
      ManagedBy   = "terragrunt"
    }

    dynamodb_table_tags = {
      Name        = "Terraform Lock Table"
      Environment = local.environment
      Project     = local.project_name
      ManagedBy   = "terragrunt"
    }
  }
}

inputs = {
  aws_region   = local.aws_region
  project_name = local.project_name
  environment  = local.environment
  tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "terragrunt"
  }
}
