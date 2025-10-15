include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/github-oidc"
}

dependency "ecr" {
  config_path = "../../../_global/ecr"

  mock_outputs = {
    repository_arn = "arn:aws:ecr:us-east-1:123456789012:repository/mock-repo"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  github_org         = "sarataha"
  github_repo        = "configmirror-operator"
  ecr_repository_arn = dependency.ecr.outputs.repository_arn
}
