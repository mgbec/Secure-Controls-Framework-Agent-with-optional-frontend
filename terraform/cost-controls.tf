################################################################################
# Cost controls - AWS Budgets monthly alarm
#
# The agent's spend is dominated by pay-per-use Bedrock tokens and AgentCore
# runtime sessions, which are driven by whatever machine identities call the
# A2A ingress. This budget doesn't cap spend (AWS Budgets can't hard-stop
# Bedrock), but it turns an unexpected bill into an email the moment ACTUAL or
# FORECASTED spend crosses each threshold - the safety net that pairs with the
# per-route API Gateway throttle in a2a.tf.
################################################################################

locals {
  budget_enabled = var.enable_cost_budget
  # Prefer the dedicated budget email; fall back to the SCF-updater email.
  budget_email     = var.budget_notification_email != "" ? var.budget_notification_email : var.notification_email
  budget_has_email = local.budget_enabled && local.budget_email != ""
}

# --------------------------------------------------------------------------
# Dedicated SNS topic for budget alerts (kept separate from the SCF-updater
# topic so cost alerts and data-update notices don't get tangled).
# --------------------------------------------------------------------------
resource "aws_sns_topic" "budget_alerts" {
  count = local.budget_enabled ? 1 : 0

  name = "${local.name_prefix}-budget-alerts"

  tags = {
    Component = "cost-controls"
  }
}

# AWS Budgets must be allowed to publish to the topic.
resource "aws_sns_topic_policy" "budget_alerts" {
  count = local.budget_enabled ? 1 : 0

  arn = aws_sns_topic.budget_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBudgetsPublish"
        Effect    = "Allow"
        Principal = { Service = "budgets.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.budget_alerts[0].arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          ArnLike      = { "aws:SourceArn" = "arn:aws:budgets::${local.account_id}:budget/*" }
        }
      },
    ]
  })
}

resource "aws_sns_topic_subscription" "budget_email" {
  count = local.budget_has_email ? 1 : 0

  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "email"
  endpoint  = local.budget_email
}

# --------------------------------------------------------------------------
# The monthly cost budget. One notification per threshold, for both ACTUAL
# spend and FORECASTED spend, delivered to the SNS topic above.
# --------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly_cost" {
  count = local.budget_enabled ? 1 : 0

  name         = "${local.name_prefix}-monthly-cost"
  budget_type  = "COST"
  limit_amount = format("%.2f", var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = { for t in var.budget_alert_thresholds : "actual-${t}" => t }
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      notification_type         = "ACTUAL"
      subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts[0].arn]
    }
  }

  dynamic "notification" {
    for_each = { for t in var.budget_alert_thresholds : "forecasted-${t}" => t }
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      notification_type         = "FORECASTED"
      subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts[0].arn]
    }
  }
}
