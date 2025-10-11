include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

dependencies {
  paths = ["../vpc"]
}

inputs = {
  cluster_name = get_env("TG_CLUSTER_NAME", "pawapay-eks-dev")
}
