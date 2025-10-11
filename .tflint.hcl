# TFLint Configuration
# https://github.com/terraform-linters/tflint

config {
  # Enable module inspection
  module = true

  # Force specific version
  force = false

  # Disabled by default rules
  disabled_by_default = false
}

# Enable AWS plugin
plugin "aws" {
  enabled = true
  version = "0.35.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enable Terraform plugin
plugin "terraform" {
  enabled = true
  version = "0.11.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# AWS-specific rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "Project", "ManagedBy"]
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

# Terraform best practices
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}
