include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  name                 = get_env("TG_PROJECT_NAME", "pawapay")
  environment          = "dev"
  project              = "pawapay"
  vpc_cidr             = get_env("TG_VPC_CIDR", "10.0.0.0/16")
  availability_zones   = jsondecode(get_env("TG_AVAILABILITY_ZONES", "[\"us-east-1a\",\"us-east-1b\"]"))
  public_subnet_cidrs  = jsondecode(get_env("TG_PUBLIC_SUBNET_CIDRS", "[\"10.0.1.0/24\",\"10.0.2.0/24\"]"))
  private_subnet_cidrs = jsondecode(get_env("TG_PRIVATE_SUBNET_CIDRS", "[\"10.0.10.0/24\",\"10.0.20.0/24\"]"))
  cluster_name         = get_env("TG_CLUSTER_NAME", "pawapay-eks-dev")
}
