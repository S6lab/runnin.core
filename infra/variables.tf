variable "project_id" {
  description = "GCP project id (runnin-494520 pra ambos ambientes — staging e prod compartilham o mesmo projeto, separados por Cloud Run service)."
  type        = string
  default     = "runnin-494520"
}

variable "region" {
  description = "Região default. Schedulers ficam em southamerica-east1 pra estar perto do Cloud Run."
  type        = string
  default     = "southamerica-east1"
}

variable "time_zone" {
  description = "Timezone das schedules. Brasil pra alinhar com horário de envio de notificação ao user."
  type        = string
  default     = "America/Sao_Paulo"
}

variable "api_staging_url" {
  description = "Base URL do Cloud Run de staging."
  type        = string
  default     = "https://runnin-api-staging-rogiz7losq-rj.a.run.app"
}

variable "api_prod_url" {
  description = "Base URL do Cloud Run de prod."
  type        = string
  default     = "https://runnin-api-rogiz7losq-rj.a.run.app"
}

variable "cron_token_staging" {
  description = "Token do header X-Cron-Token aceito pelo server de staging (cronTokenMiddleware). Carregado de terraform.tfvars (gitignored)."
  type        = string
  sensitive   = true
}

variable "cron_token_prod" {
  description = "Token do header X-Cron-Token aceito pelo server de prod (cronTokenMiddleware). Carregado de terraform.tfvars (gitignored)."
  type        = string
  sensitive   = true
}
