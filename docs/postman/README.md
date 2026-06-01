# Postman — runnin API

Coleção com as rotas HTTP do server runnin.core (Cloud Run / Express).

- **Collection:** [runnin.postman_collection.json](./runnin.postman_collection.json) — 93 endpoints em 15 folders.
- **Environments:** [prod](./runnin-prod.postman_environment.json), [staging](./runnin-staging.postman_environment.json).

Snapshot do server em 2026-06-01. Pode ficar desatualizado — ver [Como atualizar](#como-atualizar) abaixo.

## Importar

1. Postman → **Import** → arraste `runnin.postman_collection.json`.
2. Importe um dos environments (`runnin-prod.postman_environment.json` ou `runnin-staging.postman_environment.json`).
3. No canto superior direito, selecione o environment ativo.

## Variáveis do environment

| Variável | O que é | Como obter |
|---|---|---|
| `baseUrl` | URL base do Cloud Run | já preenchido (prod ou staging) |
| `idToken` | Firebase ID Token do usuário logado (`Authorization: Bearer …`) | ver abaixo |
| `cronToken` | Header `X-Cron-Token` das rotas internas/cron | env var do Cloud Run (`CRON_TOKEN`); pega via `gcloud run services describe runnin-api --format='value(spec.template.spec.containers[0].env)'` ou peça pra alguém com acesso ao painel |

### Obter um Firebase ID Token (idToken)

**Opção recomendada — rota proxy no server (Postman one-shot):**

`POST /v1/admin/dev/login` (na folder **Admin — Cron**) é um proxy pra Identity Toolkit `signInWithPassword`. Manda email/senha, devolve idToken pronto. O request tem um **test script** anexado que extrai o `idToken` da response e seta automaticamente como `{{idToken}}` da collection — depois de rodar 1x, todas as rotas autenticadas funcionam.

Exige `FIREBASE_WEB_API_KEY` setada no env do server (Web API key do projeto Firebase; é a mesma string usada em `app/lib/firebase_options.dart`, pública por design). Setar no Cloud Run:
```bash
gcloud run services update runnin-api \
  --region southamerica-east1 \
  --set-env-vars FIREBASE_WEB_API_KEY=AIza... \
  --project runnin-494520
```

**Opção 2 — DevTools no app web:**
```js
firebase.auth().currentUser.getIdToken().then(t => console.log(t))
```

**Opção 3 — `curl` direto na Identity Toolkit (sem passar pelo server):**
```bash
curl -X POST \
  "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FIREBASE_WEB_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"email":"...","password":"...","returnSecureToken":true}'
```

O token expira em 1h. Quando começar a vir 401, regenera (rerrodar o request `dev/login` no Postman atualiza `{{idToken}}` sozinho).

### Privilégio admin

As rotas em **Admin — Auth + requireAdmin** exigem o claim `admin: true` no Firebase Auth.

**Forma recomendada** (já incluída na coleção, em **Admin — Cron**): `POST /v1/admin/users/admin-claim` com `X-Cron-Token`. Aceita lookup por email ou phone E.164:
```bash
curl -X POST "$BASE_URL/v1/admin/users/admin-claim" \
  -H "Content-Type: application/json" \
  -H "X-Cron-Token: $CRON_TOKEN" \
  -d '{ "email": "nalin@s6lab.com", "admin": true }'
```

O endpoint faz merge com claims existentes e revoga refresh tokens — o user precisa reabrir o app pra pegar o novo ID token com a claim. Pra remover admin, `{ "admin": false }`.

## Auth na coleção

A coleção declara auth `Bearer {{idToken}}` no nível raiz — todos os requests herdam.

Exceções (já marcadas em cada request):
- **Health checks** (`/health`, `/healthz`, `/readyz`) → `noauth`.
- **`/v1/subscriptions/plans`** e **`/v1/subscriptions/seed`** → públicas.
- **Folder "Admin — Cron"** e **`/v1/notifications/ensure-daily`**, **`/v1/users/internal/reset-plan-revision-quota`** → `noauth` no Bearer; em vez disso usam header `X-Cron-Token: {{cronToken}}`.

## Body schemas (POST/PATCH)

Pra evitar drift, os bodies vêm como `{}` placeholder. O `description` de cada request aponta pro **Zod schema canônico** no código (ex.: `IngestSamplesSchema` em `server/src/modules/biometrics/use-cases/ingest-samples.use-case.ts`). Pra preencher o body, abra o arquivo e copie a forma do schema.

Exemplo já preenchido: `POST /v1/biometrics/samples`.

## Como atualizar

Quando uma rota nova for adicionada (`*.routes.ts`) ou mudar:

1. Adicione/edite o request correspondente em `runnin.postman_collection.json`. Estrutura mínima:
   ```json
   {
     "name": "POST /novo-endpoint",
     "request": {
       "method": "POST",
       "header": [{ "key": "Content-Type", "value": "application/json" }],
       "body": { "mode": "raw", "raw": "{}" },
       "description": "Schema: NovoSchema (server/src/modules/.../use-cases/...)",
       "url": {
         "raw": "{{baseUrl}}/v1/.../novo-endpoint",
         "host": ["{{baseUrl}}"],
         "path": ["v1", "...", "novo-endpoint"]
       }
     }
   }
   ```
2. Roda `python3 -c "import json; json.load(open('docs/postman/runnin.postman_collection.json'))"` pra validar JSON.
3. Commita junto com a mudança da rota.

Não use auto-geração (Postman → "Generate from OpenAPI") por enquanto — o server **não** expõe OpenAPI. Se um dia expor (`/openapi.json`), trocar tudo isso por `postman-code-generators` no CI.
