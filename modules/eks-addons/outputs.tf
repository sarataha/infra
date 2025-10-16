output "external_secrets_release_name" {
  description = "External Secrets Operator Helm release name"
  value       = var.enable_external_secrets ? helm_release.external_secrets[0].name : null
}

output "external_secrets_namespace" {
  description = "External Secrets Operator namespace"
  value       = var.enable_external_secrets ? helm_release.external_secrets[0].namespace : null
}
