terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.cluster_name

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

module "iam" {
  source = "../../modules/iam"

  cluster_name = var.cluster_name

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.ecr_repository_name

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

module "rds" {
  source = "../../modules/rds"

  name                = var.project_name
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = var.vpc_cidr
  private_subnet_ids  = module.vpc.private_subnet_ids
  database_name       = var.db_name
  master_username     = "postgres"
  skip_final_snapshot = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
