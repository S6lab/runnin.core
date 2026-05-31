# COACH INTRO — Figma Node ID & Token Extraction

> SUP-628: token extraction via TemPad Dev MCP  
> Arquivo: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> Data: 2026-05-18

---

## 1. Node ID Map

### Top-level screens

| nodeId  | Nome interno                    | Slide |
|---------|--------------------------------|-------|
| `1:5770` | preparar_primeira_corrida01   | 1/4 — "Quem sou eu" |
| `1:5818` | perara_primeira_corrida02     | 2/4 — "Durante a corrida" |
| `1:5870` | preparar_primeira_corrida03   | 3/4 — "Essa é a calibração" |
| `1:5922` | preparar_primeira_corrida04   | 4/4 — "Planejamento inteligente" |

### Sub-nodes — Slide 3/4 (`1:5870`)

| nodeId  | Elemento |
|---------|----------|
| `1:5886` | Ícone container (35.997 × 35.997 px) |
| `1:5888` | Título "Essa é a calibração" |
| `1:5890` | Parágrafo body text |
| `1:5896` | Bullet card 1 — texto ("Vou medir seu pace...") |
| `1:5906` | Bullet card 3 — texto ("Calibro a progressão...") |
| `1:5911` | Bullet card 4 — texto ("Após essa corrida...") |

### Sub-nodes — Slide 4/4 (`1:5922`)

| nodeId  | Elemento |
|---------|----------|
| `1:5938` | Ícone container (35.997 × 35.997 px) |
| `1:5940` | Título "Planejamento inteligente" (293.553 × 54.58 px) |
| `1:5942` | Parágrafo body text |
| `1:5948` | Bullet card 1 — texto ("Periodização mensal...") |
| `1:5953` | Bullet card 2 — texto ("Ajuste semanal...") |
| `1:5958` | Bullet card 3 — texto ("Se não puder correr...") |
| `1:5963` | Bullet card 4 — texto ("1 revisão de plano...") |

---

## 2. Design Tokens Extraídos

### 2.1 Cores

| Token Figma (valor) | Hex / RGBA | Flutter (`FigmaColors`) |
|--------------------|-----------|------------------------|
| Background | `#050510` | `FigmaColors.bgBase` |
| Primário / Cyan | `#00D4FF` | `FigmaColors.brandCyan` |
| Coach.AI / Orange | `#FF6B35` | `FigmaColors.brandOrange` |
| Texto principal | `#FFFFFF` | `FigmaColors.textPrimary` |
| Texto body (70%) | `#FFFFFFB2` | `FigmaColors.textMuted` (70% ≈ `0xB2`) |
| Texto bullet (65%) | `#FFFFFFA6` | entre `textMuted` e `textDim` |
| Texto "PULAR" (55%) | `#FFFFFF8C` | `FigmaColors.textSecondary` |
| Surface card | `#FFFFFF08` (3%) | `FigmaColors.surfaceCard` |
| Borda card | `rgba(255,255,255,0.08)` | `FigmaColors.borderDefault` |
| Progress bar track | `#FFFFFF14` (8%) | `FigmaColors.borderDefault` |
| Progress bar fill | `#00D4FF` | `FigmaColors.progressFill` |
| Dot ativo | `#00D4FF` | `FigmaColors.dotActive` |
| Dot visitado | `#FFFFFF33` (20%) | `FigmaColors.dotVisited` |
| Dot inativo | `#FFFFFF0F` (6%) | `FigmaColors.dotInactive` |
| CTA bg | `#00D4FF` | `FigmaColors.brandCyan` |
| CTA texto | `#050510` | `FigmaColors.bgBase` |

### 2.2 Tipografia

| Elemento | Font | Peso | Size | LineHeight | LetterSpacing | Cor token |
|----------|------|------|------|-----------|--------------|-----------|
| Label seção (`// QUEM SOU EU`) | JetBrains Mono | 400 | 12px | 18px (1.5) | +2.4px | `brandCyan` |
| Breadcrumb (`COACH.AI > BRIEFING INICIAL`) | JetBrains Mono | 400 | 12px | 18px | +1.8px | `brandOrange` |
| "PULAR" | JetBrains Mono | 500 | 12px | 18px | +1.2px | `textSecondary` |
| Heading principal | JetBrains Mono | **700** | 26px | 27.3px (1.05) | −0.78px | `textPrimary` |
| Parágrafo | JetBrains Mono | 400 | 15px | 25.5px (1.7) | 0 | `#FFFFFFB2` |
| Bullet marker `▸` | JetBrains Mono | 400 | 12px | 18px | 0 | `brandCyan` |
| Bullet texto | JetBrains Mono | 400 | 13px | 19.5px (1.5) | 0 | `#FFFFFFA6` |
| CTA label | JetBrains Mono | **700** | 12px | 18px | +1.2px | `bgBase` |

### 2.3 Espaçamento e Dimensões

| Token | Valor Figma | Flutter (`AppSpacing` / `FigmaDimensions`) |
|-------|------------|-------------------------------------------|
| Screen width | 393.545 px | frame width |
| Screen height | 851.519 px | frame height |
| Padding H | 23.998 px | `AppSpacing.xxl` ≈ `FigmaDimensions.screenPaddingH` |
| Progress bar height | 1.986 px | `FigmaDimensions.progressBarOnboarding` (2 px) |
| Top nav height | 49.982 px | `FigmaDimensions.topNavNoBack` (54.7 px — inclui margem) |
| Top nav padding H | 23.998 px | `FigmaDimensions.screenPaddingH` |
| Top nav padding V | 16 px | `AppSpacing.xl` |
| Coach dot size | 9.986 × 9.986 px | ~10 px |
| Icon container | 35.997 × 35.997 px | 36 px |
| Gap ícone-título | 15.999 px | `AppSpacing.xl` |
| Bottom actions height | 101.978 px | — |
| CTA button height | 49.982 px | `FigmaDimensions.ctaFullwidthMin` ≈ 46.954 |
| Gap CTA-dots | 15.999 px | `AppSpacing.xl` |
| Dot ativo width | 23.998 px | ~24 px |
| Dot inativo width | 5.986 px | ~6 px |
| Dot height | 4 px | `FigmaDimensions.progressBarPlan` |
| Dot gap | 7.999 px | `AppSpacing.md` |

### 2.4 Bordas

| Elemento | Largura | Cor |
|----------|---------|-----|
| Bullet feature card | 1.741 px | `rgba(255,255,255,0.08)` |
| (padrão global) | 1.735–1.741 px | `rgba(255,255,255,0.08)` ou `FigmaColors.borderDefault` |

> `1.741 px` no Figma é lido como `1.735 px` nos tokens Flutter (`AppDimensions.borderUniversal`). Usar `1.735` no código.

---

## 3. Componentes e seus Tokens

### `CoachSlideProgressBar`

```
height:      1.986 px  → 2 px
track:       #FFFFFF14 (rgba 8%)
fill:        #00D4FF
fill_width:  25% / 50% / 75% / 100% por slide
```

### `CoachIntroBreadcrumb` (Top Nav)

```
height:        49.982 px
padding_h:     23.998 px
padding_v:     16 px
dot_size:      9.986 px (quadrado)
dot_color:     #FF6B35
dot_opacity:   variável por slide: 83% / 62% / 70% / 36%
label_color:   #FF6B35
label_size:    12 px / tracking 1.8 px
skip_color:    #FFFFFF8C
skip_size:     12 px / weight 500 / tracking 1.2 px
```

### `CoachSlideLabel`

```
color:     #00D4FF
font_size: 12 px
tracking:  2.4 px
weight:    400
```

### `CoachFeatureBulletCard`

```
bg:        #FFFFFF08
border:    1.741 px / rgba(255,255,255,0.08)
padding_h: 15.999 px
padding_v: 11.999–12 px
gap:       11.999 px (marker ↔ texto)
marker:    "▸" / #00D4FF / 12 px
text:      #FFFFFFA6 / 13 px / leading 19.5 px
heights:   66.498 px (2 linhas) | 46.989 px (1 linha)
```

### `CoachSlideCTA`

```
height:    49.982 px
bg:        #00D4FF
text:      #050510 / Bold / 12 px / tracking 1.2 px
width:     full (self-stretch)
radius:    0 (zero border-radius)
```

### `CoachPageDots`

```
dot_active:   w 23.998 px / h 4 px / #00D4FF / pill
dot_visited:  w 5.986 px  / h 4 px / #FFFFFF33
dot_inactive: w 5.986 px  / h 4 px / #FFFFFF0F
gap:          7.999 px
radius:       pill (999)  ← exceção permitida ao zero-radius
```

---

## 4. Conteúdo por Slide

| Slide | nodeId | Label | Heading | CTA |
|-------|--------|-------|---------|-----|
| 1/4 | `1:5770` | `// QUEM SOU EU` | "Eu sou seu Coach.AI" | `CONTINUAR ↗` |
| 2/4 | `1:5818` | `// DURANTE A CORRIDA` | "Corro com você" | `CONTINUAR ↗` |
| 3/4 | `1:5870` | `// PRIMEIRA CORRIDA` | "Essa é a calibração" | `CONTINUAR ↗` |
| 4/4 | `1:5922` | `// SEU PLANO` | "Planejamento inteligente" | `[ VAMOS CORRER ] ↗` |

### Opacidade do dot laranja (Coach.AI indicator) por slide

| Slide | Opacidade |
|-------|-----------|
| 1/4 | 83.43% |
| 2/4 | 62.44% |
| 3/4 | 69.56% |
| 4/4 | 35.84% |

---

## 5. Mapeamento Flutter (`design_system_tokens.dart` / `app_palette.dart`)

```dart
// Cores → FigmaColors
FigmaColors.bgBase          = Color(0xFF050510)   // tela background
FigmaColors.brandCyan       = Color(0xFF00D4FF)   // primário
FigmaColors.brandOrange     = Color(0xFFFF6B35)   // Coach.AI
FigmaColors.textPrimary     = Color(0xFFFFFFFF)   // heading
FigmaColors.textSecondary   = Color(0x8CFFFFFF)   // "PULAR" (55%)
FigmaColors.textMuted       = Color(0x73FFFFFF)   // parágrafo (45%)
FigmaColors.surfaceCard     = Color(0x08FFFFFF)   // bullet card bg
FigmaColors.borderDefault   = Color(0x14FFFFFF)   // bullet card border / progress track
FigmaColors.dotActive       = Color(0xFF00D4FF)   // dot ativo
FigmaColors.dotVisited      = Color(0x33FFFFFF)   // dot visitado
FigmaColors.dotInactive     = Color(0x0FFFFFFF)   // dot inativo

// Espaçamento → AppSpacing
AppSpacing.xxl = 23.992    // padding horizontal de tela
AppSpacing.xl  = 15.995    // gap ícone-título, gap CTA-dots
AppSpacing.md  =  7.997    // gap entre dots

// Dimensões → FigmaDimensions / AppDimensions
FigmaDimensions.progressBarOnboarding = 2      // altura progress bar
AppDimensions.borderUniversal          = 1.735  // ≈ 1.741 Figma
AppDimensions.borderRadiusPill         = 999    // dots (única exceção zero-radius)
```
