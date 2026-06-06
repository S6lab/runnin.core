# RunninWatch — companion app

watchOS companion que entra em `HKWorkoutSession` quando o iPhone manda
`startWorkout` via WatchConnectivity. Ponto único: forçar o Apple Watch a
escrever heart rate no HK store em alta frequência (~1Hz) durante uma corrida
no app Runnin. Sem o companion, o Watch idle escreve a cada ~2-5min.

## Arquivos

```
RunninWatch/
  RunninWatchApp.swift        # @main SwiftUI App + WCSession activation
  WorkoutController.swift     # HKWorkoutSession + HKLiveWorkoutBuilder
  SessionDelegate.swift       # recebe msgs do iPhone (start/stop/ping)
  ContentView.swift           # UI mínima ("Aguardando" / "Ativo · 142 BPM")
  Info.plist                  # NSHealthShareUsage*, WKBackgroundModes
  RunninWatch.entitlements    # com.apple.developer.healthkit
  Assets.xcassets/            # placeholder Asset catalog
```

## Setup no Xcode (precisa fazer 1x, manualmente)

O Flutter NÃO gerencia targets watchOS automaticamente. Os arquivos Swift já
existem aqui; basta criar o target no Xcode e apontar pros files existentes:

1. Abra `app/ios/Runner.xcworkspace` no Xcode.
2. **File → New → Target**.
3. Categoria **watchOS**, template **App** (não "App with extension" — a
   gente já está no formato single-target de watchOS 9+).
4. Configurações:
   - **Product Name:** `RunninWatch`
   - **Team:** Super seis LTDA (Y36XR89PWG) — mesmo que o iPhone
   - **Bundle Identifier:** `com.s6lab.runnin.watchapp`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Include Notification Scene:** ❌
   - **Include Tests:** ❌
   - **Embed in companion application:** ✅ "Runner"
5. Xcode vai gerar uma pasta `RunninWatch/` com files default. **Delete tudo
   que ele criou**, mantém só o target (Project Navigator → click direito nos
   files novos → Delete → Move to Trash).
6. **Add Files to "Runner"…** (Cmd+Option+A) com a pasta `RunninWatch/`
   existente selecionada. Marca:
   - "Copy items if needed": ❌ (os files já estão no lugar certo)
   - "Create groups": ✅
   - "Add to targets": só `RunninWatch` (NÃO Runner principal)
7. Em **Signing & Capabilities** do target RunninWatch:
   - Marca "Automatically manage signing"
   - Team: Super seis LTDA
   - Adiciona capability **HealthKit**
8. **Build Settings** do target RunninWatch:
   - `IPHONEOS_DEPLOYMENT_TARGET` deve ficar `WATCHOS_DEPLOYMENT_TARGET = 10.0`
     (Xcode setta automaticamente quando você cria target watchOS)
   - `CURRENT_PROJECT_VERSION` = bump junto com o iPhone build (28 agora)
   - `MARKETING_VERSION` = mesmo do iPhone (1.0.2)
   - `CODE_SIGN_ENTITLEMENTS` = `RunninWatch/RunninWatch.entitlements`
   - `INFOPLIST_FILE` = `RunninWatch/Info.plist`
9. Confirma que o Runner target tem o RunninWatch na **Embed App Extensions**
   build phase (Xcode põe automaticamente quando marca "Embed in companion
   application").

Depois disso o `xcodebuild archive` cria 1 arquivo `.xcarchive` contendo
ambos bundles. TestFlight instala o Watch app automaticamente quando o
iPhone install termina (não precisa upload separado).

## Bump de versão

Ver `project_ios_extension_version_sync.md` — agora são **4 lugares** pra
bumpar a cada release:

1. `app/pubspec.yaml` (`version: 1.0.2+N`)
2. `app/ios/Runner.xcodeproj/project.pbxproj` — extension RunninLiveActivity
   (3 configs Debug/Release/Profile)
3. `app/ios/Runner.xcodeproj/project.pbxproj` — RunninWatch (3 configs)
4. `app/ios/RunninWatch/Info.plist` (CFBundleVersion)

A solução boa é plugar `Flutter/Generated.xcconfig` como
`baseConfigurationReference` na extensão e no Watch. Pendente.

## Debug

- **Console.app** (macOS): filtra `subsystem:ai.runnin.workout`
  - `category:hr` → eventos do plugin iOS principal (HKAnchoredObjectQuery)
  - `category:watch-bridge` → eventos WCSession do iPhone side
  - `category:watch-session` → eventos WCSession do Watch side
  - `category:workout-controller` → start/stop/finish do HKWorkoutSession
- **No iPhone**: pre-run page mostra status do pareamento via
  `_WatchStatusBanner`.
- **No Watch**: ContentView mostra "ATIVO · 142 BPM" quando workout ativa.

## Riscos / pontos abertos

- WCSession `sendMessage` falha silenciosamente se o Watch app nunca foi
  aberto na vida. Caímos em `transferUserInfo` (fila pra próximo wake), mas
  na primeira corrida o user pode ter que abrir manualmente o Runnin no
  Watch. Considerar mostrar banner explicativo no pre-run quando paired+
  installed mas !reachable.
- Bateria: HKLiveWorkoutBuilder + HKWorkoutSession são caros. Sempre garantir
  `stop()` em todos os exit paths do iPhone (já chamamos em complete/abandon).
- Não dependemos do WCSession pra streaming de HR — Watch escreve no HK
  store, iPhone lê via HKAnchoredObjectQuery existente. WCSession é só pra
  CONTROLE (start/stop).
