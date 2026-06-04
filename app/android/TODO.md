# TODO — Android

Lista de pendências do build Android. Atualizar conforme forem entregues.

## 🔴 Bloqueio — Auth (Google Sign-In + SMS) sem SHA registrado

**Sintoma:** Login Google e Login SMS não funcionam em build release Android.

**Causa raiz:** [google-services.json](app/google-services.json) tem só o OAuth
web client (`type=3`). Não tem nenhum `oauth_client` `type=1` (Android)
registrado com `certificate_hash`. Sem o SHA-1 da assinatura release no
Firebase Console:
- Google Sign-In nativo rejeita (Play Services valida package + SHA)
- Phone Auth (SMS) tenta Play Integrity attestation → falha → cai pra
  reCAPTCHA fallback (que está sendo bloqueado)

**Já feito:**
- `GoogleSignIn(serverClientId: webClientId)` em [login_page.dart](../lib/features/auth/presentation/pages/login_page.dart#L164)
  (commit `6358e0e`, build 18). Necessário mas insuficiente.

**Passos manuais pendentes:**

1. **Extrair SHA-1 + SHA-256 do keystore release usado pelo Codemagic.**
   - Local (se você tem o `.jks`):
     ```bash
     keytool -list -v -keystore runnin_keystore.jks -alias <keyAlias>
     ```
   - No Codemagic: App settings → Code signing identities → Android
     keystores → download do `runnin_keystore.jks` e rodar `keytool` local.
   - **OU** adicionar step no `codemagic.yaml`:
     ```yaml
     - name: Print keystore SHA fingerprints
       script: |
         keytool -list -v \
           -keystore $CM_KEYSTORE_PATH \
           -storepass $CM_KEYSTORE_PASSWORD \
           -alias $CM_KEY_ALIAS \
           -keypass $CM_KEY_PASSWORD | grep -E "SHA1|SHA-?256"
     ```

2. **Registrar no Firebase Console:**
   - Project Settings → Your apps → Android `com.s6lab.runnin`
   - "Add fingerprint" → cole o **SHA-1**
   - Adicione também o **SHA-256** (Play Integrity exige).

3. **Se você está usando Google Play App Signing** (recomendado pra
   distribuição na Play Store):
   - Pegar o "App Signing key certificate" SHA-1 e SHA-256 no
     Play Console → Setup → App Signing.
   - **ESSE É DIFERENTE** do upload keystore — é a chave que o Google
     usa pra re-assinar o APK na Play Store. Sem registrar essa, o app
     instalado pela Play Store falha (mesmo que o teste no Codemagic
     funcione, porque ele usa a upload key).
   - Registrar AMBOS SHA-1s (upload + app signing) no Firebase.

4. **Download e substituir** `app/android/app/google-services.json` com
   o arquivo gerado depois de adicionar os fingerprints.

5. **Commit** + push em `release-android` pra disparar build novo.

## 🟡 Refinamentos pendentes (depois do auth)

### Background mode (item #5 do user feedback)
- iOS: precisa Live Activity / ActivityKit pra notificação persistente.
- Android: `ForegroundNotificationConfig` já configurado no GPS
  (`run_bloc.dart:323`). Verificar se a notificação está aparecendo
  durante a run quando o app vai pra background. Se sim, fica como
  referência pro fix iOS.

### Health Connect — Sleep sync no Status Corporal
- `health` plugin já lê `SLEEP_ASLEEP`/`SLEEP_DEEP` no
  [health_sync_service.dart](../lib/features/biometrics/data/health_sync_service.dart).
- Verificar se Health Connect está retornando dados em devices Android
  testados. Se HC não está instalado, sample fica vazio.
- Health Connect tem hierarquia de permission DIFERENTE do HealthKit —
  usuário precisa autorizar cada data type explicitamente. UX pode
  pedir HC install se não detectado.

### Wear OS BPM
- [WorkoutRealtimePlugin.kt](app/src/main/kotlin/com/s6lab/runnin/WorkoutRealtimePlugin.kt)
  usa `androidx.health.services.client.MeasureClient` que requer Wear OS
  pareado + capability `HEART_RATE_BPM`.
- Em devices Android sem Wear OS, `checkAvailability` retorna `no_capability`
  e BPM live fica null (UI mostra "—"). Comportamento esperado mas pode
  surfacing pra um banner explicativo igual ao no_hr_source do iOS.

### Crashlytics dSYM equivalente
- Android: o NDK upload pra Crashlytics já está configurado via
  `com.google.firebase.crashlytics` plugin. Verificar se está gerando
  symbols pra release.

## 🟢 Fixes universais que JÁ são Android-ready

Tudo que foi pushado em `release-android` (até build `1965e79` então
build 18 com auth fix) não tem código platform-specific iOS-only —
funciona nas duas plataformas:
- BPM stale detection
- Share via tmpfile + delay map render
- Cards mensal navegam pra semanal
- Coach cue logging
- Plan generation cap fix (server)
- BillingService abstraction
- Sleep wire na Home (depende do health plugin)
- SafeArea no onboarding + plan_setup
- Card premium some pós-unlock
