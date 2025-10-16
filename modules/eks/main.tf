# AWS EKS Best Practices: https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  depends_on = [
    aws_cloudwatch_log_group.eks
  ]

  tags = merge(local.common_tags, var.tags)
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  version         = var.kubernetes_version
  ami_type        = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  disk_size      = var.disk_size

  labels = {
    Environment = var.environment
    NodeGroup   = "main"
  }

  tags = merge(
    local.common_tags,
    var.tags,
    {
      Name = "${var.cluster_name}-node-group"
    }
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_eks_cluster.main
  ]
}

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name} secrets encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    var.tags,
    {
      Name = "${var.cluster_name}-eks-key"
    }
  )
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.eks.arn

  tags = merge(local.common_tags, var.tags)
}

resource "aws_security_group" "cluster_additional" {
  name_prefix = "${var.cluster_name}-additional-"
  description = "Additional security group for EKS cluster ${var.cluster_name}"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    var.tags,
    {
      Name = "${var.cluster_name}-additional-sg"
    }
  )
}

resource "aws_security_group_rule" "cluster_additional_ingress" {
  description       = "Allow pods to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster_additional.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "cluster_additional_egress" {
  description       = "Allow cluster egress access to the Internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster_additional.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, var.tags)
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, var.tags)
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, var.tags)

  depends_on = [
    aws_eks_node_group.main
  ]
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, var.tags)
}

################################################################################
# EKS Access Entries for kubectl access
################################################################################

locals {
  # Flatten policy associations per entry
  flattened_access_entries = flatten([
    for entry_key, entry in var.access_entries : [
      for pol_key, pol in entry.policy_associations : {
        entry_key    = entry_key
        pol_key      = pol_key
        policy_arn   = pol.policy_arn
        access_scope = pol.access_scope
      }
    ]
  ])
}

# IAM roles for kubectl access
resource "aws_iam_role" "kubectl_access" {
  for_each = var.access_entries

  name = each.value.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    var.tags,
    lookup(each.value, "tags", {})
  )
}

# IAM policy for EKS API access
resource "aws_iam_role_policy" "kubectl_eks_access" {
  for_each = var.access_entries

  name = "${each.value.iam_role_name}-eks-access"
  role = aws_iam_role.kubectl_access[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}

# EKS access entries
resource "aws_eks_access_entry" "kubectl" {
  for_each = var.access_entries

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.kubectl_access[each.key].arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]
}

# EKS access policy associations
resource "aws_eks_access_policy_association" "kubectl" {
  for_each = { for v in local.flattened_access_entries : "${v.entry_key}_${v.pol_key}" => v }

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.kubectl_access[each.value.entry_key].arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = lookup(each.value.access_scope, "namespaces", null)
  }

  depends_on = [aws_eks_access_entry.kubectl]
}

################################################################################
# External Secrets Operator
################################################################################

# IAM Role for External Secrets Operator (IRSA)
resource "aws_iam_role" "external_secrets" {
  name = "${var.cluster_name}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

# IAM Policy for External Secrets Operator to access Secrets Manager
resource "aws_iam_role_policy" "external_secrets" {
  name = "${var.cluster_name}-external-secrets-policy"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

