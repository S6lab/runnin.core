# Monitoria mínima viável (12/06): uptime nos /healthz + alerta de taxa de
# erros nos logs. Antes disto não existia NENHUM alerta — queda de serviço
# ou explosão de erros só era percebida abrindo o app/console.

variable "alert_email" {
  description = "E-mail que recebe os alertas (notification channel)."
  type        = string
  default     = "eduardokaizer@gmail.com"
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Eduardo (email)"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

# ── Uptime checks nos /healthz (prod) ────────────────────────────────────

locals {
  uptime_targets = {
    runnin-api = replace(var.api_prod_url, "https://", "")
    s6-ai      = "runnin-s6-ai-rogiz7losq-rj.a.run.app"
  }
}

resource "google_monitoring_uptime_check_config" "healthz" {
  for_each     = local.uptime_targets
  display_name = "healthz ${each.key}"
  timeout      = "10s"
  period       = "300s" # 5min — free tier amigável

  http_check {
    path         = "/healthz"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value
    }
  }
}

resource "google_monitoring_alert_policy" "uptime" {
  for_each     = google_monitoring_uptime_check_config.healthz
  display_name = "DOWN: ${each.key}"
  combiner     = "OR"

  conditions {
    display_name = "healthz ${each.key} falhando"
    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${each.value.uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "600s" # 2 ciclos falhando antes de acordar alguém
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.host"]
      }
      trigger { count = 1 }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  severity              = "CRITICAL"
}

# ── Taxa de erros nos logs dos serviços Cloud Run ────────────────────────
# logger.error (winston) sai com severity ERROR no Cloud Logging via
# jsonPayload.level. Métrica de log + alerta quando passar do limiar.

resource "google_logging_metric" "service_errors" {
  name   = "service-error-count"
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name=("runnin-api" OR "runnin-api-staging" OR "runnin-s6-ai" OR "runnin-s6-ai-staging")
    (severity>=ERROR OR jsonPayload.level="error")
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "service"
      value_type  = "STRING"
      description = "Cloud Run service name"
    }
  }
  label_extractors = {
    service = "EXTRACT(resource.labels.service_name)"
  }
}

resource "google_monitoring_alert_policy" "error_rate" {
  display_name = "Taxa de erros alta (logs)"
  combiner     = "OR"

  conditions {
    display_name = ">10 erros em 5min num serviço"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"logging.googleapis.com/user/${google_logging_metric.service_errors.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["metric.label.service"]
      }
      trigger { count = 1 }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  severity              = "WARNING"
}
