# Secrets Manager secret with CMK-capable encryption, a TLS-only resource
# policy, optional cross-region replication, an optional initial version, and
# Lambda rotation scaffolding. The secure default is to create NO initial
# version and let the value be set out of band; when a value is seeded the
# write-only path (secret_string_wo, Terraform 1.11+) keeps it out of state.

locals {
  use_generated_policy = var.policy == null

  # Did the caller actually supply a value to seed?
  has_value    = var.secret_string != null || var.secret_string_wo != null
  seed_version = var.create_initial_version && local.has_value
}

# ---------------------------------------------------------------------------
# Secret
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "this" {
  name        = var.name
  name_prefix = var.name_prefix
  description = var.description

  kms_key_id                     = var.kms_key_id
  recovery_window_in_days        = var.recovery_window_in_days
  force_overwrite_replica_secret = var.force_overwrite_replica_secret

  dynamic "replica" {
    for_each = var.replica_regions
    content {
      region     = replica.key
      kms_key_id = replica.value
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = (var.name == null) != (var.name_prefix == null)
      error_message = "Set exactly one of name or name_prefix."
    }
    precondition {
      condition     = var.secret_string == null || var.secret_string_wo == null
      error_message = "Set at most one of secret_string and secret_string_wo (prefer secret_string_wo on Terraform 1.11+)."
    }
    precondition {
      condition     = var.secret_string_wo == null || var.secret_string_wo_version != null
      error_message = "secret_string_wo requires secret_string_wo_version to be set."
    }
  }
}

# ---------------------------------------------------------------------------
# Initial version (optional)
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret_version" "this" {
  count = local.seed_version ? 1 : 0

  secret_id = aws_secretsmanager_secret.this.id

  # State-stored value (Terraform 1.6+) when secret_string is used.
  secret_string = var.secret_string

  # Write-only value (Terraform 1.11+) when secret_string_wo is used: never
  # persisted to state. Both are null when the other path is chosen.
  secret_string_wo         = var.secret_string_wo
  secret_string_wo_version = var.secret_string_wo_version
}

# ---------------------------------------------------------------------------
# Resource policy: deny non-TLS access; optionally allow named cross-account
# readers. block_public_policy guards against an accidental public grant.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "secret" {
  count = var.create_resource_policy && local.use_generated_policy ? 1 : 0

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["secretsmanager:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = length(var.reader_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowCrossAccountRead"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.reader_principal_arns
      }
    }
  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  count = var.create_resource_policy ? 1 : 0

  secret_arn          = aws_secretsmanager_secret.this.arn
  policy              = local.use_generated_policy ? data.aws_iam_policy_document.secret[0].json : var.policy
  block_public_policy = var.block_public_policy
}

# ---------------------------------------------------------------------------
# Rotation (optional Lambda-driven)
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.enable_rotation ? 1 : 0

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation_lambda_arn
  rotate_immediately  = var.rotate_immediately

  rotation_rules {
    automatically_after_days = var.rotation_automatically_after_days
    schedule_expression      = var.rotation_schedule_expression
    duration                 = var.rotation_duration
  }

  lifecycle {
    precondition {
      condition     = var.rotation_lambda_arn != null
      error_message = "enable_rotation requires rotation_lambda_arn."
    }
    precondition {
      condition     = (var.rotation_automatically_after_days != null) != (var.rotation_schedule_expression != null)
      error_message = "Set exactly one of rotation_automatically_after_days or rotation_schedule_expression when rotation is enabled."
    }
  }
}
