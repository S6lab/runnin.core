# Instalar Runnin no Galaxy Watch (Wear OS) via ADB

Guia rápido pra sideload do `runnin-watch-v*.apk` em Galaxy Watch 4/5/6/7
(Wear OS 3+) sem precisar de Play Store.

## 1. Habilitar Developer Mode no Galaxy Watch

1. No relógio, abra **Settings → About watch → Software information**.
2. Toque em **Software version** **7×** seguidas. Aparece "Developer mode
   habilitado".
3. Volte pra **Settings**. Aparece uma nova entrada **Developer options**.
4. Em **Developer options**:
   - Ligue **ADB debugging**
   - Ligue **Wireless debugging** (preferido — não precisa do dock USB do
     Galaxy Watch, que muitos usuários não têm)
5. Toque em **Wireless debugging** → toque em **Pair new device**. Ele
   mostra um **código de pareamento** (6 dígitos) e um endereço
   `IP:porta` (ex: `192.168.0.42:42001`).

## 2. Conectar via ADB do laptop

No laptop, com o Galaxy Watch e o laptop na **mesma rede Wi-Fi**:

```bash
# Use o IP:porta mostrado no relógio (porta de PAIRING, não a de conexão)
adb pair 192.168.0.42:42001
# Cole o código de 6 dígitos quando pedido.

# Depois do pair, o relógio mostra OUTRA porta (de conexão). Use ela:
adb connect 192.168.0.42:5555
adb devices   # confirma que aparece "192.168.0.42:5555    device"
```

Se você tem o phone Android também conectado via USB ao laptop, o `adb`
vai mostrar 2 devices. Use `-s` pra mirar especificamente o relógio:

```bash
adb -s 192.168.0.42:5555 install -r runnin-watch-v1.0.4-84.apk
```

## 3. Instalar o APK

A partir da pasta com o APK (ex: `builds-1.0.4-84/`):

```bash
adb -s <ip_do_watch>:5555 install -r runnin-watch-v1.0.4-84.apk
```

Output esperado: `Success`.

Se aparecer `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, é porque já tem uma
versão instalada com signature diferente (provavelmente debug). Desinstala
antes:

```bash
adb -s <ip_do_watch>:5555 uninstall com.s6lab.runnin
```

## 4. Primeira execução

1. No Galaxy Watch, role o app drawer e abra **Runnin**.
2. Vai pedir **BODY_SENSORS** + **ACTIVITY_RECOGNITION** — aceitar ambas.
   Sem isso, o BPM live não fluí.
3. A primeira tela é **PreRunScreen** ("ESCOLHA O TIPO"). Se o phone
   Runnin já tiver pareado e empurrado a sessão do dia, aparece
   "SESSÃO DO DIA" também. Senão, só "CORRIDA LIVRE".

## 5. Pareamento phone↔watch

Pra Wearable Data Layer funcionar (Watch → Phone messages):

- Phone e Watch precisam estar pareados via **Galaxy Wearable** app
  (ou **Wear OS** app oficial do Google).
- Ambos APKs (`runnin-phone-*.apk` e `runnin-watch-*.apk`) precisam
  estar assinados pela **mesma keystore** (já garantido — verificável
  via `apksigner verify --print-certs`).
- O `applicationId` precisa ser idêntico: `com.s6lab.runnin` em ambos
  (também já garantido).

Se o phone Runnin abrir e mostrar banner "Conecte um Watch", está
funcionando. Se não aparece nada, conferir:

```bash
# Logcat do phone filtrado pra Watch comm
adb -s <phone_serial> logcat -s WearableBridge:V PhoneWearListener:V
```

Deve aparecer linhas tipo `onMessageReceived path=/runnin/start_run` ou
`pushRunState.fail`.

## 6. Troubleshooting

| Sintoma | Causa provável | Fix |
|---|---|---|
| App fecha sozinho ao abrir | BODY_SENSORS negado | Settings → Apps → Runnin → Permissions |
| BPM fica em "—" durante a corrida | ExerciseClient não startou | Logcat watch: `adb -s <watch>:5555 logcat -s WorkoutController:V` |
| Tap INICIAR cai em "Phone sem resposta" | Watch não enxerga phone reachable | Confirmar pareamento Galaxy Wearable; reabrir phone Runnin |
| Layout corta nos cantos da tela redonda | Bug de safe area | Reportar — padding raiz é 14dp por padrão em telas round |
| Sessão do dia não aparece no PreRun | Phone não empurrou today_session | Abrir phone Runnin na aba Home — push é automático |

## 7. Re-instalar atualizações

A cada novo APK, o `-r` reusa o data dir (não perde permissões nem cache).
Se quiser reset limpo:

```bash
adb -s <ip_do_watch>:5555 uninstall com.s6lab.runnin
adb -s <ip_do_watch>:5555 install runnin-watch-v1.0.5-N.apk
```
