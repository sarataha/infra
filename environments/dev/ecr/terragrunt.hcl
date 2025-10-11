include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

dependencies {
  paths = ["../iam"]
}

inputs = {
  repository_name = get_env("TG_ECR_REPOSITORY_NAME", "configmirror-operator")
}
