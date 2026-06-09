# 06 — Telemetria (corrida + biometria)

## Telemetry timeline (durante corrida)

Tick 30s no `run_bloc.dart` snapshota `{bpm, pace, distância}` no MESMO instante — antes BPM e GPS chegavam por streams separados e dessincronizados.

```dart
class TelemetryPoint {
  final int tMs;           // ms desde startedAt
  final double distM;
  final int? bpm;
  final int? paceSec;      // sec/km dos últimos ~50m
}
```

Cap 1500 ticks (=12.5h a 30s/tick). Persistido no completeRun. Coach in-run lê os últimos N ticks pra computar "como foram os últimos 500m" no cue check_in.

## Max BPM real (pico instantâneo)

Antes `maxBpmFromSplits = splits.avgBpm.reduce(max)` — média por km escondia picos de 5-10s. Agora `state.maxBpmSeen` (atualizado a cada `_onBpmTick`) é enviado no completeRun. Server faz auto-bump em `profile.maxBpm` se run.maxBpm exceder.

## GPS points

```dart
class GpsPoint {
  final double lat, lng;
  final int ts;            // Unix ms
  final double accuracy;
  final double? altitude;
  final double? pace;      // min/km do ponto
  final int? bpm;          // anexado se BPM stream emitir no mesmo tick
}
```

Salvos via `POST /v1/runs/:id/gps` em batches. Splits computados a cada km boundary.

## Biometric sync

```
app boot ou resume:
   _refreshHealthAndReload
       │
       ├──► healthSyncService.syncSince()
       │       │
       │       ├──► getHealthDataFromTypes (loop POR TIPO — bug histórico
       │       │     com plugin que aborta em 1 unsupported)
       │       │
       │       ├──► _mapToInput → BiometricSampleInput[]
       │       │
       │       └──► POST /v1/biometrics/samples (batches 500)
       │
       ├──► healthSyncService.forceFullResync() (paralelo, 7d safety net)
       │
       └──► HomeCubit.load() → refetch summary do server
```

### Tipos coletados

42 tipos HK/HealthConnect, mapeados em `_typeMap` (Dart) e enum em `BiometricSampleType` (TS):
- BPM (realtime, resting, max)
- HRV (SDNN), HRV (RMSSD — Android only, gera erro silencioso em iOS)
- Sono: stages (deep/rem/light) + inBed + awake (fallback `inBed - awake` quando sem stages — Watch SE / sleep schedule)
- Steps, distance, calories (active + basal)
- Body: weight, height, BMI, fat %, lean mass, waist
- Vital: BP, SpO2, ECG, temperature, respiratory rate
- Mobility: walking speed, walking HR

### Lições aprendidas (memória)

Ver memória `project_health_plugin_per_type_query`: **NUNCA passar lista batch pro `health.getHealthDataFromTypes`** — 1 tipo unsupported aborta TODOS. Loop tipo-por-tipo com try/catch.

## Eventos estruturados (logger)

Convenção: `logger.info('<dominio>.<componente>.<evento>', { uid?, ...meta })`.

| Evento | Quando | Meta principal |
|---|---|---|
| `llm.gemini.generate` | Cada call LLM completa | model, latencyMs, tokens, finishReason |
| `llm.gemini.generate.non_stop` | finishReason ≠ STOP/MAX_TOKENS | + chars |
| `llm.usage.tracked` | Após cada call (best-effort) | userId, model, useCase, costUsd |
| `llm.usage.tracked_failed` | Tracker falhou em Firestore | err |
| `plan.generate.failed` | LLM 3x retry esgotou | planId, err |
| `plan.narratives.generated` | Enriquecimento ok | planId, weeks |
| `plan.rationale.generated` | Rationale longo ok | planId, chars, headings |
| `plan.rationale.suspiciously_short` | <2500 chars OU <4 headings | planId, chars |
| `plan.revision.applied` | Cron weekly aplicou | planId, weekNumber, revisionId |
| `plan.revision.clamped` | Clamp 70-110% acionado | planId, clamps[] |
| `plan.session.flag_executed_failed` | Não conseguiu flag executed | runId, err |
| `coach.live.rotate.start` | Rotação preventiva iniciou | reason, turns, ageMs |
| `coach.live.reconnect_exhausted` | 10 tentativas esgotaram | attempts, code |
| `coach.runtime_config.load_failed` | Firestore down | err |
| `wearable.sync.telemetry` | Sync HK completou (qualquer outcome) | hkFetchedTotal, mappedTotal, errorMsg? |
| `wearable.sync.ping` | App boot/resume | uid, tfHint, platform |
| `wearable_sync_failed` | (analytics event app-side) | stage, platform |
| `notifications.ensure_daily_failed` | Daily ensure falhou | uid, err |
| `user.maxBpm.bumped` | Auto-bump pós-run | userId, before, after |

## Paths-chave

| Path | Função |
|---|---|
| `app/lib/features/run/presentation/bloc/run_bloc.dart` | telemetryTimeline tick + maxBpmSeen |
| `app/lib/features/biometrics/data/health_sync_service.dart` | syncSince + forceFullResync + per-type loop |
| `app/lib/features/biometrics/data/biometric_remote_datasource.dart` | POST samples + sync-telemetry + sync-ping |
| `server/src/modules/biometrics/use-cases/get-summary.use-case.ts` | Agregação multi-nível stages>inBed-awake>legacy |
| `server/src/modules/biometrics/use-cases/ingest-samples.use-case.ts` | Zod schema + persist |
| `server/src/shared/logger/logger.ts` | Winston JSON stdout |
