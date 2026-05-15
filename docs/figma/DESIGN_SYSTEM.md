# Runnin.AI — Design System

> Consolidação completa de tokens, tipografia, componentes e padrões extraídos via MCP de todas as 13 seções do Figma (`gmfDCcbt5mQ4Yc6wa0PAye`).
> Fonte de verdade para a implementação Flutter — todos os valores são pixel-perfeitos do Figma.

---

## 1. Identidade Visual

- **Estilo:** Dark-mode exclusivo. Zero light mode.
- **Linguagem:** Terminal/tech — JetBrains Mono em todo o app, uppercase agressivo, tracking positivo.
- **Corners:** **Zero border-radius em todos os elementos** (exceto toggle pill — ver §5).
- **Borda universal:** `1.735px` em todo o app. Nunca 1px, nunca 2px.
- **Font-family único:** `JetBrains Mono` (Regular / Medium / Bold).

---

## 2. Paleta de Cores

### 2.1 Cores base

| Token | Hex / RGBA | Uso |
|---|---|---|
| `color/bg/base` | `#050510` | Background de todas as telas |
| `color/brand/cyan` | `#00d4ff` | Acento primário — CTAs, ativos, progresso, valores |
| `color/brand/orange` | `#ff6b35` | COACH.AI, acento secundário, tendências positivas de sono/recovery |

### 2.2 Texto

| Token | Hex / RGBA | Uso |
|---|---|---|
| `color/text/primary` | `#ffffff` | Títulos, valores principais |
| `color/text/secondary` | `rgba(255,255,255,0.55)` | Subtítulos, labels inativos, metadata |
| `color/text/muted` | `rgba(255,255,255,0.45)` | Notas secundárias |
| `color/text/dim` | `rgba(255,255,255,0.30)` | Frequência, labels terciários |
| `color/text/ghost` | `rgba(255,255,255,0.20)` | Botão Logout, delete button |
| `color/text/separator` | `rgba(255,255,255,0.12)` | Separador "/" no breadcrumb |
| `color/text/placeholder` | `rgba(255,255,255,0.50)` | Placeholder de inputs |

### 2.3 Superfícies

| Token | Hex / RGBA | Uso |
|---|---|---|
| `color/surface/card` | `rgba(255,255,255,0.03)` | Fundo padrão de cards/rows |
| `color/surface/card-cyan` | `rgba(0,212,255,0.03)` | Card conectado / badge desbloqueado |
| `color/surface/card-orange` | `rgba(255,107,53,0.03)` | Bloco Coach.AI |
| `color/surface/input` | `rgba(255,255,255,0.03)` | Background de campos de texto |

### 2.4 Bordas

| Token | Hex / RGBA | Uso |
|---|---|---|
| `color/border/default` | `rgba(255,255,255,0.08)` | Borda padrão de cards/rows |
| `color/border/cyan` | `rgba(0,212,255,0.14)` | Borda elementos ciano-tintados (chips, file icon) |
| `color/border/cyan-strong` | `rgba(0,212,255,0.19)` | Borda card conectado / badge desbloqueado |
| `color/border/cyan-active` | `#00d4ff` | Borda elemento ativo (tab, botão CTA) |
| `color/border/orange` | `#ff6b35` | Borda esquerda Coach.AI blocks |
| `color/border/input` | `rgba(255,255,255,0.08)` | Borda campos de input |
| `color/border/back-btn` | `rgba(255,255,255,0.10)` | Borda botão back |
| `color/border/upload-dashed` | `rgba(0,212,255,0.31)` | Borda tracejada do botão upload (único dashed no app) |

### 2.5 Estados interativos

| Token | Hex / RGBA | Uso |
|---|---|---|
| `color/selection/active/bg` | `rgba(0,212,255,0.10)` | Fundo opção selecionada (Assessment) |
| `color/selection/active/border` | `rgba(0,212,255,0.30)` | Borda opção selecionada |
| `color/info/bg` | `rgba(0,212,255,0.14)` | Background blocos de info ciano |
| `color/skin/active/bg` | `rgba(0,212,255,0.06)` | Skin card ativo |
| `color/dot/active` | `#00d4ff` | Dot ativo no page indicator |
| `color/dot/visited` | `rgba(255,255,255,0.20)` | Dots visitados |
| `color/dot/inactive` | `rgba(255,255,255,0.06)` | Dots inativos |

### 2.6 Navegação

| Token | Hex / RGBA | Uso |
|---|---|---|
| `color/nav/topbar/bg` | `rgba(5,5,16,0.92)` | Background TopNav (frosted) |
| `color/nav/bottombar/bg` | `rgba(5,5,16,0.96)` | Background BottomNav (frosted) |
| `color/nav/border` | `rgba(255,255,255,0.06)` | Borda top/bottom das navbars |
| `color/nav/btn/back/bg` | `rgba(255,255,255,0.06)` | Fundo botão back |
| `color/nav/active/indicator` | `#00d4ff` | Underline tab ativo (BottomNav) |
| `color/nav/run/shadow` | `rgba(0,212,255,0.31)` | Glow do botão RUN FAB |

### 2.7 Progress & Tracks

| Token | Hex / RGBA | Uso |
|---|---|---|
| `color/progress/track` | `rgba(255,255,255,0.05)` | Track de barras de progresso |
| `color/progress/fill` | `#00d4ff` | Fill padrão de progresso (ciano) |
| `color/badge/progress/fill` | `#00d4ff` | Fill barra de progresso de badge bloqueado |

### 2.8 Zonas de Corrida (canônicas)

| Zona | Cor | Uso |
|---|---|---|
| Z1 — Recuperação | `#3b82f6` | Cor da zona 1 em gráficos e cards |
| Z2 — Aeróbico base | `#22c55e` | Cor da zona 2 |
| Z3 — Aeróbico leve | `#eab308` | Cor da zona 3 |
| Z4 — Limiar | `#f97316` | Cor da zona 4 |
| Z5 — VO2max | `#ef4444` | Cor da zona 5 |

### 2.9 Skin Palettes (cores de tema do app)

| Palette | Cor primária | Cor secundária |
|---|---|---|
| SANGUE | `#ff2d2d` | `#4ea8ff` |
| MAGENTA | `#ff0066` | `#00e5ff` |
| VOLT | `#ccff00` | `#8b5cf6` |
| ÁRTICO (default) | `#00d4ff` | `#ff6b35` |

---

## 3. Tipografia

> Fonte única: **JetBrains Mono** em todos os pesos. Não existe nenhuma outra fonte no app.

### 3.1 Scale completa

| Token | Peso | Tamanho | Line-height | Tracking | Uso |
|---|---|---|---|---|---|
| `type/display/level` | Bold | 56px | 50.4px | — | Número de nível XP (GAMIFICAÇÃO) |
| `type/display/hero` | Bold | 48px | — | — | Valor hero (HIST, métricas principais) |
| `type/display/brand` | Bold | 28px | 42px | 3.36px | Logo principal (Splash) |
| `type/display/heading` | Bold | 28px | 28px | −0.84px | Heading principal, input numérico (Assessment) |
| `type/heading/section` | Bold | 24px | 24px | −0.48px | H2 Assessment |
| `type/heading/app` | Bold | 22px | 24.2px | −0.44px | Headings de seção no app (HOME, TREINO, HIST, PERFIL) |
| `type/heading/stat` | Bold | 22px | 24.2px | — | Valores gamificação (STREAK/XP/BADGES) |
| `type/heading/post-run` | Bold | 22px | — | — | Valores pós-corrida |
| `type/label/badge` | Bold | 12px | 18px | 0 | Badge ".AI" |
| `type/label/slide` | Regular | 12px | 18px | 1.8px | "// SLIDE_XX" |
| `type/label/assessment` | Regular | 13px | 19.5px | 1.95px | "// ASSESSMENT_XX" |
| `type/label/tagline` | Regular | 12px | 18px | 2.4px | Taglines onboarding |
| `type/label/slide-number` | Bold | 14px | 14px | −0.84px | Número do slide no heading |
| `type/label/nav` | Medium | 14px | 21px | 1.12px | Labels de navegação |
| `type/label/skip` | Medium | 13px | 19.5px | 1.3px | "PULAR", breadcrumbs |
| `type/label/field` | Medium | 11px | 16.5px | 1.65px | Labels de campos ALL CAPS |
| `type/label/metric` | Regular | 9px | 13.5px | 0.9px | Labels de métricas pequenas (body metrics row) |
| `type/body/main` | Regular | 15px | 25.5px | 0 | Corpo onboarding |
| `type/body/assessment` | Regular | 14px | 23.8px | 0 | Corpo blocos informativos Assessment |
| `type/body/app` | Regular | 13px | 19.5px | 0 | Corpo padrão no app |
| `type/body/small` | Regular | 12px | 18px | 0 | Chips, subtítulos secundários |
| `type/body/tiny` | Regular | 11px | 16.5px | 0 | Metadata, frequências |
| `type/body/micro` | Regular | 10px | 15px | 0 | Labels Coach análise |
| `type/card/title` | Bold | 13px | 19.5px | 0 | Títulos de cards |
| `type/card/description` | Regular | 12px | 18px | 0 | Descrições de cards |
| `type/cta/button` | Bold | 12px | 18px | 1.2px | CTAs principais |
| `type/cta/tab` | Bold | 12px | 18px | 1.2px | Labels de tabs (BADGES/XP/STREAK) |
| `type/cta/tab-small` | Bold | 11px | 16.5px | 0.66px | Labels de tabs 4-col (SAÚDE) |
| `type/header/logo` | Bold | 14px | 21px | 1.4px | "RUNNIN" no TopNav |
| `type/header/breadcrumb` | Regular | 13px | 19.5px | 1.3px | Breadcrumb no TopNav |
| `type/nav/bottombar` | Medium | 10px | 15px | 1px | Labels do BottomNav |
| `type/nav/run-fab` | Bold | 11px | 16.5px | 1.1px | Label "RUN" no FAB |
| `type/badge/premium` | Bold | 8px | 12px | — | Badge "PREMIUM" |
| `type/badge/dot` | Bold | 9px | 13.5px | — | Badge ".AI" |
| `type/badge/priority` | Bold | 9px | 13.5px | — | Badges ALTO/MÉDIO |
| `type/superscript` | Regular | 6.6px | — | — | Número de seção (superscript ciano) |

---

## 4. Espaçamento e Layout

### 4.1 Grid e margens

| Propriedade | Valor |
|---|---|
| Screen horizontal padding | `23.992px` (≈24px) |
| Content width (368px viewport) | `319.841px` |
| Borda universal | `1.735px` |
| Border-radius | `0` (exceto toggle) |

### 4.2 Gap system

| Token | Valor | Uso |
|---|---|---|
| `space/gap/xs` | `3.985px` | Gap entre cards em listas tight |
| `space/gap/sm` | `5.991px` | Gap exam cards, split cards |
| `space/gap/md` | `7.997px` | Gap interno de cards (ícone→texto) |
| `space/gap/lg` | `11.983px` | Gap ícone→info em device/exam cards |
| `space/gap/xl` | `15.995px` | Gap avatar→info, entre seções próximas |
| `space/gap/section` | `23.992px` | Gap entre seções principais |

### 4.3 Padding interno de cards

| Contexto | Valor |
|---|---|
| Card padrão (menu, XP rows) | `13.718px` |
| Card skin palette | `17.73px` |
| Card level XP | `21.715px` |
| Card assessment | `~16px` |

### 4.4 Alturas de componentes

| Componente | Altura |
|---|---|
| TopNav (sem back button) | `54.708px` |
| TopNav (com back button) | `73.712px` |
| BottomNav | `78.591–79px` |
| Botão back | `39.987px` (quadrado) |
| Tab selector 3 abas | `41.424px` |
| Tab selector 4 abas | `39.933px` |
| Botão CTA fullwidth padrão | `46.954–56.5px` |
| Botão CTA assessment | `56.5px` |
| Metric card (SAÚDE/HIST) | `85.45px` |
| Zone card | `58.937px` |
| Badge card (1 linha) | `91.848px` |
| Device card connect | `223.303px` |
| Toggle pill | `19.98 × 35.975px` |
| Progress bar fina | `3.985px` (badges) |
| Progress bar média | `5.991px` (skin) |
| Progress bar espessa | `7.997px` (XP level, zones) |
| Progress bar onboarding | `2px` (no topo da tela) |
| Progress bar plan | `4px` |

---

## 5. Componentes — Catálogo Completo

> Todos os componentes têm `border-radius: 0` exceto onde explicitamente indicado.

### 5.1 Navegação Global

#### `TopNav` (2 variantes)
- **Sem back button** (h=54.708px): Logo + breadcrumb à direita. Usado na tela principal de cada seção (HOME, TREINO, HIST, PERFIL raiz).
- **Com back button** (h=73.712px): Back button 39.987px + logo + breadcrumb. Todas as sub-telas.
- Fundo: `rgba(5,5,16,0.92)`, borda inferior 1.735px `rgba(255,255,255,0.06)`
- Logo "RUNNIN": Bold 14px, `#ffffff`, tracking 1.4px
- Badge ".AI": bg `#00d4ff`, texto `#050510`, Bold 9px, px 6px py 2px
- Separador "/": Regular 12px, `rgba(255,255,255,0.12)`
- Breadcrumb: Regular 13px, `rgba(255,255,255,0.55)`, tracking 1.3px

#### `BottomNav` (5 tabs)
- h=78.591px, bg `rgba(5,5,16,0.96)`, borda superior 1.735px `rgba(255,255,255,0.06)`
- Tabs: HOME / TREINO / RUN (FAB) / HIST / PERFIL
- Tab inativo: ícone + label Medium 10px, `rgba(255,255,255,0.55)`, tracking 1px
- Tab ativo: label `#ffffff` + underline `#00d4ff` 1.979 × 19.98px
- **RUN FAB:** 55.982px quadrado, bg `#00d4ff`, shadow `0px 0px 30px rgba(0,212,255,0.31)` + `0px 4px 20px rgba(0,0,0,0.5)`, label Bold 11px `#050510` tracking 1.1px; anel externo 2px `#00d4ff` ~25% opacity

---

### 5.2 Onboarding

| Componente | Especificação |
|---|---|
| `OnboardingTopProgressBar` | Barra 2px no topo; fill ciano proporcional (N/13) |
| `OnboardingHeader` | Logo + "PULAR" à direita; variante com/sem "VOLTAR" à esquerda |
| `OnboardingSlideLabel` | "// SLIDE_XX" — ciano 12px Regular tracking 1.8px |
| `OnboardingHeading` | Título branco 28px Bold + número do slide ciano 14px Bold (top-right) |
| `OnboardingFeatureCard` | Ícone 22px + título Bold 13px + descrição Regular 12px; borda sutil |
| `OnboardingContinueButton` | CTA ciano fullwidth "CONTINUAR ↗"; Bold 12px tracking 1.2px |
| `OnboardingPageIndicator` | 13 dots: ativo 20×4px ciano, visitado 6×4px 20% branco, inativo 6×4px 6% branco |

---

### 5.3 Forms / Input

| Componente | Especificação |
|---|---|
| `FormFieldLabel` | ALL CAPS 11px Medium tracking 1.65px, `rgba(255,255,255,0.55)` |
| `FormTextField` | h=48.5px, bg `rgba(255,255,255,0.03)`, borda 1.735px `rgba(255,255,255,0.08)`, placeholder muted |
| `OtpTextField` | Variante FormTextField — placeholder "_ _ _ _ _ _" tracking 4.2px |
| `GoogleSignInButton` | Outline escuro `rgba(255,255,255,0.05)`, ícone Google 16px, texto branco |
| `NumericInputField` | Valor Bold 28px + unidade 14px + setas ± |

---

### 5.4 Assessment / Seleção

| Componente | Especificação |
|---|---|
| `AssessmentLabel` | "// ASSESSMENT_XX" — ciano 13px Regular tracking 1.95px |
| `AssessmentHeading` | H2 Bold 24px tracking −0.48px |
| `CoachAIBlock` | Borda esquerda 2px `#ff6b35`, bg `rgba(255,107,53,0.06)` |
| `CyanInfoBlock` | Borda 1px `rgba(0,212,255,0.14)`, texto branco 14px |
| `SelectionButton` | Fullwidth 56.5px; selecionado: borda `rgba(0,212,255,0.30)` + bg `rgba(0,212,255,0.10)` |
| `TimePeriodCard` | 109.8×138.5px — seleção manhã/tarde/noite |
| `HealthChip` | Multi-select, largura variável; condições de saúde |

---

### 5.5 Plan Loading

| Componente | Especificação |
|---|---|
| `CoachAIBreadcrumb` | `[■] COACH.AI > {AÇÃO}` — quadrado laranja 10px + texto orange 12px tracking 1.8px |
| `PlanTaskRow` | 3 estados (done ✓ / active ● / pending ○); label + texto + sub-detalhe |
| `PlanProgressBar` | Track 4px + fill ciano animado; sem border-radius, sem label % |

---

### 5.6 Home & Notificações

| Componente | Especificação |
|---|---|
| `SectionHeading` | Bold 22px + superscript 6.6px ciano — padrão universal de todas as seções |
| `CoachAICard` | Left-border laranja/ciano, breadcrumb, corpo; variante com/sem botões |
| `NotificationCard` | Left-border por categoria (5 cores), ícone + título + sub + time |
| `WeeklyDayGrid` | 7 colunas, 3 estados (✓ completo / HOJE / futuro dim) |
| `MetricCard` | Label 11px + valor 28px Bold (colorido) + delta + sub; variante sólido ciano |
| `AlertToggleRow` | Título + sub + pill toggle ON/OFF à direita |
| `BadgeChip` | Chip ciano-tintado, ícone 18px + texto 13px, borda `rgba(0,212,255,0.25)` |

---

### 5.7 Run Journey (sessão ativa)

| Componente | Especificação |
|---|---|
| `RunMetricCell` | Label + superscript 9px ciano + valor 28px + unidade; grade 2×2 no HUD |
| `ZoneBar` | 5 zonas Z1–Z5 com cores canônicas e barra proporcional |
| `SplitCard` | KM## + tempo (OK=laranja, PEND=dim), scroll horizontal |
| `SplitRow` | KM label + barra (melhor=ciano, outros=dim) + tempo |
| `BadgeUnlockModal` | Overlay escuro + card top/bottom ciano, badge icon com anéis concêntricos |
| `PostRunStatCard` | Label + valor 22px Bold (colorido) + unidade, grade 3 colunas |
| `ShareCardPreview` | Card branded ciano-bordado, distância hero 48px, mapa SVG, stats |
| `PhotoOverlayChip` | Label + valor sobre foto, bg `rgba(5,5,16,0.60)` |
| `OverlayDataToggleChip` | Multi-select: ativo=ciano tintado+✓, inativo=dim |

---

### 5.8 Treino

| Componente | Especificação |
|---|---|
| `WeekPlanRow` | Linha do dia: estado OK/HOJE/FUTURO/DESCANSO + nome + detalhes |
| `TrainingStatsRow` | Row com VOLUME + SESSÕES + DESCANSO em 3 tiles |
| `MonthWeekCard` | Card de semana: foco/volume/status + barra de volume |
| `ReportCard` | ADERÊNCIA/KM/SESSÕES/FREE + preview coach |
| `ProgressDetailCard` | Card aderência com valor 48px + métricas row |
| `ChangeRequestGrid` | Grade 2 colunas de botões de seleção |
| `CoachChatBubble` | Bubble de mensagem Coach ou usuário; Coach tem breadcrumb laranja |
| `CoachOptionButton` | Botão de opção inline no chat (borda ciano, fullwidth) |
| `AjusteHistoryEntry` | Linha de histórico de ajuste com data + descrição + tag |

---

### 5.9 Histórico

| Componente | Especificação |
|---|---|
| `HistStatCard` | 2-col grid, Label + valor 28px Bold (colorido) + delta; 10 cards |
| `ZoneDistributionBar` | Barra empilhada 5 zonas + tabela de % |
| `ChartLineSpark` | Gráfico de linha (volume/pace/BPM) — SVG |
| `RunCard` | Badge de tipo 40px + stats row + preview coach clipped |
| `RunDetailMetricRow` | 3-col cards de métricas pós-corrida |
| `SplitBarRow` | KM label + barra horizontal (melhor=ciano, outros=dim) + tempo |
| `BenchmarkBellCurve` | Curva normal SVG + posição do usuário |
| `BenchmarkMetricRow` | Valor usuário ciano vs comparação muted |

---

### 5.10 Perfil

| Componente | Especificação |
|---|---|
| `UserProfileHeader` | Avatar + nome + nível + badge PREMIUM + stats de corrida |
| `GamificationStatsRow` | 3 tiles STREAK/XP/BADGES — Bold 22px |
| `BodyMetricsRow` | 4 tiles PESO/ALTURA/IDADE/FREQ — valor 16px + unidade 9px |
| `SkinPaletteCard` | Card 2×2 com swatches + barra tri-segmentada; ativo/inativo |
| `ProfileMenuRow` | Ícone 20px + título Medium 14px + sub + "↗" |
| `BadgeCard` | Ícone + título + descrição; bloqueado = opacity 50% + progress bar |
| `XPLevelCard` | Número nível 56px Bold + label + XP fraction + barra 7.997px |
| `XPEarningRow` | Ação texto branco + valor Bold ciano (space-between) |
| `StreakCalendarGrid` | Grid 7×4, células ~40.9px; gradiente opacity nas ativas |
| `HealthMetricCard` | 345.867×85.45px — valor 28px + tendência 13px (ciano ou laranja) |
| `ZoneCard` | 58.937px — cor zona + label + range BPM + % + barra 7.997px |
| `DeviceConnectedCard` | Borda ciano, dot de status, chips de dado, sync button |
| `DataPermissionToggleRow` | Título + sub + toggle pill ON/OFF |
| `CompatibleDeviceCard` | Ícone + plataforma + dados + "Conectar ↗" |
| `ExamCard` | Ícone-doc + título + arquivo + chip tamanho + data + análise Coach |
| `ExamUploadCTA` | Borda dashed ciano — único elemento dashed no app |
| `RecommendedExamCard` | Ícone + nome + badge ALTO/MÉDIO + descrição + frequência |

---

### 5.11 Estados de Componentes

#### Tab Selector (2 variantes: 3-col e 4-col)
```
ATIVO:   bg=#00d4ff | borda 1.735px #00d4ff | texto #050510 Bold
INATIVO: bg=transparent | borda 1.735px rgba(255,255,255,0.08) | texto rgba(255,255,255,0.55) Bold
```

#### Toggle Pill
```
ON:  bg=#00d4ff | thumb #050510 | border-radius: 100 (fully rounded — único no app)
OFF: bg=rgba(255,255,255,0.1) | thumb rgba(255,255,255,0.3)
Tamanho: 35.975 × 19.98px | thumb: 15.995px
```

#### Badge Card (Gamificação)
```
DESBLOQUEADO: bg=rgba(0,212,255,0.03) | borda rgba(0,212,255,0.19) | opacity 100%
BLOQUEADO:    bg=rgba(255,255,255,0.03) | borda rgba(255,255,255,0.08) | opacity 50% + progress bar
```

#### Skin Card (Perfil)
```
ATIVO:  bg=rgba(0,212,255,0.06) | borda #00d4ff | label #ffffff | badge "ATIVA" ciano
INATIVO: bg=rgba(255,255,255,0.03) | borda rgba(255,255,255,0.08) | label rgba(255,255,255,0.55)
```

#### CoachAI Block (variantes por contexto)
```
Assessment:  bg=rgba(255,107,53,0.06) | borda esquerda 2px #ff6b35
App geral:   bg=rgba(255,107,53,0.03) | borda esquerda 1.735px #ff6b35
Dentro de card (exames): bg=rgba(255,107,53,0.02) | borda esquerda 1.735px #ff6b35
```

---

## 6. Padrões de Layout

### 6.1 Estrutura de tela padrão
```
┌──────────────────────────────────┐
│ TopNav (54.708px ou 73.712px)    │
├──────────────────────────────────┤
│ [Tab Selector — opcional]        │
│ (39.933px ou 41.424px)           │
├──────────────────────────────────┤
│                                  │
│  Conteúdo scrollável             │
│  padding: 23.992px horiz         │
│  gap seções: 23.992px            │
│                                  │
├──────────────────────────────────┤
│ BottomNav (78.591px)             │
└──────────────────────────────────┘
```

### 6.2 Section Heading padrão
```dart
Row(
  children: [
    Text("SEÇÃO", style: Bold 22px #ffffff tracking -0.44px),
    Text("01", style: Regular 6.6px #00d4ff),  // superscript
  ]
)
Text("Subtítulo opcional", style: Regular 13px rgba(255,255,255,0.55))
```

### 6.3 Card Row padrão
```dart
Container(
  width: 319.841,
  decoration: BoxDecoration(
    color: Color(0x08FFFFFF),  // rgba(255,255,255,0.03)
    border: Border.all(color: Color(0x14FFFFFF), width: 1.735),
    // border-radius: 0 (padrão)
  ),
  padding: EdgeInsets.all(13.718),
)
```

### 6.4 Coach.AI Block (borda apenas esquerda)
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0x08FF6B35),  // rgba(255,107,53,0.03)
    border: Border(
      left: BorderSide(color: Color(0xFFFF6B35), width: 1.735),
    ),
  ),
)
```

### 6.5 Borda dashed (upload)
```dart
// Único caso de borda dashed no app — usar CustomPainter ou pacote dashed_border
Container(
  decoration: BoxDecoration(
    color: Color(0x0500D4FF),  // rgba(0,212,255,0.02)
    // Borda: 1.735px dashed rgba(0,212,255,0.31)
  ),
)
```

---

## 7. Iconografia

- **Tamanhos usados:** 16px, 18px, 19.98px, 21.986px, 22px, 28px
- **Formato:** SVG assets (não icon font)
- **Cor:** herdada do contexto (branco, ciano, ou laranja dependendo do estado)
- **Back button icon:** 21.986 × 21.986px (chevron/arrow)
- **Nav icons:** 17.974 × 17.974px (BottomNav)
- **BottomNav RUN:** sem ícone, apenas texto "RUN"

---

## 8. Animações e Efeitos

| Efeito | Especificação |
|---|---|
| **RUN FAB glow** | `box-shadow: 0px 0px 30px rgba(0,212,255,0.31)` |
| **RUN FAB shadow** | `box-shadow: 0px 4px 20px rgba(0,0,0,0.5)` |
| **Streak calendar** | Gradiente de opacidade 30%–94% nas células ativas |
| **TopNav frosted** | `rgba(5,5,16,0.92)` — simula blur backdrop |
| **BottomNav frosted** | `rgba(5,5,16,0.96)` — simula blur backdrop |
| **Plan Loading progress** | Fill animado (implícito — nenhum valor de duração no Figma) |
| **Badge Unlock Modal** | Overlay escuro + anéis concêntricos (pulse implícito) |

---

## 9. Lacunas e Pendências

### 9.1 Tokens não publicados
`get_variable_defs` retornou vazio — tokens do Figma não publicados. Todos os valores foram extraídos diretamente dos nós. Recomenda-se publicar tokens no Figma para sincronização futura.

### 9.2 Telas não extraídas (pendentes)
Ver `JOURNEYS.md` — seção "Telas Pendentes".

### 9.3 Comportamentos implícitos (sem especificação no Figma)
- Duração e curva de animações (progress bars, transições de tela)
- Estados de erro nos forms (LOGIN, Assessment inputs)
- Estados de loading de telas
- Pull-to-refresh
- Scroll behavior (sticky headers vs scroll-along)
- Haptic feedback
