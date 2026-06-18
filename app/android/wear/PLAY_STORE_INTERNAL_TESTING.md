# Subir Runnin Wear OS no Play Store (teste interno)

**IMPORTANTE — política Google Play desde Aug/2023**: Wear OS **não pode**
mais usar Companion Delivery via mesmo release do phone. Tem que usar uma
**TRACK DEDICADA** de Wear OS. Cada track tem sua série de versionCode
independente.

Se você cair no erro:

> "Não é possível lançar esta versão porque ela não permite que os usuários
> existentes façam a atualização para os novos pacotes de apps."
> "Para enviar essa versão, remova o pacote do Wear OS e crie uma faixa
> dedicada do Wear OS em 'Wear OS' na guia Formatos das configurações
> avançadas."

…é porque tentou subir o AAB do Wear no MESMO release do phone (caminho
antigo). Siga os passos abaixo.

Pré-requisitos (já garantidos pelo build atual):
- Mesma `applicationId` em phone e wear (`com.s6lab.runnin`) ✓
- Mesma keystore — `SHA-256 9a32ad…c46faf` em ambos ✓
- Wear AAB com `<uses-feature android:name="android.hardware.type.watch">` ✓
- Wear meta-data `com.google.android.wearable.standalone=true` ✓

## Passo 1 — Limpar tentativa anterior (se você já tentou)

Se já tentou subir o AAB do Wear num release de phone:

1. https://play.google.com/console → app **Runnin**
2. **Test → Internal testing → Releases**
3. Editar o release pendente / em rascunho
4. **Remove** o AAB do Wear da lista de arquivos
5. Salvar — agora o release do phone fica só com o AAB do phone

## Passo 2 — Habilitar track dedicada do Wear OS

1. **Configure → Advanced settings** (lado esquerdo, dependendo da versão
   da UI pode estar em **Grow → Store presence → Store listing**)
2. Aba **Form factors** → seção **Wear OS**
3. Marcar **"Use a dedicated track for Wear OS"** (ou em PT-BR:
   "Usar uma faixa dedicada para o Wear OS")
4. Salvar

Pode pedir pra você confirmar que tem um app Wear OS standalone (`uses-feature`
watch) — confirmar. Não pode reverter depois de habilitar.

Após salvar, aparece **Wear OS** como item no menu lateral, com seu próprio
conjunto de tracks (Internal, Closed, Open, Production).

## Passo 3 — Subir o AAB do Wear no Internal testing dedicado

1. **Wear OS → Testing → Internal testing**
2. **Create new release**
3. Upload do AAB: [builds-1.0.4-24/runnin-watch-v1.0.4-24.aab](../../../builds-1.0.4-24/runnin-watch-v1.0.4-24.aab) (12 MB)
4. Como é track novinha, **versionCode 1 é aceito** (cada track Wear OS tem
   sua série independente do phone)
5. **Release name**: `1.0.4 (1) — Wear OS standalone`
6. **Release notes** (campo obrigatório):
   ```
   - Primeira versão do app Wear OS standalone
   - Paridade com Apple Watch: PreRun, Briefing, ActiveRun, RunCompleted
   - BPM ao vivo via ExerciseClient, splits, pause/parar com slide-to-confirm
   - Comunicação phone↔watch via Wearable Data Layer
   ```
7. **Review release** → **Start rollout to Internal testing**.

## Passo 4 — Adicionar testers no track Wear OS

Os tester emails do phone track NÃO são herdados automaticamente.

1. **Wear OS → Testing → Internal testing → Testers**
2. **Create email list** (ou reusar a do phone se aparecer na lista)
3. Adicionar os emails dos testers
4. Copiar o **opt-in URL** (algo tipo
   `https://play.google.com/apps/internaltest?id=com.s6lab.runnin`)

## Passo 5 — Instalar no Galaxy Watch

1. **No celular do tester**: aceitar o opt-in pelos 2 links (phone track +
   Wear OS track)
2. Instalar Runnin no celular pelo Play Store
3. **No Galaxy Watch pareado**:
   - Abrir Play Store do relógio
   - Buscar **Runnin**
   - Toque em Install
   - (Em alguns casos, o Wear instala automaticamente quando o phone for
     instalado e o relógio estiver pareado via Galaxy Wearable)

## Verificação pelo lado do dev

```bash
# No phone Android (com ADB):
adb shell dumpsys package com.s6lab.runnin | grep -E "versionName|versionCode"

# No Galaxy Watch (ADB wireless):
adb -s <watch_ip>:5555 shell dumpsys package com.s6lab.runnin | grep -E "versionName|versionCode"
```

Phone deve mostrar versionName=1.0.4. Watch deve mostrar versionName=1.0.0
(release Wear independente). **Diferença normal** — tracks dedicadas
versionam separado.

## Troubleshooting

| Sintoma | Causa | Fix |
|---|---|---|
| "Wear OS" não aparece no menu lateral | Track dedicada não habilitada | Passo 2 |
| Erro "removed support for older devices" no upload | versionCode menor que algum publicado anterior na MESMA track Wear | Bumpar `versionCode` em [wear/build.gradle.kts](build.gradle.kts) e rebuildar |
| Watch app instala mas não fala com phone | Keystore divergente | `apksigner verify --print-certs` em ambos AABs deve dar mesmo SHA-256 |
| Phone instala mas Wear não aparece no Play Store do relógio | Tester não opt-in no Wear OS track (lista separada) | Passo 4 |
| Galaxy Watch não para de mostrar "Loading…" no Play Store | App ainda processando no Play Console (até 24h pra primeira release) | Esperar |

## Próximas releases

Cada nova versão do Wear OS bumpa `versionCode` no [wear/build.gradle.kts](build.gradle.kts):

```kotlin
defaultConfig {
    versionCode = 2  // bumpar a cada release
    versionName = "1.0.1"  // semver da Wear app, independente do phone
}
```

E rebuild:

```bash
cd app/android
./gradlew :wear:bundleRelease
# AAB em app/build/wear/outputs/bundle/release/wear-release.aab
```

Upload manual no Wear OS internal track (mesmo fluxo do Passo 3).

## Automação futura (opcional)

Pra publicar Wear AAB automaticamente via Codemagic precisa um workflow
separado com `track: wear:internal` (sintaxe do plugin codemagic_publish).
Hoje deixei só o phone AAB no `android-release` workflow do
[codemagic.yaml](../../../codemagic.yaml). Por enquanto, upload do Wear é
manual.
