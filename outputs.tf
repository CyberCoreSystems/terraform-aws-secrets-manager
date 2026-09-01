output "secret_arn" {
  description = "ARN of the secret."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_id" {
  description = "ID of the secret (same as the ARN)."
  value       = aws_secretsmanager_secret.this.id
}

output "secret_name" {
  description = "Final name of the secret (resolves name_prefix)."
  value       = aws_secretsmanager_secret.this.name
}

output "version_id" {
  description = "Version id of the initial secret version; null when no initial version was created."
  value       = try(aws_secretsmanager_secret_version.this[0].version_id, null)
}

output "replica_regions" {
  description = "Regions the secret is replicated to."
  value       = keys(var.replica_regions)
}

output "rotation_enabled" {
  description = "Whether Lambda-driven rotation is configured."
  value       = var.enable_rotation
}
