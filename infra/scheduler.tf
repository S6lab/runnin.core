# Cloud Scheduler jobs que disparam endpoints internos do server.
#
# Autenticação: cada job manda o header `X-Cron-Token` com o token do
# ambiente correspondente; o `cronTokenMiddleware` no server compara com
# o env CRON_TOKEN (carregado do Secret Manager no Cloud Run).
#
# Naming: mantive os nomes legados (`runnin-daily-push`,
# `weekly-plan-proposals`) pra evitar destroy+create durante o import
# inicial. Adoção futura de sufixo `-staging` em todos os jobs fica como
# TODO de cleanup (vide README).

locals {
  cron_header_staging = {
    "User-Agent"   = "Google-Cloud-Scheduler"
    "X-Cron-Token" = var.cron_token_staging
  }
  cron_header_prod = {
    "User-Agent"   = "Google-Cloud-Scheduler"
    "X-Cron-Token" = var.cron_token_prod
  }
}

# ─────────────────────────────────────────────────────────────────────
# DAILY: 08:00 BRT — garante 7 notificações in-app do dia + push motiv.
# Já gateado por tier (freemium não recebe — ensure-daily-insights checa
# feature `coachChat`). Diário porque os textos rotacionam por sessão
# planejada/dia da semana.
# ─────────────────────────────────────────────────────────────────────

resource "google_cloud_scheduler_job" "daily_push_staging" {
  name             = "runnin-daily-push"
  description      = "Daily 8am BRT: ensure in-app notifs + send motivational push for all onboarded users"
  region           = var.region
  schedule         = "0 8 * * *"
  time_zone        = var.time_zone
  attempt_deadline = "180s"

  retry_config {
    max_backoff_duration = "3600s"
    max_doublings        = 5
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
  }

  http_target {
    http_method = "POST"
    uri         = "${var.api_staging_url}/v1/notifications/ensure-daily"
    headers     = local.cron_header_staging
  }
}

resource "google_cloud_scheduler_job" "daily_push_prod" {
  name             = "runnin-daily-push-prod"
  description      = "Daily 8am BRT (PROD): ensure in-app notifs + send motivational push for all onboarded users"
  region           = var.region
  schedule         = "0 8 * * *"
  time_zone        = var.time_zone
  attempt_deadline = "180s"

  retry_config {
    max_backoff_duration = "3600s"
    max_doublings        = 5
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
  }

  http_target {
    http_method = "POST"
    uri         = "${var.api_prod_url}/v1/notifications/ensure-daily"
    headers     = local.cron_header_prod
  }
}

# ─────────────────────────────────────────────────────────────────────
# WEEKLY: domingo 23:00 BRT — fecha a semana do user com o checkpoint
# automático. Server enfileira por user via Cloud Tasks pra não estourar
# timeout do scheduler. Horário escolhido pra cobrir a semana INTEIRA
# (incluindo qualquer corrida feita no domingo) antes do ajuste rolar.
# ─────────────────────────────────────────────────────────────────────

resource "google_cloud_scheduler_job" "weekly_proposals_staging" {
  name             = "weekly-plan-proposals"
  description      = "Sunday 11pm BRT: run weekly checkpoint per active user (enqueues per-user tasks)"
  region           = var.region
  schedule         = "0 23 * * 0"
  time_zone        = var.time_zone
  attempt_deadline = "540s"

  retry_config {
    max_backoff_duration = "3600s"
    max_doublings        = 5
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
  }

  http_target {
    http_method = "POST"
    uri         = "${var.api_staging_url}/v1/admin/cron/weekly-proposals"
    headers     = local.cron_header_staging
  }
}

resource "google_cloud_scheduler_job" "weekly_proposals_prod" {
  name             = "weekly-plan-proposals-prod"
  description      = "Sunday 11pm BRT (PROD): run weekly checkpoint per active user (enqueues per-user tasks)"
  region           = var.region
  schedule         = "0 23 * * 0"
  time_zone        = var.time_zone
  attempt_deadline = "300s"

  retry_config {
    max_backoff_duration = "3600s"
    max_doublings        = 5
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
  }

  http_target {
    http_method = "POST"
    uri         = "${var.api_prod_url}/v1/admin/cron/weekly-proposals"
    headers     = local.cron_header_prod
  }
}
