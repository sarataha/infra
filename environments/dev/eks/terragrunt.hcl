include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id              = "vpc-mock-id"
    vpc_cidr            = "10.0.0.0/16"
    public_subnet_ids   = ["subnet-mock-pub-1", "subnet-mock-pub-2"]
    private_subnet_ids  = ["subnet-mock-priv-1", "subnet-mock-priv-2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "iam" {
  config_path = "../iam"

  mock_outputs = {
    eks_cluster_role_arn = "arn:aws:iam::123456789012:role/mock-cluster-role"
    eks_node_role_arn    = "arn:aws:iam::123456789012:role/mock-node-role"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name       = get_env("TG_CLUSTER_NAME", "pawapay-eks-dev")
  cluster_role_arn   = dependency.iam.outputs.eks_cluster_role_arn
  node_role_arn      = dependency.iam.outputs.eks_node_role_arn
  vpc_id             = dependency.vpc.outputs.vpc_id
  vpc_cidr           = dependency.vpc.outputs.vpc_cidr

  # PRODUCTION BEST PRACTICE: Control plane in private subnets only
  # Using private subnets ensures the EKS control plane is not directly exposed
  public_subnet_ids  = dependency.vpc.outputs.private_subnet_ids
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  kubernetes_version   = get_env("TG_KUBERNETES_VERSION", "1.34")
  enable_public_access = true
  public_access_cidrs  = jsondecode(get_env("TG_PUBLIC_ACCESS_CIDRS", "[\"0.0.0.0/0\"]"))

  desired_size       = tonumber(get_env("TG_DESIRED_NODE_COUNT", "2"))
  max_size           = tonumber(get_env("TG_MAX_NODE_COUNT", "4"))
  min_size           = tonumber(get_env("TG_MIN_NODE_COUNT", "1"))
  instance_types     = jsondecode(get_env("TG_NODE_INSTANCE_TYPES", "[\"t3.small\"]"))

  # kubectl access entries
  access_entries = {
    admin = {
      iam_role_name = "pawapay-eks-dev-admin"
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
      tags = {
        Description = "EKS cluster admin role for full kubectl access"
      }
    }

    user = {
      iam_role_name = "pawapay-eks-dev-user"
      policy_associations = {
        default_edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["default"]
          }
        }
        kube_system_view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["kube-system"]
          }
        }
      }
      tags = {
        Description = "EKS developer role with edit access to default and view access to kube-system"
      }
    }
  }
}
