# runnin.core

Monorepo do runnin.ai — AI Running Coach.

## Estrutura

```
app/     Flutter (iOS + Android + Web)
server/  Node + Express + Firestore
docs/    Postman, GCP, notifications, etc
```

## Branches = ambientes

A convenção é "1 branch = 1 ambiente". Cada push numa branch protegida dispara o pipeline correspondente automaticamente, sem necessidade de tag — versão é controlada via bump em `app/pubspec.yaml` (e/ou `server/package.json`).

| Branch         | Server (Cloud Run)              | Mobile                                              | Web (Firebase Hosting)              |
|---             |---                              |---                                                  |---                                  |
| `main`         | —                               | —                                                   | prod (`Deploy Production`)          |
| `release`      | prod `runnin-api`               | TestFlight (iOS) + Play Internal (Android)          | —                                   |
| `homologation` | staging `runnin-api-staging`    | —                                                   | staging (`Deploy Staging`)          |

Os workflows estão configurados em:

- Server + Web: [`.github/workflows/`](.github/workflows/) (GitHub Actions)
- Mobile (iOS + Android): [`codemagic.yaml`](codemagic.yaml) (Codemagic)

Build number do IPA/AAB vem de `PROJECT_BUILD_NUMBER` (variável incremental do Codemagic), então cada push em `release` gera um build único no TestFlight / Play Internal mesmo se o `pubspec.yaml` não mudou.

## Rodando localmente

Em um terminal, suba o server:

```bash
cd server
npm run dev
```

Em outro terminal, rode o app no Chrome apontando para o server local:

```bash
cd app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

O app prepende `/v1` ao `API_BASE_URL` automaticamente.

## Deploy de produção

1. **Bumpar versão** em `app/pubspec.yaml` (e `server/package.json` se houver mudança server-side).
2. **Mergear `main` em `release`** (fast-forward quando possível).
3. **Push `release`** — dispara em sequência:
   - GitHub Actions `Deploy Server Production` (Cloud Run prod)
   - Codemagic `ios-release` (IPA → TestFlight)
   - Codemagic `android-release` (AAB → Play Internal)
4. Acompanhar nos respectivos consoles. ~3-10min total.

```bash
# Fluxo completo
git checkout main && git pull
# (edita app/pubspec.yaml pra bumpar +N)
git add app/pubspec.yaml && git commit -m "chore: bump version"
git push origin main
git checkout release && git merge --ff-only main && git push origin release
```

Pra disparar um build novo no TestFlight **sem mudança de código** (rebuild com mesma versão, novo build number do Codemagic):

```bash
git checkout release
git commit --allow-empty -m "chore: rebuild"
git push origin release
```

## Deploy de staging

Mesma ideia, na branch `homologation`:

```bash
git checkout homologation && git merge --ff-only main && git push origin homologation
```

Dispara `Deploy Server Staging` (Cloud Run) + `Deploy Staging` (Web). Mobile não tem workflow staging — TestFlight cobre o papel de "QA build".

## Pré-requisitos & credenciais

- **Codemagic UI** (Settings → Code signing):
  - Android: keystore `.jks` com reference `runnin_keystore`.
  - iOS: integração `codemagic_app_store` + secret `CERTIFICATE_PRIVATE_KEY` no grupo `ios_signing`.
- **GitHub Secrets**:
  - `GCP_SA_KEY` (Cloud Run deploy).
  - `ENV_PRODUCTION` / `ENV_STAGING` (conteúdo de `server/.env.production` / `.env.staging`).
- **Firebase**: configurado em `app/lib/firebase_options.dart` e `server/runnin-google-service-account.json` (gitignored).

## Documentação

- [Postman](docs/postman/README.md) — coleção das rotas do server
- [GCP Setup](docs/GCP_SETUP.md)
- [Notifications](docs/notifications.md)
