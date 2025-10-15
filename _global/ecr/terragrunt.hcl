include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/ecr"
}

inputs = {
  repository_name = "configmirror-operator"
  environment     = "global"
  project         = "configmirror"
  tags = {
    Name        = "ConfigMirror Operator ECR"
    Description = "Shared ECR repository for all environments"
  }
}
