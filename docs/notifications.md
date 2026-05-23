# Notificações — arquitetura, tipos e triggers

> Documento de referência. Para o setup do Cloud Scheduler do cron diário, ver [notifications-schedule.md](./notifications-schedule.md).

## Visão geral

O sistema tem **duas camadas** que andam casadas:

1. **In-app** — docs no Firestore em `users/{uid}/notifications`. Listados na tela `/notifications` e contados no badge do sino da home.
2. **Push (FCM)** — entregue ao device via `admin.messaging().send()` com payload `{ notification, data }`. O `data.route` faz o tap navegar pra área certa do app.

Sempre que um evento dispara, geralmente cria-se o **in-app** (visível mesmo sem push) e, em eventos críticos, também o **push**.

```
evento (server)
   │
   ├─► CreateNotificationUseCase  ──► Firestore (in-app)
   │                                   └─► listado em /notifications
   │                                       └─► badge da home (unread)
   │
   └─► SendUserPushUseCase  ──► FCM ──► device (push)
                                         └─► onMessageOpenedApp → context.push(data.route)
```

## Storage e dedup

| Campo            | Significado                                  |
|------------------|----------------------------------------------|
| `id`             | `${type}_${dedupeKey}` — determinístico       |
| `type`           | string, ver tabela de tipos abaixo            |
| `title` / `body` | texto pro card e push                         |
| `icon`           | nome resolvido em `_iconFromName` no client   |
| `ctaLabel`       | rótulo do CTA (opcional)                      |
| `ctaRoute`       | override de rota; fallback é mapa por `type`  |
| `data`           | payload extra (ids, contexto)                 |
| `createdAt`      | ISO timestamp                                 |
| `readAt`         | visualizado pelo user (tap no card)           |
| `dismissedAt`    | apagado pelo user (swipe ou "limpar")         |

- **Dedup**: `createIfAbsent` usa transaction com o ID determinístico — chamadas concorrentes com o mesmo ID não geram duplicata.
- **Daily insights**: `dedupeKey = YYYY-MM-DD`. Cada dia gera 7 novos docs por design — o histórico fica acessível via scroll infinito.
- **`upsertPreserveUserState`**: usado em `hidratacao` pra que correção de cap no meio do dia sobrescreva `body` mas preserve `readAt`/`dismissedAt`.

## Estado visual

| Estado          | Condição                                  | Aparência                |
|-----------------|-------------------------------------------|--------------------------|
| Não visualizada | `readAt == null && dismissedAt == null`   | Borda colorida + conta no badge |
| Visualizada     | `readAt != null && dismissedAt == null`   | Borda neutra + fora do badge |
| Apagada         | `dismissedAt != null`                     | Não renderizada na lista |

- Tap no card chama `markRead` (otimista) — badge cai imediatamente.
- Swipe-to-end → `dismiss` (remove da lista, doc fica no Firestore com `dismissedAt`).
- "LIMPAR" → `dismissAll` (batch update em todos os docs ativos).

## Tipos e triggers

### Daily insights (cron diário)

7 docs por usuário/dia, criados pelo `EnsureDailyInsightsUseCase` quando:
- `POST /notifications/ensure-daily` é chamado pelo Cloud Scheduler (cron diário, ver [notifications-schedule.md](./notifications-schedule.md))
- `GET /notifications` é chamado pelo client na 1ª página (defensivo — garante que o user vê o de hoje mesmo se o cron falhou)

| `type`                    | Composição (title/body)                                                                 | Push?      | Rota fallback (client)         |
|---------------------------|------------------------------------------------------------------------------------------|------------|--------------------------------|
| `melhor_horario`          | "MELHOR HORARIO" / sugestão de janela conforme `runPeriod` + sessão                      | Não direto¹ | `/training`                    |
| `preparo_nutricional`     | "PREPARO NUTRICIONAL" / `session.nutritionPre` ou fallback por tipo de sessão            | Não direto¹ | `/training`                    |
| `hidratacao`              | "HIDRATACAO" / meta diária (cap 4L) cruzando peso + sessão                               | Não direto¹ | `/profile/health`              |
| `checklist_pre_easy_run`  | "CHECKLIST PRE-EASY RUN" / aquecimento + dicas                                           | Não direto¹ | `/prep`                        |
| `sono_performance`        | "SONO → PERFORMANCE" / status integração wearable                                        | Não direto¹ | `/profile/health/devices`      |
| `bpm_real`                | "BPM REAL" / status de dado real disponível                                              | Não direto¹ | `/profile/health/zones`        |
| `fechamento_mensal`       | "FECHAMENTO MENSAL" / sumário de corridas no mês                                         | Não direto¹ | `/profile/health/trends`       |

¹ **Push consolidado**: o cron diário também dispara `SendDailyPushUseCase` que envia **1 push motivacional por dia** com `data.route = /training` (ou `/home` se não há sessão). Cada um dos 7 insights NÃO vira push separado pra evitar spam.

### Eventos de plano

| `type`            | Trigger (server)                                                                       | Push? | Rota                                          |
|-------------------|----------------------------------------------------------------------------------------|-------|-----------------------------------------------|
| `plan_ready`      | `GeneratePlanUseCase` após `repo.update({status:'ready'})` ([generate-plan.use-case.ts:316](../server/src/modules/plans/use-cases/generate-plan.use-case.ts#L316)) | **Sim** | `/training` |
| `plan_proposal`   | `ProposeCheckpointUseCase` quando checkpoint semanal gera revisão ([propose-checkpoint.use-case.ts:107-124](../server/src/modules/plans/use-cases/propose-checkpoint.use-case.ts#L107-L124)) | **Sim** | `/training/revise?planId={planId}` |

Dedup: `dedupeKey = planId` (ready) / `dedupeKey = revisionId` (proposal) — cada plano/revisão notifica uma única vez.

### Eventos do coach

| `type`            | Trigger (server)                                                                       | Push? | Rota                       |
|-------------------|----------------------------------------------------------------------------------------|-------|----------------------------|
| `coach_message`   | `GenerateReportUseCase._enrichInBackground` após salvar relatório com status `enriched` ([generate-report.use-case.ts](../server/src/modules/coach/use-cases/generate-report.use-case.ts)) | **Sim** | `/history/run/{runId}` |

Dedup: `dedupeKey = report_enriched_{runId}`.

## Push notifications (FCM)

### Setup

- **Registro de token** ([push_notifications_service.dart](../app/lib/features/notifications/data/push_notifications_service.dart)): `initAndRegister` pede permissão, pega o token, envia pro server via `POST /notifications/devices`. Listener `onTokenRefresh` atualiza quando o token roda.
- **Server**: tokens vivem em `users/{uid}/devices`. `SendUserPushUseCase` faz fan-out pra todos os devices do user (best-effort, falha individual não derruba os demais).

### Handlers no client

`PushNotificationsService._attachHandlers` registra três caminhos:

| Caminho                          | Quando                          | Ação                                             |
|----------------------------------|----------------------------------|--------------------------------------------------|
| `getInitialMessage()`            | Cold start via tap em push      | `context.push(data.route)` depois do router montar |
| `onMessageOpenedApp`             | App em background, user tappou  | `context.push(data.route)` imediato              |
| `onMessage`                      | Foreground (app aberto)         | Apenas log — sem navegação (seria intrusivo)     |

Rota é lida de `message.data['route']`; fallback é `/notifications`.

### Payload padrão

```json
{
  "notification": { "title": "...", "body": "..." },
  "data": {
    "kind": "plan_ready" | "plan_proposal" | "coach_report_ready" | "daily_motivational",
    "route": "/training" | "/training/revise?planId=..." | "/history/run/...",
    "planId": "...",
    "revisionId": "...",
    "runId": "..."
  }
}
```

Tudo em `data` deve ser **string** (limitação do FCM).

## Toggle do usuário

`SendUserPushUseCase` respeita `profile.notificationsEnabled.push` (default `true`). Se o user desativou push em settings, in-app continua sendo criado mas push é pulado com `skipped: 'disabled_by_user'`.

## Paginação

- Server: `GET /notifications?cursor={iso}&limit={n}` → `{ items, nextCursor }`. `listActive` pede `limit+1` pra detectar `hasMore` sem 2ª query; cursor é o `createdAt` do último doc.
- Client: `NotificationsCubit.loadMore()` é disparado pelo `ScrollController` quando faltam 200px pro fim. Dedupe defensivo por ID ao mergear páginas.
- `ensureDaily.execute()` roda **só na 1ª página** (`cursor` ausente) — evita atrasar paginação.

## Onde fica o quê

| Camada     | Arquivo                                                                                                                          |
|------------|----------------------------------------------------------------------------------------------------------------------------------|
| Entidade   | [server/src/modules/notifications/domain/notification.entity.ts](../server/src/modules/notifications/domain/notification.entity.ts) |
| Repo       | [server/src/modules/notifications/infra/firestore-notification.repository.ts](../server/src/modules/notifications/infra/firestore-notification.repository.ts) |
| Daily cron | [server/src/modules/notifications/domain/use-cases/ensure-daily-insights.use-case.ts](../server/src/modules/notifications/domain/use-cases/ensure-daily-insights.use-case.ts) |
| Push UC    | [server/src/modules/notifications/domain/use-cases/send-user-push.use-case.ts](../server/src/modules/notifications/domain/use-cases/send-user-push.use-case.ts) |
| Daily push | [server/src/modules/notifications/domain/use-cases/send-daily-push.use-case.ts](../server/src/modules/notifications/domain/use-cases/send-daily-push.use-case.ts) |
| Controller | [server/src/modules/notifications/http/notification.controller.ts](../server/src/modules/notifications/http/notification.controller.ts) |
| Entidade client | [app/lib/features/notifications/domain/entities/app_notification.dart](../app/lib/features/notifications/domain/entities/app_notification.dart) |
| Cubit      | [app/lib/features/notifications/presentation/cubit/notifications_cubit.dart](../app/lib/features/notifications/presentation/cubit/notifications_cubit.dart) |
| Tela lista | [app/lib/features/notifications/presentation/pages/notifications_page.dart](../app/lib/features/notifications/presentation/pages/notifications_page.dart) |
| Rota por tipo | [app/lib/features/notifications/presentation/notification_routes.dart](../app/lib/features/notifications/presentation/notification_routes.dart) |
| Push service | [app/lib/features/notifications/data/push_notifications_service.dart](../app/lib/features/notifications/data/push_notifications_service.dart) |
| Badge sino | [app/lib/features/home/presentation/pages/home_page.dart](../app/lib/features/home/presentation/pages/home_page.dart) (`_NotificationBell`) |
| Provider shell | [app/lib/shared/widgets/main_layout.dart](../app/lib/shared/widgets/main_layout.dart) |

## Como adicionar um tipo novo

1. Adicionar string em `Notification.type` ([notification.entity.ts](../server/src/modules/notifications/domain/notification.entity.ts)).
2. No use case que dispara o evento, chamar `container.useCases.createNotification.execute(...)` (in-app) e opcionalmente `container.useCases.sendUserPush.execute(...)` (push). Definir `dedupeKey` estável pro evento.
3. No client, mapear `type → rota` em [notification_routes.dart](../app/lib/features/notifications/presentation/notification_routes.dart).
4. Se for novo icon, adicionar case em `_iconFromName` ([app_notification.dart](../app/lib/features/notifications/domain/entities/app_notification.dart)).
5. Atualizar a tabela neste doc.
