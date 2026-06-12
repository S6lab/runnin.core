# Budget do projeto com avisos em 50/80/100% — controle de custo de infra
# (Cloud Run + Firestore + Logging) sem construir tracking fino próprio.
# Custo LLM tem tracking dedicado no app_config/llm_usage (aba TECH).
#
# NOTA pro apply: precisa do billing account id e da API
# billingbudgets.googleapis.com habilitada + permissão billing.budgets.*
# na conta que roda o terraform. Valor default conservador — ajustar.

variable "billing_account_id" {
  description = "Billing account (formato XXXXXX-XXXXXX-XXXXXX). Em terraform.tfvars (gitignored)."
  type        = string
  default     = "" # vazio = budget não é criado (count abaixo)
}

variable "monthly_budget_brl" {
  description = "Teto mensal em BRL pros avisos (50/80/100%)."
  type        = number
  default     = 500
}

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_billing_budget" "monthly" {
  count           = var.billing_account_id == "" ? 0 : 1
  billing_account = var.billing_account_id
  display_name    = "runnin — teto mensal"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "BRL"
      units         = tostring(var.monthly_budget_brl)
    }
  }

  threshold_rules { threshold_percent = 0.5 }
  threshold_rules { threshold_percent = 0.8 }
  threshold_rules { threshold_percent = 1.0 }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
    disable_default_iam_recipients   = false
  }
}
