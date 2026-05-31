# RUN_SHARE — Spec frontend (SUP-610 C4)

## Route + entry points

- Route: `/share` aceitando `extra: {runId: string}` (passa run a compartilhar)
- Entries:
  - HOME ÚLTIMA CORRIDA card → button COMPARTILHAR
  - Run Report page → button COMPARTILHAR
  - HIST run detail page → button COMPARTILHAR

## Page structure

`SharePage` com 2 tabs no topo (CARD / CÂMERA + OVERLAY).

## Tab 1: CARD

### Preview composition (`FigmaShareCardPreview` — criar em A6)

Card 4:3 (export 1080×1350) com:
- Branding "RUNNIN.AI" badge top-left
- Distância grande (`5.2km`) + duração (`28:15` orange) + pace (`Pace: 5:26/km`)
- `FigmaChartLineSpark` mostrando splits da run com markers nos km (1K, 2K, 3K, 4K)
- Tagline LLM: "{plan.weekFocus}, semana {weekNumber} do plano {goal} — {improvementText}"
  - Se não houver plano: "Corrida {type} concluída"
- Stats inferiores: streak (🔥 N dias seguidos), BPM, RANK (TOP N% se benchmark wired)

### 3 themes

`ShareTheme` enum:
- `dark` (default): tokens existentes — fundo `FigmaColors.bgBase`, cyan accent
- `color`: usa skin ativa do user via `themeController.activeSkin`
- `minimal`: mono — fundo preto puro, accent white, sem ícones decorativos

Switcher: row de 3 chips cyan-border, ativo cheio cyan.

### Render como PNG

```dart
final boundary = GlobalKey();
// wrap preview in RepaintBoundary(key: boundary, child: preview)

Future<Uint8List> renderPng() async {
  final ctx = boundary.currentContext!;
  final renderObj = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await renderObj.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
```

### 4 share targets

Lista vertical de cards com ícone + label + arrow:
- Instagram Stories — `share_plus` package: `Share.shareXFiles([XFile.fromData(png, ...)], text: tagline)` ou intent `instagram-stories://`
- WhatsApp — `Share.shareXFiles(...)` (sistema decide)
- Twitter/X — `Share.shareXFiles(...)`
- Salvar imagem — `gallery_saver` package (mobile) OU blob download web (`AnchorElement` + `download` attribute)

Detect web vs mobile via `kIsWeb`; mostrar diálogo "Salvar imagem só disponível no app mobile" se aplicável.

## Tab 2: CÂMERA + OVERLAY

### Camera/galeria

- Botão "Tirar outra foto ↗" abre `ImagePicker().pickImage(source: ImageSource.camera)` (mobile) ou `source: ImageSource.gallery` (fallback)
- Web: usa `image_picker_web` package OR mostra "Disponível em mobile"

### Overlay composition

`Stack` com:
1. `Image.file(foto)` cobrindo full
2. `Positioned` Branding RUNNIN.AI top-left
3. `Positioned` Sparkline `FigmaChartLineSpark` (cyan, semi-transparent bg)
4. `Positioned` Caption tagline bottom-left
5. `Positioned` 4 stat chips bottom-right (conforme toggles habilitados)

### 9 toggle chips (DADOS NO OVERLAY)

Seção abaixo da preview. Cada chip é `FigmaSelectionButton` em modo toggle multi-select.

Defaults selecionados: Pace, Distância, Tempo, Streak, Plano, Trajeto.
Não selecionados por padrão: BPM, Splits, Coach.

```dart
const overlayToggles = ['Pace', 'Distância', 'Tempo', 'BPM', 'Streak', 'Plano', 'Trajeto', 'Splits', 'Coach'];
```

Para "Trajeto", renderizar mini-map (polyline GPS) usando `flutter_map` package ou simple CustomPaint.

### Same render + share targets do tab 1.

## Critério done

- `dart analyze lib/features/run/` → 0 errors / 0 warnings
- Preview Card renderiza com dados reais da run
- Tabs trocam sem perda de state
- Share intents abrem apps nativos (testar em mobile)
- "Salvar imagem" funciona (mobile) ou mostra mensagem fallback (web)
- 1-2 microcommits (issue grande)
