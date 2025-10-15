variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "policy_statements" {
  description = "List of IAM policy statements to attach to the role"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
