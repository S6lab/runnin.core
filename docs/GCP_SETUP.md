# GCP, Firebase & Cloud Run Setup

## Project Details

| Field             | Value                                            |
| ----------------- | ------------------------------------------------ |
| GCP Project ID    | `runnin-494520`                                  |
| Region            | `southamerica-east1`                             |
| Service Account   | `paperclip@runnin-494520.iam.gserviceaccount.com`|
| IAM Role          | `roles/editor`                                   |

## Available GCP Services

- **Cloud Run** — `runnin-api` (production), `runnin-api-staging` (staging)
- **Firebase Hosting** — `runnin-494520.web.app`
- **Cloud Firestore** — document database
- **Cloud Storage** — file storage
- **Firebase Cloud Messaging** — push notifications
- **Cloud Build** — container builds for Cloud Run
- **Cloud Logging & Monitoring** — observability
- **Identity Toolkit** — Firebase Auth
- **Pub/Sub** — messaging
- **Gemini API** — generative AI
- **Cloud Text-to-Speech** — TTS

## Local Credential Setup

### 1. Obtain the service account key

Ask the project owner for the service account JSON key file. It follows the naming pattern `runnin-494520-*.json`.

### 2. Place the key file

Copy it to the project root:

```
cp ~/path-to-key/runnin-494520-XXXX.json ./
```

The file is gitignored via the pattern `runnin-494520-*.json` — it will never be committed.

### 3. Activate with gcloud

```bash
gcloud auth activate-service-account --key-file=runnin-494520-*.json
gcloud config set project runnin-494520
```

Verify:

```bash
gcloud auth list
gcloud projects describe runnin-494520
```

### 4. Set GOOGLE_APPLICATION_CREDENTIALS (for SDKs)

For server-side code that uses Firebase Admin SDK or any Google Cloud client library:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/runnin-494520-387fe41b3198.json"
```

Add this to your shell profile or `.env` files as needed.

## Deploying to Cloud Run

### Production

```bash
./deploy-server.sh
```

Deploys `server/` to Cloud Run service `runnin-api` in `southamerica-east1`. Requires `server/.env.production`.

**URL:** https://runnin-api-506126899076.southamerica-east1.run.app

### Staging

```bash
./deploy-server-staging.sh
```

Deploys to `runnin-api-staging`. Uses `server/.env.staging` (falls back to `.env.production`).

**URL:** https://runnin-api-staging-506126899076.southamerica-east1.run.app

### What the deploy scripts do

1. Read env vars from the appropriate `.env.*` file
2. Run `gcloud run deploy --source=server` which triggers Cloud Build to containerize
3. Set env vars, memory (512Mi), CPU (1), and scaling (0–10 prod, 0–5 staging)
4. Uses service account `runnin-api@runnin-494520.iam.gserviceaccount.com` as the runtime identity

### Rollback

```bash
gcloud run services update-traffic runnin-api \
  --to-revisions=REVISION_NAME=100 \
  --region=southamerica-east1 \
  --project=runnin-494520
```

List revisions first:

```bash
gcloud run revisions list --service=runnin-api \
  --region=southamerica-east1 --project=runnin-494520
```

## Deploying Firebase Hosting (Web)

### Production

```bash
./deploy-web.sh
```

Builds Flutter web and deploys to Firebase Hosting live channel.

### Staging

```bash
./deploy-web-staging.sh
```

Deploys to Firebase Hosting preview channel `staging`.

Both scripts use `gcloud auth print-access-token` to authenticate with the Firebase Hosting REST API.

## Security Notes

- **Never commit** the service account JSON file to git
- The `.gitignore` pattern `runnin-494520-*.json` covers all key files for this project
- In CI/CD, store the key as a secret (e.g., GitHub Actions secret, Cloud Build secret)
- The service account has `roles/editor` — broad access; consider scoping down for CI-only use
- Rotate the key periodically via GCP Console > IAM > Service Accounts
