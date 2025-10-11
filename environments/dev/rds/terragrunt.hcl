include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id              = "vpc-mock-id"
    vpc_cidr            = "10.0.0.0/16"
    private_subnet_ids  = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name                = get_env("TG_PROJECT_NAME", "pawapay")
  vpc_id              = dependency.vpc.outputs.vpc_id
  vpc_cidr            = dependency.vpc.outputs.vpc_cidr
  private_subnet_ids  = dependency.vpc.outputs.private_subnet_ids
  database_name       = get_env("TG_DB_NAME", "configmirror")
  master_username     = "postgres"
  skip_final_snapshot = true
  multi_az            = true
}
