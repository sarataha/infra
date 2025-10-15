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
  role_name   = "github-actions-ecr-push"
  github_org  = get_env("TG_GITHUB_ORG", "sarataha")
  github_repo = get_env("TG_GITHUB_REPO", "configmirror-operator")

  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    },
    {
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ]
      resources = [dependency.ecr.outputs.repository_arn]
    }
  ]
}
