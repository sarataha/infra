include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks-addons"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock-endpoint"
    cluster_certificate_authority_data = "bW9jaw==" # base64 "mock"
    external_secrets_role_arn          = "arn:aws:iam::123456789012:role/mock-role"
    kubectl_access_role_arns           = { admin = "arn:aws:iam::123456789012:role/mock-admin" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name               = dependency.eks.outputs.cluster_name
  cluster_endpoint           = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate     = dependency.eks.outputs.cluster_certificate_authority_data
  external_secrets_role_arn  = dependency.eks.outputs.external_secrets_role_arn
  kubectl_admin_role_arn     = dependency.eks.outputs.kubectl_access_role_arns["admin"]

  enable_external_secrets = true

  environment = "dev"
  project     = "pawapay"
}
