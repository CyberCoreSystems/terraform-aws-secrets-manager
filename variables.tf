variable "name" {
  description = "Name of the secret. Mutually exclusive with name_prefix."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-zA-Z0-9/_+=.@-]{1,512}$", coalesce(var.name, "x")))
    error_message = "name must be 1-512 characters of [a-zA-Z0-9/_+=.@-]."
  }
}

variable "name_prefix" {
  description = "Creates a unique name beginning with this prefix. Mutually exclusive with name."
  type        = string
  default     = null
}

variable "description" {
  description = "Description of the secret."
  type        = string
  default     = "Managed by IaC Bazaar aws-secrets-manager module."
}

# ---------------------------------------------------------------------------
# Encryption
# ---------------------------------------------------------------------------

variable "kms_key_id" {
  description = "Customer-managed KMS key (id or ARN) used to encrypt the secret. Null uses the AWS-managed aws/secretsmanager key (still encrypted). A CMK is recommended for cross-account/replica access control."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Lifecycle / deletion
# ---------------------------------------------------------------------------

variable "recovery_window_in_days" {
  description = "Recovery window after deletion (0, or 7-30 days). Defaults to the maximum (30) so a deleted secret can be restored. Set to 0 ONLY for disposable test secrets that must destroy immediately (irrecoverable)."
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 (immediate, irrecoverable) or between 7 and 30."
  }
}

variable "force_overwrite_replica_secret" {
  description = "Overwrite a secret with the same name in a replica region. Leave false unless you intend to clobber an existing replica."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Initial secret value
#
# Most secure default: create NO initial version (manage the value out of band
# via the rotation Lambda, the CLI, or a write-only apply). When you do seed a
# value, prefer the write-only path (secret_string_wo, Terraform 1.11+) so the
# value never lands in state; secret_string is the state-stored fallback for
# Terraform 1.6-1.10.
# ---------------------------------------------------------------------------

variable "secret_string" {
  description = "Initial secret value stored in Terraform state (sensitive). Leave null to create no initial version, or prefer secret_string_wo on Terraform 1.11+ to keep the value out of state."
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_string_wo" {
  description = "Initial secret value supplied as a write-only argument (Terraform 1.11+): never persisted to state. Requires secret_string_wo_version to be set/incremented to apply changes."
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_string_wo_version" {
  description = "Version trigger for secret_string_wo. Increment to push a new write-only value."
  type        = number
  default     = null
}

variable "create_initial_version" {
  description = "Whether to create an initial secret version from secret_string / secret_string_wo. Disable to let an external process (rotation Lambda, CLI) own the value."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Resource policy
# ---------------------------------------------------------------------------

variable "create_resource_policy" {
  description = "Attach the module's resource policy (TLS-only deny + optional cross-account read). Disable if you manage aws_secretsmanager_secret_policy yourself."
  type        = bool
  default     = true
}

variable "policy" {
  description = "Full JSON resource policy to attach verbatim, overriding the generated one. Leave null to use the built-in policy."
  type        = string
  default     = null
}

variable "block_public_policy" {
  description = "Reject a resource policy that grants broad public access. Kept true so a misconfigured policy cannot make the secret world-readable."
  type        = bool
  default     = true
}

variable "reader_principal_arns" {
  description = "IAM principal ARNs (typically cross-account roles) allowed to read the secret value via the resource policy. Empty = no cross-account access."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Cross-region replication
# ---------------------------------------------------------------------------

variable "replica_regions" {
  description = "Map of replica region -> optional CMK id/ARN in that region. Null value uses the AWS-managed key in the replica region. Keeps a copy of the secret in other regions for DR/low-latency reads."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Rotation
# ---------------------------------------------------------------------------

variable "enable_rotation" {
  description = "Enable automatic rotation via a Lambda. Requires rotation_lambda_arn and a rotation schedule."
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN of the Lambda that performs rotation. Required when enable_rotation = true."
  type        = string
  default     = null
}

variable "rotation_automatically_after_days" {
  description = "Rotate every N days. Mutually exclusive with rotation_schedule_expression; one of the two is required when rotation is enabled."
  type        = number
  default     = null

  validation {
    condition     = var.rotation_automatically_after_days == null ? true : (var.rotation_automatically_after_days >= 1 && var.rotation_automatically_after_days <= 1000)
    error_message = "rotation_automatically_after_days must be between 1 and 1000."
  }
}

variable "rotation_schedule_expression" {
  description = "cron() or rate() schedule for rotation. Mutually exclusive with rotation_automatically_after_days."
  type        = string
  default     = null
}

variable "rotation_duration" {
  description = "Length of the rotation window, e.g. \"3h\" (1h-24h). Null leaves the AWS default."
  type        = string
  default     = null
}

variable "rotate_immediately" {
  description = "Rotate once immediately when rotation is configured. Disable to wait for the first scheduled window."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the secret."
  type        = map(string)
  default     = {}
}
