include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/ecr"
}

inputs = {
  repository_name = "configmirror-operator"
  tags = {
    Name        = "ConfigMirror Operator ECR"
    Description = "Shared ECR repository for all environments"
    ManagedBy   = "terraform"
  }
}
