# runnin.core

Monorepo do runnin.ai — AI Running Coach.

## Estrutura

```
app/     Flutter (iOS + Android + Web)
server/  Node + Express + Firestore
docs/    Postman, GCP, notifications, etc
```

## Branches = ambientes

A convenção é "1 branch = 1 ambiente". Cada push numa branch protegida dispara o pipeline correspondente automaticamente, sem necessidade de tag — versão é controlada via bump em `app/pubspec.yaml` (e/ou `server/package.json`). Mobile tem branches **separadas por plataforma** pra publicar iOS e Android de forma independente.

| Branch             | Server (Cloud Run)              | Mobile                              | Web (Firebase Hosting)              |
|---                 |---                              |---                                  |---                                  |
| `main`             | —                               | —                                   | prod (`Deploy Production`)          |
| `release`          | prod `runnin-api`               | —                                   | —                                   |
| `release-ios`      | —                               | TestFlight (Codemagic `ios-release`) | —                                   |
| `release-android`  | —                               | Play Internal (Codemagic `android-release`) | —                                   |
| `homologation`     | staging `runnin-api-staging`    | —                                   | staging (`Deploy Staging`)          |

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

Cada alvo deploya em sua branch correspondente. Você escolhe o que publicar:

```bash
git checkout main && git pull
# (edita app/pubspec.yaml e/ou server/package.json pra bumpar)
git add . && git commit -m "chore: bump version"
git push origin main
```

Depois, dependendo do que quer publicar:

```bash
# Server prod (Cloud Run, via GitHub Actions)
git checkout release && git merge --ff-only main && git push origin release

# iOS (TestFlight, via Codemagic)
git checkout release-ios && git merge --ff-only main && git push origin release-ios

# Android (Play Internal, via Codemagic)
git checkout release-android && git merge --ff-only main && git push origin release-android
```

Pra publicar tudo de uma vez, push as 3 branches (cada uma dispara o pipeline correspondente em paralelo).

Pra disparar um build novo no TestFlight / Play Internal **sem mudança de código** (rebuild com mesma versão semver, novo build number do Codemagic):

```bash
git checkout release-ios     # ou release-android
git commit --allow-empty -m "chore: rebuild"
git push origin release-ios
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
