# runnin

runnin.ai — AI Running Coach

## Rodando localmente

Em um terminal, suba o server local:

```bash
cd /home/nalin/Projects/runnin.app/server
npm run dev
```

Em outro terminal, rode o app no Chrome apontando para o server local:

```bash
cd /home/nalin/Projects/runnin.app/app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

O app adiciona `/v1` automaticamente ao `API_BASE_URL`, então use apenas a raiz do server.

## Deploy

Deploy do backend no Cloud Run:

```bash
cd /home/nalin/Projects/runnin.app
./deploy-server.sh
```

Deploy do frontend no Firebase Hosting:

```bash
cd /home/nalin/Projects/runnin.app
./deploy-web.sh
```
