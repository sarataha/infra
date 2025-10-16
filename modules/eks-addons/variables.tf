variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster certificate authority data"
  type        = string
  sensitive   = true
}

variable "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  type        = string
}

variable "kubectl_admin_role_arn" {
  description = "IAM role ARN for kubectl admin access"
  type        = string
}

variable "enable_external_secrets" {
  description = "Enable External Secrets Operator"
  type        = bool
  default     = true
}
