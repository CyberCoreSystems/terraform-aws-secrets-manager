terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "secret" {
  source = "../../"

  name        = "iacbazaar-example/app/db-credentials"
  description = "Database credentials for the example app"

  # Disposable example: delete immediately on destroy so this can be re-applied
  # right away. The MODULE DEFAULT is recovery_window_in_days = 30, which is the
  # right production setting but reserves the secret NAME for 30 days after a
  # destroy — a fixed-name re-apply within that window fails with "secret
  # scheduled for deletion". For real workloads keep the 30-day window (omit
  # this line) and use name_prefix if you redeploy under churn.
  recovery_window_in_days = 0

  # Secure default: no value is seeded here. Set one out of band, or pass
  # secret_string_wo (Terraform 1.11+) to keep the value out of state.
  create_initial_version = false

  # Cross-account read access for a partner role (optional).
  reader_principal_arns = ["arn:aws:iam::123456789012:role/example-reader"]

  tags = {
    Environment = "example"
    ManagedBy   = "iac-bazaar"
  }
}

output "secret_arn" {
  value = module.secret.secret_arn
}

output "secret_name" {
  value = module.secret.secret_name
}
