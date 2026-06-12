# Smoke Runbook — verificação agentica por build

> Processo formalizado a partir do smoke iterativo de 11-12/06 (que pegou 8
> bugs em uma noite). Executado pelo Claude (ou humano) a cada build/release
> candidate. Complementa — não substitui — o gate de device real (TF):
> Watch, FC, GPS de rua e áudio em condição real só existem lá.

## 0. Pré-condições e lições aprendidas

- **SEMPRE `cd` explícito no comando de build** e **conferir o mtime do
  binário** antes de instalar — duas builds stale foram instaladas em
  11/06 porque o cwd do shell flutua e `| tail` mascara exit≠0:
  ```bash
  cd /Users/eduardovasqueskaizer/Projects/runnin.core/app && \
    flutter build ios --simulator -d <SIM_ID> --dart-define=API_BASE_URL=<staging>
  stat -f "%Sm" build/ios/iphonesimulator/Runner.app/Frameworks/App.framework/App
  ```
- Simulador padrão: `iPhone-17-Runnin` (`xcrun simctl list devices | grep Runnin`).
- Staging API: `https://runnin-api-staging-rogiz7losq-rj.a.run.app`
- Staging s6-ai: `https://runnin-s6-ai-staging-rogiz7losq-rj.a.run.app`
- Staging e prod compartilham o MESMO Firestore — reset de conta afeta tudo.

## 1. Suítes estáticas (sempre, ~2min)

```bash
cd server && npx tsc --noEmit && npx vitest run
cd ../s6-ai && npx tsc --noEmit && npx vitest run
cd ../app && flutter analyze lib && flutter test
```

## 2. Smoke e2e do live coach (antes de QUALQUER deploy do s6-ai/server)

```bash
cd s6-ai
S6_INTERNAL_TOKEN=$(gcloud secrets versions access latest --secret=s6-internal-token --project=runnin-494520) \
X_CRON_TOKEN=$(gcloud secrets versions access latest --secret=cron-token --project=runnin-494520) \
SMOKE_EMAIL=smoke-bot@s6lab.ai SMOKE_PASSWORD=$(cat /tmp/smoke-bot-pw.txt) \
npm run smoke -- \
  --s6-url=https://runnin-s6-ai-staging-rogiz7losq-rj.a.run.app \
  --server-url=https://runnin-api-staging-rogiz7losq-rj.a.run.app
```
- `--scenario=assessment` pra validar a persona de medição.
- `--long` em release candidate (segura a sessão >5,5min — regressão do
  timeout de 300s do Cloud Run).
- **Passa quando**: exit 0; relatório com `responded: true` pra
  start/km_reached/goal_reached/finish; `transcript_contains_6:00` true
  (regra dos números exatos); `goal_reached.turns ≤ 2` (sem fala dupla).
- Usuário de smoke: criar/rodar `node ../s6-ai/scripts/create-smoke-user.cjs`
  a partir de `server/` (SA key local) se a senha rotacionar.

## 3. Integration tests no simulador

```bash
cd app && flutter test integration_test -d <SIM_ID>
```
Cobrem: jornada do wizard de plano (data derivada, admissibilidade) e
corrida free-run com `MockGpsService` até o report.

## 4. Smoke manual-agentico no sim (por release candidate)

```bash
xcrun simctl install <SIM_ID> app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch <SIM_ID> com.s6lab.runnin
xcrun simctl io <SIM_ID> screenshot /tmp/smoke_<tela>.png   # por tela
# GPS simulado pra corrida:
#   Simulator.app → Features → Location → Freeway Drive (ou City Run)
```

**Tabela de fluxos por release** (marcar cada um):

| # | Fluxo | O que validar |
|---|---|---|
| 1 | Login + onboarding | claims, campos persistem, redirect correto |
| 2 | Oferta de avaliação | última avaliação exibida (refazer/seguir) |
| 3 | Corrida de avaliação | saudação modo medição; goal_reached FALADO no alvo (1 vez); finish inteiro; badge; card de esforço no report |
| 4 | Wizard do plano | card USAR MINHA AVALIAÇÃO; pace estável ao trocar distância; StartDayNotice quando início fora dos dias; data derivada coerente |
| 5 | Geração | rationale com idade certa + capacidade MEDIDA citada |
| 6 | Sessão de plano c/ coach | saudação situada ("semana Y de X..."); cues por km |
| 7 | Report pós-run | pace sem "5:60"; elevação ↑/↓; feedback só em run normal |
| 8 | Revisão semanal | trigger manual via admin (`/admin/cron/weekly-proposals/trigger`) |

**Log-grep após cada fluxo** (erros + eventos esperados):
```bash
xcrun simctl spawn <SIM_ID> log show --last 10m \
  --predicate 'processImagePath CONTAINS "Runner"' --style compact \
  | grep -iE "ZONE_ERROR|wait_playback|live_audio|plan\.generate|run\.assessment|bpm_gap|suppressed"
```
E no staging:
```bash
gcloud logging read 'resource.labels.service_name=runnin-api-staging AND severity>=WARNING' \
  --project=runnin-494520 --freshness=30m --limit=20 \
  --format="value(timestamp,jsonPayload.message)"
```

## 5. Decisão registrada: Firebase Test Lab

**Adiado** até o release Android ativar. Racional (12/06): nosso valor está
em GPS+FC+Watch+áudio — Test Lab não cobre nenhum; Robo test não passa do
login OTP; iOS (plataforma primária) só via XCTest frágil. Quando o Android
RC existir: job pontual por release (Robo + 1 smoke `integration_test` em
3-4 devices físicos populares, ~$3-4/build via gcloud CLI) — é onde a
fragmentação OEM paga o custo.
