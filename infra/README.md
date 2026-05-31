# infra/

Infrastructure as Code (Terraform) pros recursos GCP do Runnin que vivem fora do código da app/server.

Hoje cobre:
- **Cloud Scheduler** (4 jobs: daily push staging+prod, weekly plan proposals staging+prod)

Pra adicionar depois (não cobertos ainda): Cloud Run services, Firestore indexes, Secret Manager secrets, Cloud Tasks queues.

## Pré-requisitos

```bash
brew install terraform        # ou versão >= 1.6
gcloud auth application-default login
gcloud config set project runnin-494520
```

Pra confirmar que está autenticado pelo provider:

```bash
gcloud auth application-default print-access-token >/dev/null && echo OK
```

## Setup inicial (primeira vez)

1. Copie o template de vars e preencha com os tokens reais:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # editar terraform.tfvars com os tokens (instruções no próprio arquivo)
   ```

2. Inicialize o Terraform:

   ```bash
   terraform init
   ```

3. Importe os jobs que já existem em prod (criados manualmente antes deste IaC):

   ```bash
   terraform import google_cloud_scheduler_job.daily_push_staging \
     projects/runnin-494520/locations/southamerica-east1/jobs/runnin-daily-push

   terraform import google_cloud_scheduler_job.weekly_proposals_staging \
     projects/runnin-494520/locations/southamerica-east1/jobs/weekly-plan-proposals

   terraform import google_cloud_scheduler_job.weekly_proposals_prod \
     projects/runnin-494520/locations/southamerica-east1/jobs/weekly-plan-proposals-prod
   ```

4. Rode `plan` pra ver o diff esperado:

   ```bash
   terraform plan
   ```

   O plan deve mostrar:
   - **1 novo** recurso: `daily_push_prod` (job que ainda não existe — vai ser criado)
   - **3 sem mudança**: os recursos importados acima

   Se aparecer diff em algum dos importados, ajustar o `.tf` pra refletir o que está em produção antes de fazer apply.

5. Aplique:

   ```bash
   terraform apply
   ```

## Operação contínua

Sempre que mudar uma schedule, URL, ou criar/remover job: edite `scheduler.tf`, rode `terraform plan` pra revisar, depois `terraform apply`.

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

## State

State local (`terraform.tfstate`) por padrão pra simplicidade na primeira iteração.

**Antes de mais de uma pessoa rodar apply, migrar pra GCS backend** (instruções comentadas em `main.tf`). State local não suporta acesso concorrente e some se o repo for clonado em outra máquina.

## TODO conhecidos

- [ ] Migrar state pra GCS (`gs://runnin-494520-tfstate`)
- [ ] Normalizar nomes (`runnin-daily-push` → `runnin-daily-push-staging`, `weekly-plan-proposals` → `weekly-plan-proposals-staging`). Mexer envolve destroy+create em janela de manutenção
- [ ] Mover `cron_token_*` pra Secret Manager (`google_secret_manager_secret_version` data source) em vez de tfvars local
- [ ] Adicionar dead-letter / alerting pra falhas de execução do Scheduler
