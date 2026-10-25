################################################################################
# Variables
################################################################################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "scf-agent"
}

variable "bedrock_model_id" {
  description = "Bedrock foundation model ID (inference profile) for agent reasoning. Use a cross-region inference profile ID; the older on-demand 'anthropic.claude-sonnet-4-20250514-v1:0' is flagged Legacy and fails with an on-demand-throughput error."
  type        = string
  default     = "us.anthropic.claude-sonnet-4-6"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model for knowledge base"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR"
  }
}

variable "notification_email" {
  description = "Email address for SCF update notifications (leave empty to skip)"
  type        = string
  default     = ""
}

################################################################################
# A2A (Agent-to-Agent) ingress
################################################################################

variable "enable_a2a" {
  description = "Provision the API Gateway HTTP API + bridge Lambda that accept incoming A2A connections"
  type        = bool
  default     = true
}

variable "agent_public_name" {
  description = "Human-readable agent name published in the A2A Agent Card"
  type        = string
  default     = "SCF Compliance Assessment Agent"
}

variable "cognito_a2a_domain_prefix" {
  description = "Globally-unique prefix for the Cognito hosted-UI domain (<prefix>.auth.<region>.amazoncognito.com)"
  type        = string
  default     = "scf-agent-a2a"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,63}$", var.cognito_a2a_domain_prefix))
    error_message = "cognito_a2a_domain_prefix must be 3-63 chars of lowercase letters, digits, or hyphens."
  }
}

variable "cognito_a2a_web_callback_urls" {
  description = "Allowed callback/logout URLs for the interactive (authorization_code) Cognito app client. The default covers the local Streamlit frontend: Streamlit's OIDC redirect path is fixed at /oauth2callback (login), and st.logout returns to the app root."
  type        = list(string)
  default     = ["http://localhost:8501/oauth2callback", "http://localhost:8501/"]
}

variable "entra_tenant_id" {
  description = "Microsoft Entra ID tenant (directory) ID. Leave empty to skip the Entra-authorized route."
  type        = string
  default     = ""
}

variable "entra_audience" {
  description = "Expected `aud` for Entra tokens - the App ID URI or client ID of this API's Entra app registration"
  type        = string
  default     = ""
}

variable "entra_issuer_override" {
  description = "Override the Entra issuer (e.g. https://sts.windows.net/<tid>/ for v1.0 tokens). Empty = v2.0 issuer."
  type        = string
  default     = ""
}

variable "a2a_custom_domain" {
  description = "Optional custom domain for the A2A API (e.g. a2a.example.com). Empty = use the generated execute-api URL. Only affects URLs published in the Agent Card; the domain/cert/mapping are managed outside this config."
  type        = string
  default     = ""
}

variable "a2a_worker_timeout" {
  description = "Max seconds the async A2A worker Lambda may run one agent turn (Lambda hard max 900)."
  type        = number
  default     = 600

  validation {
    condition     = var.a2a_worker_timeout >= 30 && var.a2a_worker_timeout <= 900
    error_message = "a2a_worker_timeout must be between 30 and 900."
  }
}

variable "a2a_worker_max_concurrency" {
  description = "Max concurrent async A2A worker invocations (SQS event-source scaling cap; minimum 2). Caps concurrent InvokeAgentRuntime / Bedrock calls without touching the account's reserved-concurrency pool."
  type        = number
  default     = 5
}

################################################################################
# Streamlit frontend (ECS Fargate + ALB + CloudFront)
#
# Default is OFF: the hosted human UI is disabled to remove standing cost in the
# agents-only deployment. Set enable_frontend = true (and run the two-phase apply
# in frontend.tf) to restore the Streamlit UI. frontend.tf is fully count-gated,
# so leaving it in the config costs nothing while disabled.
################################################################################

variable "enable_frontend" {
  description = "Host the Streamlit frontend on ECS Fargate behind an ALB with CloudFront in front (requires enable_a2a for the Cognito user pool). Defaults to false for the agents-only deployment."
  type        = bool
  default     = false
}

variable "frontend_base_url" {
  description = "Public https base URL of the frontend (the CloudFront domain, no trailing slash, e.g. https://abc123.cloudfront.net). Leave empty for the first apply, then set it to the frontend_url output and apply again so the Cognito callback and the container's AUTH_REDIRECT_URI match the real URL."
  type        = string
  default     = ""
}

################################################################################
# Cost & abuse controls (agents-only ingress)
#
# Non-human callers don't self-limit the way a person clicking a UI does: a
# buggy or compromised machine credential can drive requests - and therefore
# billable Bedrock tokens - far faster than any human. These knobs put a
# predictable ceiling on request rate and turn "surprise bill" into an alert.
################################################################################

variable "a2a_throttle_rate_limit" {
  description = "Steady-state request/second cap applied per A2A RPC route on the API Gateway stage. Bounds how fast any single caller (or all callers) can drive billable agent invocations."
  type        = number
  default     = 5

  validation {
    condition     = var.a2a_throttle_rate_limit > 0
    error_message = "a2a_throttle_rate_limit must be greater than 0."
  }
}

variable "a2a_throttle_burst_limit" {
  description = "Maximum burst (token-bucket depth) allowed per A2A RPC route before requests are throttled with HTTP 429."
  type        = number
  default     = 10

  validation {
    condition     = var.a2a_throttle_burst_limit > 0
    error_message = "a2a_throttle_burst_limit must be greater than 0."
  }
}

variable "enable_cost_budget" {
  description = "Create an AWS Budgets monthly cost budget that emails notifications when spend crosses the configured thresholds."
  type        = bool
  default     = true
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD. Notifications fire at each percentage in budget_alert_thresholds (actual and forecasted)."
  type        = number
  default     = 100

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be greater than 0."
  }
}

variable "budget_alert_thresholds" {
  description = "Percent-of-budget thresholds that trigger a notification (e.g. 50, 80, 100). Each fires on both ACTUAL and FORECASTED spend."
  type        = list(number)
  default     = [50, 80, 100]
}

variable "budget_notification_email" {
  description = "Email address for budget alerts. Leave empty to reuse notification_email; if both are empty, the budget is created without an email subscriber."
  type        = string
  default     = ""
}
