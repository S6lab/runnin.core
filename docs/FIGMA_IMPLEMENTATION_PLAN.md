# Plano de Implementação: Alinhamento Figma → Código

**Data:** 2026-05-14  
**Autor:** CTO  
**Status:** Análise Completa — Aguardando Aprovação

---

## 1. Resumo Executivo

### 1.1 Objetivo
Alinhar completamente a implementação Flutter com o design system extraído do Figma, garantindo máxima fidelidade visual e consistência de componentes.

### 1.2 Escopo da Análise
- **Documentação Figma:** 3 arquivos principais (DESIGN_SYSTEM.md, JOURNEYS.md, README.md)
- **Telas documentadas:** 26 screens completos + 13 passos de onboarding
- **Componentes catalogados:** 60+ componentes únicos
- **Tokens extraídos:** 69 tokens de cor + 32 estilos tipográficos

### 1.3 Situação Atual
O app possui implementação funcional com navegação, features principais e backend integrado. Porém há **divergências significativas** entre o design system do Figma e a implementação atual em termos de:
- Tipografia (fonte, tamanhos, tracking)
- Paleta de cores e opacidades
- Componentes e estados
- Espaçamento e dimensões
- Identidade visual (zero border-radius vs uso de bordas arredondadas)

---

## 2. Análise Comparativa: Figma vs Código

### 2.1 Sistema de Design

#### 2.1.1 Tipografia

**FIGMA (Fonte Canônica):**
- **Font-family único:** JetBrains Mono (Regular / Medium / Bold)
- **32 estilos tipográficos** pixel-perfect
- **Tracking agressivo:** uppercase com 1.2px–3.36px
- **Zero outras fontes** no app inteiro

**CÓDIGO ATUAL:**
- ✅ JetBrains Mono presente via `google_fonts`
- ❌ **Mistura de fontes:** Inter, Barlow, JetBrains Mono
- ❌ `app_theme.dart` usa `GoogleFonts.interTextTheme()` e `GoogleFonts.barlow()` como padrão
- ❌ Estilos tipográficos não mapeados 1:1 com Figma
- ❌ Tracking values divergentes

**GAP CRÍTICO:**
```dart
// ATUAL (app_theme.dart linha 12-15)
final textTheme = GoogleFonts.interTextTheme(base.textTheme)
  .apply(bodyColor: palette.text, displayColor: palette.text);

// FIGMA REQUER
final textTheme = GoogleFonts.jetBrainsMonoTextTheme(base.textTheme)
  .apply(bodyColor: palette.text, displayColor: palette.text);
```

#### 2.1.2 Paleta de Cores

**FIGMA (Tokens Canônicos):**
- `color/bg/base`: `#050510` (dark exclusivo)
- `color/brand/cyan`: `#00d4ff` (acento primário)
- `color/brand/orange`: `#ff6b35` (Coach.AI)
- **Opacidades específicas:** 55%, 45%, 30%, 20%, 12%, 08%, 06%, 03%
- **Skin "Cyber"** é a paleta padrão, idêntica ao "ÁRTICO" do código

**CÓDIGO ATUAL:**
- ✅ `RunninSkin.cyber` existe com valores corretos
- ❌ Paleta padrão é `RunninSkin.artico` (linha 86 app_theme.dart)
- ⚠️ Valores numéricos **quase** corretos mas pequenas diferenças:
  - Figma `#050510` vs Código `#060814` (artico bg)
  - Figma `#00d4ff` vs Código `#2ECDF3` (artico primary)

**GAP:**
```dart
// ATUAL (app_palette.dart linha 245-260)
case RunninSkin.cyber:
  return const RunninPalette(
    background: Color(0xFF050510), // ✅ CORRETO
    primary: Color(0xFF00D4FF),     // ✅ CORRETO
    secondary: Color(0xFFFF6B35),   // ✅ CORRETO
    // ...
  );

// MAS: linha 86 de app_theme.dart
static ThemeData get dark => build(RunninSkin.artico.palette); // ❌ DEVERIA SER .cyber
```

#### 2.1.3 Border-Radius

**FIGMA:**
- **Zero border-radius** em todos os elementos (exceto toggle pill)
- Identidade visual: cantos retos, estética terminal/tech

**CÓDIGO ATUAL:**
- ❌ `BorderRadius.circular(999)` usado em:
  - BottomNav RUN FAB (main_layout.dart:87)
  - Skin cards (profile_page.dart várias linhas)
  - Hydration sheet (home_page.dart:1902)
- ❌ `BorderRadius.zero` presente mas não universal

**GAP CRÍTICO:**
Design system inteiro depende de cantos retos. Uso de `circular()` quebra a identidade.

#### 2.1.4 Borda Universal

**FIGMA:**
- **1.735px** em todos os cards/rows/inputs
- Nunca 1px, nunca 2px

**CÓDIGO ATUAL:**
- ❌ Valores variados: `1px`, `1.5px`, `1.735px`, `2px`, `3px`
- ⚠️ Inconsistente entre componentes

**Exemplo:**
```dart
// main_layout.dart linha 41
border: Border(top: BorderSide(color: palette.border, width: 1.5)), // ❌ DEVERIA SER 1.735
```

---

### 2.2 Componentes

#### 2.2.1 Navegação Global

| Componente | Figma | Código | Status |
|------------|-------|--------|--------|
| **TopNav** | 2 variantes (54.7px / 73.7px) | `AppPageHeader` customizado | ⚠️ Estrutura diferente |
| **BottomNav** | 5 tabs + RUN FAB | `_BottomNav` em main_layout.dart | ⚠️ Existe mas dimensões divergem |
| **RUN FAB** | 55.982px quadrado, shadow específico | 56px circular | ❌ Shape errado (circular vs quadrado) |

**GAP TopNav:**
- Figma: Logo "RUNNIN" + badge ".AI" + breadcrumb
- Código: Vários headers customizados, sem padrão consistente

**GAP RUN FAB:**
```dart
// ATUAL (main_layout.dart:82-95)
Container(
  width: 56, height: 56,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(999), // ❌ DEVERIA SER 0
    // ...
  )
)

// FIGMA REQUER
Container(
  width: 55.982, height: 55.982,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.zero, // ✅ Quadrado
    boxShadow: [
      BoxShadow(color: #00D4FF @ 31%, blurRadius: 30, offset: Offset(0,0)),
      BoxShadow(color: #000 @ 50%, blurRadius: 20, offset: Offset(0,4)),
    ],
  ),
)
```

#### 2.2.2 Cards e Panels

**FIGMA:**
- `AppPanel` padrão: bg `rgba(255,255,255,0.03)`, borda `rgba(255,255,255,0.08)`, padding `13.718px`
- `CoachAIBlock`: borda **apenas esquerda** 1.735px `#ff6b35`, bg `rgba(255,107,53,0.03)`
- Estados claros: default / cyan-tinted / orange-tinted

**CÓDIGO ATUAL:**
- ✅ `AppPanel` existe (shared/widgets/app_panel.dart)
- ⚠️ Usado mas valores de padding/border divergem
- ❌ CoachAIBlock não é componente reutilizável, implementado inline

**GAP:**
Falta biblioteca de componentes atômicos. Cada tela reimplementa blocos similares.

#### 2.2.3 Forms / Input

| Componente Figma | Código Atual | Status |
|------------------|--------------|--------|
| `FormFieldLabel` (11px Medium, 1.65ls) | Labels variados | ❌ Sem padrão |
| `FormTextField` (h=48.5px, bg 03%, border 08%) | TextField material | ⚠️ Theme genérico |
| `NumericInputField` (28px Bold + setas ±) | Não existe | ❌ Faltando |
| `SelectionButton` (56.5px fullwidth) | Chips customizados | ⚠️ Diverge |

#### 2.2.4 Gamificação

**FIGMA:**
- `BadgeCard` com estados locked/unlocked + progress bar 3.985px
- `XPLevelCard` com número 56px Bold + barra 7.997px
- `StreakCalendarGrid` 7×4 com gradiente opacity

**CÓDIGO ATUAL:**
- ✅ `GamificationPage` existe e funcional
- ✅ `AchievementCard` existe
- ❌ Dimensões e estilos divergem do Figma
- ❌ Progress bars usam tema Material, não custom heights

---

### 2.3 Telas Principais

#### HOME

**FIGMA:**
- Header: Logo + breadcrumb + avatar
- WeeklyDayGrid: 7 colunas com estados (✓/HOJE/futuro)
- Coach.AI card com borda esquerda laranja
- Métricas com superscript ciano 6.6px

**CÓDIGO ATUAL:**
- ✅ Estrutura similar implementada
- ❌ Tipografia diverge (Inter/Barlow vs JetBrains Mono)
- ❌ WeekGrid existe mas estilo diferente
- ⚠️ Coach card inline, não componente

**Fidelidade Visual:** ~60%

#### PERFIL

**FIGMA:**
- UserProfileHeader com avatar + nível + stats
- GamificationStatsRow (STREAK/XP/BADGES) 3 tiles
- BodyMetricsRow (PESO/ALTURA/IDADE/FREQ) 4 tiles
- Skin palette selector 2×2 grid

**CÓDIGO ATUAL:**
- ✅ Estrutura completa implementada
- ✅ Skin selector funcional
- ❌ Layout diverge (cards vs row de stats)
- ❌ Tipografia/spacing diferentes

**Fidelidade Visual:** ~65%

#### TREINO

**FIGMA:**
- Plano Semanal: lista 7 dias com estados
- Tab selector 3-col (h=41.424px)
- Stats row: VOLUME/SESSÕES/DESCANSO
- Coach chat com bubbles + opções inline

**CÓDIGO ATUAL:**
- ✅ TrainingPage existe e funcional
- ⚠️ Estrutura básica presente
- ❌ Componentes visuais divergem significativamente
- ❌ Coach chat não implementado na UI

**Fidelidade Visual:** ~50%

#### HISTÓRICO

**FIGMA:**
- Tab 3-col (SEMANA/MÊS/3MESES)
- 10 stat cards 2-col
- Zone distribution bar empilhada
- Gráficos SVG de linha

**CÓDIGO ATUAL:**
- ✅ HistoryPage existe com tabs
- ✅ MetricCards existem
- ❌ Zone bar não implementada
- ❌ Charts usam lib externa, não SVG custom

**Fidelidade Visual:** ~55%

#### GAMIFICAÇÃO

**CÓDIGO ATUAL:**
- ✅ Página completa implementada
- ✅ 17 badges definidos
- ✅ XP/Streak tabs funcionais
- ❌ Visual diverge do Figma (borders, spacing, colors)

**Fidelidade Visual:** ~60%

---

### 2.4 Componentes Ausentes

Componentes do Figma **não implementados:**

1. **Onboarding (13 passos):**
   - `OnboardingTopProgressBar`
   - `OnboardingSlideLabel` ("// SLIDE_XX")
   - `OnboardingHeading` (número ciano no canto)
   - `OnboardingPageIndicator` (13 dots com 3 estados)

2. **Assessment (9 telas):**
   - `AssessmentLabel` ("// ASSESSMENT_XX")
   - `AssessmentHeading` (H2 24px)
   - `CoachAIBlock` (componente reutilizável)
   - `CyanInfoBlock`
   - `TimePeriodCard` (seleção manhã/tarde/noite)
   - `HealthChip` (multi-select)

3. **Plan Loading:**
   - `CoachAIBreadcrumb` ("[■] COACH.AI > {AÇÃO}")
   - `PlanTaskRow` (3 estados: done/active/pending)
   - `PlanProgressBar` (4px sem label)

4. **Run Journey:**
   - `RunMetricCell` (HUD 2×2)
   - `ZoneBar` (5 zonas Z1-Z5)
   - `SplitCard` (scroll horizontal)
   - `BadgeUnlockModal` (overlay + anéis)
   - `ShareCardPreview`
   - `PhotoOverlayChip`

5. **Treino:**
   - `WeekPlanRow` (OK/HOJE/FUTURO/DESCANSO)
   - `MonthWeekCard`
   - `CoachChatBubble` (bubbles + breadcrumb)
   - `CoachOptionButton`
   - `AjusteHistoryEntry`

6. **Histórico:**
   - `ZoneDistributionBar` (barra empilhada + tabela %)
   - `ChartLineSpark` (gráfico SVG)
   - `BenchmarkBellCurve`
   - `BenchmarkMetricRow`

7. **Perfil:**
   - `ZoneCard` (58.937px, cor + label + range + % + barra)
   - `DeviceConnectedCard`
   - `ExamCard`
   - `ExamUploadCTA` (borda dashed — único dashed no app)
   - `RecommendedExamCard`

**Total:** ~40 componentes específicos do Figma não implementados como reutilizáveis.

---

### 2.5 Telas Pendentes

Telas do Figma **não extraídas/implementadas:**

1. **PERFIL > AJUSTES (3 telas estimadas):**
   - Coach settings
   - Alertas/Notificações
   - Unidades (km/milhas, métricas)

2. **PERFIL > ASSINATURA (1 tela):**
   - Premium upgrade flow

3. **PERFIL > Editar Perfil (1 tela):**
   - Edição inline de dados

4. **Estados globais:**
   - Empty states (HIST sem corridas, BADGES todos bloqueados)
   - Error states (falha conexão)
   - Loading states (skeletons)

**Total:** ~5-7 telas adicionais

---

## 3. Gaps Críticos Identificados

### 3.1 Nível Crítico (Bloqueiam Fidelidade Visual)

1. **Tipografia mista** (Inter + Barlow + JetBrains Mono)
   - Impacto: 100% das telas
   - Esforço: Médio (refactor theme + update all widgets)

2. **Border-radius inconsistente** (circular vs zero)
   - Impacto: Identidade visual quebrada
   - Esforço: Médio (update all containers)

3. **Paleta padrão errada** (artico vs cyber)
   - Impacto: Cores ligeiramente off em toda UI
   - Esforço: Baixo (1 linha)

4. **Borda 1.735px não universal**
   - Impacto: Precisão visual comprometida
   - Esforço: Médio (update all borders)

### 3.2 Nível Alto (Degradam Experiência)

5. **TopNav inconsistente** (sem padrão global)
   - Impacto: Navegação confusa
   - Esforço: Médio (criar componente unificado)

6. **RUN FAB shape errado** (circular vs quadrado)
   - Impacto: Elemento mais visível da UI
   - Esforço: Baixo (fix shape + shadows)

7. **Componentes não reutilizáveis** (inline everywhere)
   - Impacto: Manutenibilidade ruim
   - Esforço: Alto (extrair ~40 componentes)

8. **Spacing values não padronizados** (gap system ignorado)
   - Impacto: Layout "quase certo" mas inconsistente
   - Esforço: Alto (aplicar gap system em todas as telas)

### 3.3 Nível Médio (Features Incompletas)

9. **Onboarding não implementado** (13 passos + components)
   - Impacto: Primeira impressão comprometida
   - Esforço: Alto (13 telas + flows)

10. **Run Journey incompleto** (HUD, zones, splits)
    - Impacto: Feature core do app
    - Esforço: Alto (sessão ativa + pós-run)

11. **Coach Chat UI ausente** (bubbles + options)
    - Impacto: Interação IA limitada a cards
    - Esforço: Médio (chat UI + integration)

12. **Zona cardíaca não visualizada** (ZoneBar, ZoneCard)
    - Impacto: Feature diferencial não explorada
    - Esforço: Médio (5 componentes de zona)

### 3.4 Nível Baixo (Polish e Consistência)

13. **Telas PERFIL > Ajustes pendentes**
14. **Empty/Error states genéricos**
15. **Animations não especificadas**
16. **Loading states sem skeleton**

---

## 4. Plano de Implementação

### 4.1 Princípios Orientadores

1. **Fidelidade Pixel-Perfect:** Valores exatos do Figma, sem aproximações
2. **Componentes Atômicos:** Extrair reutilizáveis desde o início
3. **Migrations Seguras:** Manter app funcional a cada passo
4. **Teste Visual:** Comparar screenshots Figma vs App
5. **Zero Regressões:** Features existentes continuam funcionando

### 4.2 Estratégia de Abordagem

#### Opção A: Big Bang Refactor (NÃO RECOMENDADO)
- Reescrever todo design system de uma vez
- **Risco:** 2-3 semanas de app quebrado
- **Vantagem:** Consistência total no final

#### Opção B: Incremental Layer-by-Layer (RECOMENDADO)
- Camada 1: Fundações (theme, tokens, utils)
- Camada 2: Componentes atômicos
- Camada 3: Migração tela-por-tela
- **Risco:** Baixo, app sempre funcional
- **Vantagem:** Deploy contínuo, feedback rápido

**DECISÃO:** Opção B com 5 fases progressivas.

---

### 4.3 Fases de Implementação

## FASE 1: Fundações do Design System (3-5 dias)

**Objetivo:** Alinhar tokens, theme e utilitários base sem quebrar UI existente.

### 1.1 Tokens de Cor
- [ ] Criar `app/lib/core/theme/figma_tokens.dart`
  - 69 tokens de cor documentados
  - Usar valores exatos do Figma (rgba com opacidades específicas)
  - Organizados por categoria (bg, text, surface, border, etc.)

- [ ] Atualizar `RunninSkin.cyber` como padrão
  - Alterar linha 86 de `app_theme.dart`: `artico` → `cyber`
  - Validar que `cyber` tem valores exatos do Figma

### 1.2 Tipografia
- [ ] Criar `FigmaTypography` class
  - 32 estilos tipográficos mapeados 1:1
  - Todos com JetBrains Mono
  - Tracking values exatos

- [ ] Refatorar `app_theme.dart`
  - Substituir `GoogleFonts.interTextTheme()` por `jetBrainsMonoTextTheme()`
  - Remover referências a Barlow
  - Aplicar `FigmaTypography` ao theme

- [ ] Garantir `pubspec.yaml` tem JetBrains Mono
  - Verificar se `google_fonts: ^6.2.1` baixa a fonte corretamente

### 1.3 Constantes de Layout
- [ ] Criar `app/lib/core/theme/figma_dimensions.dart`
  ```dart
  abstract class FigmaDimensions {
    // Border
    static const borderUniversal = 1.735;
    
    // Gap system
    static const gapXs = 3.985;
    static const gapSm = 5.991;
    static const gapMd = 7.997;
    static const gapLg = 11.983;
    static const gapXl = 15.995;
    static const gapSection = 23.992;
    
    // Screen padding
    static const screenPaddingH = 23.992;
    
    // Heights
    static const topNavNoBack = 54.708;
    static const topNavWithBack = 73.712;
    static const bottomNav = 78.591;
    static const runFab = 55.982;
    // ... etc
  }
  ```

### 1.4 Border-Radius Strategy
- [ ] Criar `FigmaBorderRadius` utility
  ```dart
  abstract class FigmaBorderRadius {
    static const zero = BorderRadius.zero; // padrão universal
    static const toggle = BorderRadius.circular(100); // único caso
  }
  ```

- [ ] **NÃO aplicar globalmente ainda** (evitar quebrar UI)
- [ ] Usar progressivamente nas próximas fases

### 1.5 Validação Fase 1
- [ ] App compila sem erros
- [ ] Nenhuma regressão visual (ainda usando estilos antigos como fallback)
- [ ] Tokens disponíveis para uso progressivo

**Entregável:** Biblioteca de tokens pronta, theme preparado, app funcional.

---

## FASE 2: Componentes Atômicos (5-7 dias)

**Objetivo:** Extrair componentes reutilizáveis pixel-perfect do Figma.

### 2.1 Estrutura
- [ ] Criar pasta `app/lib/shared/widgets/figma/`
  - Organizar por categoria (navigation, forms, cards, etc.)

### 2.2 Navegação Global
- [ ] `FigmaTopNav` (2 variantes)
  ```dart
  // Sem back button (54.708px)
  FigmaTopNav(
    breadcrumb: 'SEÇÃO',
    showBackButton: false,
  )
  
  // Com back button (73.712px)
  FigmaTopNav(
    breadcrumb: 'SEÇÃO / SUBSEÇÃO',
    showBackButton: true,
    onBack: () {},
  )
  ```

- [ ] `FigmaBottomNav` (5 tabs + RUN FAB)
  - Altura exata: 78.591px
  - RUN FAB: 55.982px **quadrado** (não circular)
  - Shadows corretos: glow ciano + drop shadow
  - Underline tab ativo: 1.979 × 19.98px ciano

### 2.3 Forms
- [ ] `FigmaFormFieldLabel` (11px Medium, 1.65ls ALL CAPS)
- [ ] `FigmaFormTextField` (h=48.5px, bg/border exatos)
- [ ] `FigmaNumericInputField` (28px Bold + setas ±)
- [ ] `FigmaSelectionButton` (56.5px fullwidth, estados select/unselect)
- [ ] `FigmaHealthChip` (multi-select)

### 2.4 Cards e Containers
- [ ] `FigmaAppPanel` (substituir `AppPanel` existente)
  - Padding default: 13.718px
  - Borda: 1.735px rgba(255,255,255,0.08)
  - Bg: rgba(255,255,255,0.03)
  - Border-radius: **zero**

- [ ] `FigmaCoachAIBlock` (borda apenas esquerda)
  - 3 variantes de bg opacity (06%, 03%, 02%)
  - Breadcrumb opcional: "[■] COACH.AI > {AÇÃO}"

- [ ] `FigmaCyanInfoBlock`
- [ ] `FigmaMetricCard` (reutilizar ou refatorar existente)

### 2.5 Gamificação
- [ ] `FigmaBadgeCard` (locked/unlocked states)
  - Progress bar: 3.985px height
  - Opacities exatas: 50% quando locked

- [ ] `FigmaXPLevelCard`
  - Número nível: 56px Bold
  - Barra: 7.997px height

- [ ] `FigmaStreakCalendarGrid` (7×4, gradiente opacity)

### 2.6 Stats e Métricas
- [ ] `FigmaSectionHeading` (Bold 22px + superscript 6.6px ciano)
- [ ] `FigmaGamificationStatsRow` (3 tiles STREAK/XP/BADGES)
- [ ] `FigmaBodyMetricsRow` (4 tiles PESO/ALTURA/IDADE/FREQ)
- [ ] `FigmaWeeklyDayGrid` (7 colunas, 3 estados)

### 2.7 Run Journey
- [ ] `FigmaRunMetricCell` (HUD 2×2 grid)
- [ ] `FigmaZoneBar` (5 zonas com cores canônicas)
- [ ] `FigmaSplitCard` (scroll horizontal)
- [ ] `FigmaSplitRow` (barra horizontal por KM)

### 2.8 Buttons e CTAs
- [ ] `FigmaCTAButton` (fullwidth, altura específica)
  - Tracking: 1.2px
  - Bold 12px
  - Variantes: primary (ciano) / secondary (outline)

### 2.9 Outros
- [ ] `FigmaAppTag` (badges de contagem)
- [ ] `FigmaTogglePill` (único com border-radius)
- [ ] `FigmaProgressBar` (4 heights: 2px, 3.985px, 5.991px, 7.997px)

### 2.10 Validação Fase 2
- [ ] Storybook ou página de showcase com todos os componentes
- [ ] Comparação visual: screenshots Figma vs componentes Flutter
- [ ] Zero uso de border-radius (exceto toggle)
- [ ] Todas as dimensões exatas

**Entregável:** Biblioteca de 30-40 componentes atômicos reutilizáveis.

---

## FASE 3: Migração Tela-por-Tela (Core) (7-10 dias)

**Objetivo:** Refatorar telas principais usando componentes Figma.

**Ordem de Prioridade:**
1. HOME (tela de entrada)
2. PERFIL (mais complexa, valida todos os componentes)
3. Gamificação (já funcional, migração rápida)
4. Histórico
5. Treino

### 3.1 Migração HOME
- [ ] Substituir header customizado por `FigmaTopNav`
- [ ] Refatorar `_WeekGrid` → `FigmaWeeklyDayGrid`
- [ ] Coach.AI card → `FigmaCoachAIBlock`
- [ ] Métricas → `FigmaMetricCard` com superscript
- [ ] Aplicar JetBrains Mono em todos os textos
- [ ] Validar spacing com gap system
- [ ] Screenshot comparison

### 3.2 Migração PERFIL
- [ ] UserProfileHeader → `FigmaUserProfileHeader`
- [ ] GamificationStatsRow → `FigmaGamificationStatsRow` (3 tiles)
- [ ] BodyMetricsGrid → `FigmaBodyMetricsRow` (4 tiles)
- [ ] Skin selector: remover border-radius, aplicar dimensões exatas
- [ ] Menu items: altura 76px, borda 1.735px
- [ ] Refatorar forms com `FigmaFormFieldLabel` + `FigmaFormTextField`
- [ ] Screenshot comparison

### 3.3 Migração GAMIFICAÇÃO
- [ ] Tab bar → `FigmaSegmentedTabBar` (3-col, h=41.424px)
- [ ] Badge grid → `FigmaBadgeCard` components
- [ ] XP level card → `FigmaXPLevelCard`
- [ ] Streak calendar → `FigmaStreakCalendarGrid`
- [ ] Screenshot comparison

### 3.4 Migração HISTÓRICO
- [ ] Tab selectors (período + conteúdo)
- [ ] Stat cards 2-col layout
- [ ] Implementar `FigmaZoneDistributionBar` (barra empilhada + tabela %)
- [ ] Charts: considerar SVG custom vs biblioteca
- [ ] Screenshot comparison

### 3.5 Migração TREINO
- [ ] Plano semanal: `FigmaWeekPlanRow` × 7
- [ ] Stats row: VOLUME/SESSÕES/DESCANSO
- [ ] Tab selector 3-col
- [ ] Coach summary → `FigmaCoachAIBlock`
- [ ] Screenshot comparison

### 3.6 Validação Fase 3
- [ ] Todas as 5 telas core migradas
- [ ] Screenshots lado-a-lado (Figma vs App) documentados
- [ ] Fidelidade visual > 90% em cada tela
- [ ] Features funcionais preservadas
- [ ] Performance mantida ou melhorada

**Entregável:** 5 telas core pixel-perfect.

---

## FASE 4: Features Avançadas (7-10 dias)

**Objetivo:** Implementar jornadas completas ausentes.

### 4.1 Onboarding Flow (13 passos)
- [ ] `OnboardingTopProgressBar` (2px, fill proporcional)
- [ ] `OnboardingHeader` (logo + PULAR + VOLTAR)
- [ ] `OnboardingSlideLabel` ("// SLIDE_XX")
- [ ] `OnboardingHeading` (número ciano top-right)
- [ ] `OnboardingFeatureCard`
- [ ] `OnboardingPageIndicator` (13 dots, 3 estados)
- [ ] `OnboardingContinueButton`

**Telas:**
- [ ] SPLASH
- [ ] ONBOARDING 01-03 (3 slides)
- [ ] LOGIN (4/13)
- [ ] ASSESSMENT 01-09 (5-13/13)
- [ ] PLAN LOADING (pós-13)

### 4.2 Run Journey (Sessão Ativa)
- [ ] Pre-run / Confirmação
- [ ] HUD Ativo: `FigmaRunMetricCell` grade 2×2
- [ ] `FigmaZoneBar` zona atual
- [ ] `FigmaSplitCard` scroll horizontal
- [ ] Pause / Stop controls
- [ ] Pós-corrida:
  - [ ] Stats grid 3-col
  - [ ] `FigmaSplitRow` relatório por KM
  - [ ] `FigmaBadgeUnlockModal` (se aplicável)
  - [ ] `FigmaShareCardPreview`
  - [ ] Foto overlay chips

### 4.3 Coach Chat UI
- [ ] `FigmaCoachChatBubble` (usuário + coach)
- [ ] Breadcrumb laranja no bubble Coach
- [ ] `FigmaCoachOptionButton` (4 opções inline)
- [ ] Integração com backend de chat
- [ ] Scroll behavior

### 4.4 Zonas Cardíacas
- [ ] `FigmaZoneCard` (58.937px, 5 zonas Z1-Z5)
  - Cores canônicas
  - Range BPM
  - % de tempo
  - Barra 7.997px
- [ ] Integração com dados de treino

### 4.5 Validação Fase 4
- [ ] Onboarding flow completo end-to-end
- [ ] Run journey completo (pré → ativo → pós)
- [ ] Coach chat funcional
- [ ] Zones visualizadas corretamente

**Entregável:** Features diferenciais completas e polidas.

---

## FASE 5: Polish e Detalhes Finais (3-5 dias)

**Objetivo:** Estados, animações e telas pendentes.

### 5.1 Estados Globais
- [ ] Empty states
  - HIST sem corridas
  - BADGES todos bloqueados
  - Treino sem plano
- [ ] Error states (falha conexão, timeout)
- [ ] Loading states (skeleton screens)

### 5.2 Telas PERFIL Pendentes
- [ ] PERFIL > AJUSTES > Coach settings
- [ ] PERFIL > AJUSTES > Alertas/Notificações
- [ ] PERFIL > AJUSTES > Unidades
- [ ] PERFIL > ASSINATURA (Premium flow)
- [ ] PERFIL > Editar Perfil (inline)

### 5.3 Detalhes Visuais
- [ ] Animações de transição (se especificadas)
- [ ] RUN FAB glow animation
- [ ] Badge unlock pulse
- [ ] Loading progress bars animadas
- [ ] Pull-to-refresh personalizado

### 5.4 Acessibilidade
- [ ] Contrast ratios validados
- [ ] Labels semanticamente corretos
- [ ] Touch targets mínimos (44×44)

### 5.5 Validação Final
- [ ] Audit completo: todas as telas vs Figma
- [ ] Performance profiling (60fps)
- [ ] Bundle size otimizado
- [ ] Documentação de componentes atualizada

**Entregável:** App 100% alinhado com Figma, polido e production-ready.

---

## 5. Gestão de Riscos

### 5.1 Riscos Identificados

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Quebra de features existentes durante refactor | Média | Alto | Testes automatizados + feature flags |
| Divergência de interpretação Figma | Baixa | Médio | Screenshots comparativos + validação design |
| Performance degradada (componentes novos) | Baixa | Alto | Profiling contínuo + benchmarks |
| Atraso no timeline | Média | Médio | Buffer 20% em cada fase |
| Tokens Figma não publicados (valor extraído manualmente) | Baixa | Baixo | Valores hardcoded com TODOs para sync futuro |

### 5.2 Estratégias de Mitigação

1. **Feature Flags:**
   - Usar Hive para toggle `useFigmaComponents`
   - Rollback fácil se regressão detectada

2. **Testes Visuais:**
   - Screenshots automatizados (golden tests)
   - Comparação pixel-diff com Figma exports

3. **Code Review Rigoroso:**
   - PRs pequenos (1 componente ou 1 tela por vez)
   - Checklist de fidelidade visual

4. **Feedback Loop:**
   - Deploy staging após cada fase
   - Validação com designer (se disponível)

---

## 6. Estimativas e Recursos

### 6.1 Estimativa de Esforço

| Fase | Dias (Dev) | Complexidade | Risco |
|------|------------|--------------|-------|
| Fase 1: Fundações | 3-5 | Baixa | Baixo |
| Fase 2: Componentes Atômicos | 5-7 | Média | Médio |
| Fase 3: Migração Core | 7-10 | Alta | Médio |
| Fase 4: Features Avançadas | 7-10 | Alta | Alto |
| Fase 5: Polish | 3-5 | Média | Baixo |
| **TOTAL** | **25-37 dias** | — | — |

**Com buffer 20%:** 30-44 dias úteis (6-9 semanas)

### 6.2 Recursos Necessários

**Engenharia:**
- 1 Frontend Engineer (Flutter) — full-time
- 1 CTO (review + unblock) — 25% time

**Design (opcional):**
- Designer para validação visual — consultas pontuais

**Infraestrutura:**
- CI/CD para golden tests
- Staging environment para validação

### 6.3 Dependências Externas

- ✅ Documentação Figma completa (já extraída)
- ⚠️ Tokens Figma não publicados (usar valores hardcoded)
- ⚠️ Assets SVG de ícones (exportar do Figma)
- ⚠️ Specs de animações (não detalhadas no Figma)

---

## 7. Métricas de Sucesso

### 7.1 Métricas Técnicas

| Métrica | Target | Medição |
|---------|--------|---------|
| **Fidelidade Visual** | > 95% | Screenshot diff score |
| **Componentes Reutilizáveis** | 40+ | Contagem em `figma/` folder |
| **Cobertura Tipográfica** | 100% JetBrains Mono | Audit de `TextStyle` widgets |
| **Border-Radius Zero** | 100% (exceto toggle) | Grep por `BorderRadius.circular` |
| **Performance (60fps)** | 100% das telas | Flutter DevTools profiling |
| **Testes Visuais** | > 90% cobertura | Golden tests count |

### 7.2 Métricas de Negócio

| Métrica | Baseline | Target | Impacto Esperado |
|---------|----------|--------|------------------|
| Time-to-Onboard | N/A | < 3 min | Onboarding implementado |
| Engagement Gamificação | Médio | +30% | UI polida aumenta uso |
| Retention D7 | TBD | +15% | Identidade visual forte |
| NPS | TBD | +10 pts | App "parece profissional" |

### 7.3 Critérios de Aceitação (DoD)

**Fase considerada completa quando:**
- [ ] Todos os componentes/telas implementados
- [ ] Fidelidade visual > 90% validada com screenshots
- [ ] Zero regressões funcionais
- [ ] Testes visuais passing
- [ ] Code review aprovado
- [ ] Documentação atualizada
- [ ] Deploy em staging validado

---

## 8. Alternativas Consideradas

### 8.1 Alternativa 1: Ignorar Figma, Iterar Código Atual
**Pros:**
- Sem esforço de refactor
- App já funcional

**Cons:**
- Fidelidade visual comprometida
- Design inconsistente dificulta escala
- Débito técnico acumula

**Decisão:** ❌ Rejeitada. Figma é fonte de verdade do produto.

### 8.2 Alternativa 2: Rewrite Completo em Nova Stack
**Pros:**
- Clean slate, zero dívida técnica

**Cons:**
- Meses de desenvolvimento
- Risco altíssimo de regressões
- Custo proibitivo

**Decisão:** ❌ Rejeitada. Refactor incremental é viável e seguro.

### 8.3 Alternativa 3: Contratar Agência de UI
**Pros:**
- Especialistas em fidelidade visual
- Potencial mais rápido

**Cons:**
- Custo alto ($$$$)
- Onboarding demorado
- Ownership de longo prazo

**Decisão:** ⚠️ Considerar se timeline crítico. Por ora, capacidade interna suficiente.

---

## 9. Próximos Passos (Recomendações)

### 9.1 Aprovação Necessária

**Board/CEO deve aprovar:**
1. Escopo completo (5 fases, 30-44 dias)
2. Alocação de Frontend Engineer full-time
3. Priorização sobre outras features durante execução
4. Budget para design validation (se aplicável)

### 9.2 Kick-off Imediato

**Após aprovação:**
1. **Dia 1:** Criar branch `feature/figma-design-system`
2. **Dia 1-2:** Setup CI/CD para golden tests
3. **Dia 3:** Iniciar Fase 1 (Fundações)
4. **Semanal:** Demo de progresso + screenshot comparisons
5. **Bi-semanal:** Review com CTO + ajustes de prioridade

### 9.3 Comunicação Stakeholders

**Transparência contínua:**
- Slack channel: `#figma-migration`
- Semanal update: progresso vs plano
- Screenshots antes/depois compartilhados
- Bloqueios escalados imediatamente

---

## 10. Conclusão

### 10.1 Resumo da Análise

O app possui **fundações sólidas** com features funcionais e backend integrado. Porém, há **divergências significativas** entre o design system do Figma e a implementação atual:

- **Tipografia:** Mistura de 3 fontes vs JetBrains Mono exclusivo
- **Border-Radius:** Uso de circular vs zero cantos (identidade visual)
- **Componentes:** Inline repetitivo vs biblioteca atômica
- **Fidelidade:** ~50-65% nas telas principais

### 10.2 Recomendação Final

**✅ APROVAR plano de 5 fases com execução incremental.**

**Justificativa:**
1. **Risco Controlado:** Abordagem incremental mantém app funcional
2. **ROI Claro:** Identidade visual forte diferencia produto
3. **Escalabilidade:** Biblioteca de componentes facilita futuras features
4. **Timeline Viável:** 6-9 semanas com buffer adequado

**Crítico para Sucesso:**
- Alocação dedicada de 1 Frontend Engineer
- Validação visual contínua (screenshots)
- Approval gates entre fases

### 10.3 Impacto Esperado

**Pós-implementação:**
- App com fidelidade > 95% ao Figma
- 40+ componentes reutilizáveis documentados
- Identidade visual consistente e profissional
- Base sólida para escalar features futuras
- Redução de 50% em tempo de desenvolvimento de novas telas (componentes prontos)

---

**Aguardando decisão do Board para iniciar execução.**

---

## Apêndice A: Inventário Completo de Componentes

### Componentes por Categoria

**Navegação (3):**
- FigmaTopNav (2 variantes)
- FigmaBottomNav
- FigmaRunFAB

**Forms (8):**
- FigmaFormFieldLabel
- FigmaFormTextField
- FigmaOtpTextField
- FigmaNumericInputField
- FigmaSelectionButton
- FigmaTimePeriodCard
- FigmaHealthChip
- FigmaTogglePill

**Cards & Containers (10):**
- FigmaAppPanel
- FigmaCoachAIBlock
- FigmaCyanInfoBlock
- FigmaMetricCard
- FigmaBadgeCard
- FigmaXPLevelCard
- FigmaZoneCard
- FigmaDeviceCard
- FigmaExamCard
- FigmaSkinPaletteCard

**Stats & Data Viz (12):**
- FigmaSectionHeading
- FigmaGamificationStatsRow
- FigmaBodyMetricsRow
- FigmaWeeklyDayGrid
- FigmaRunMetricCell
- FigmaZoneBar
- FigmaZoneDistributionBar
- FigmaSplitCard
- FigmaSplitRow
- FigmaProgressBar (4 variants)
- FigmaChartLineSpark
- FigmaBenchmarkBellCurve

**Onboarding (7):**
- FigmaOnboardingTopProgressBar
- FigmaOnboardingHeader
- FigmaOnboardingSlideLabel
- FigmaOnboardingHeading
- FigmaOnboardingFeatureCard
- FigmaOnboardingContinueButton
- FigmaOnboardingPageIndicator

**Assessment (4):**
- FigmaAssessmentLabel
- FigmaAssessmentHeading
- FigmaCoachAIBreadcrumb
- FigmaPlanTaskRow

**Run Journey (5):**
- FigmaBadgeUnlockModal
- FigmaShareCardPreview
- FigmaPhotoOverlayChip
- FigmaOverlayDataToggleChip
- FigmaPostRunStatCard

**Treino (5):**
- FigmaWeekPlanRow
- FigmaMonthWeekCard
- FigmaCoachChatBubble
- FigmaCoachOptionButton
- FigmaAjusteHistoryEntry

**Outros (6):**
- FigmaAppTag
- FigmaBadgeChip
- FigmaCTAButton
- FigmaNotificationCard
- FigmaAlertToggleRow
- FigmaSegmentedTabBar

**TOTAL:** 60 componentes únicos

---

## Apêndice B: Checklist de Validação Visual

### Por Tela

**HOME:**
- [ ] Tipografia 100% JetBrains Mono
- [ ] Logo lockup exato (RUNNIN + .AI badge)
- [ ] WeekGrid: 7 colunas, estados corretos
- [ ] Coach card: borda esquerda laranja 1.735px
- [ ] Spacing: gap system aplicado
- [ ] Border-radius: zero em todos os cards

**PERFIL:**
- [ ] UserProfileHeader: avatar + stats layout
- [ ] GamificationStatsRow: 3 tiles, Bold 22px
- [ ] BodyMetricsRow: 4 tiles, 9px units
- [ ] Skin selector: 2×2 grid, sem border-radius
- [ ] Menu items: 76px height, 1.735px border

**GAMIFICAÇÃO:**
- [ ] Tab bar: 3-col, 41.424px height
- [ ] Badge cards: locked opacity 50%
- [ ] XP card: 56px Bold number
- [ ] Streak calendar: 7×4 grid, gradiente

**HISTÓRICO:**
- [ ] Tab selectors: correto
- [ ] Stat cards: 2-col layout
- [ ] Zone bar: barra empilhada + tabela %
- [ ] Charts: estilo consistente

**TREINO:**
- [ ] Week plan: 7 rows, estados OK/HOJE/FUTURO/DESCANSO
- [ ] Stats row: 3 tiles
- [ ] Coach summary: borda esquerda
- [ ] Tab selector: 3-col

---

## Apêndice C: Tokens de Cor (Referência Rápida)

```dart
// Background
color/bg/base: #050510

// Brand
color/brand/cyan: #00d4ff
color/brand/orange: #ff6b35

// Text
color/text/primary: #ffffff
color/text/secondary: rgba(255,255,255,0.55)
color/text/muted: rgba(255,255,255,0.45)
color/text/dim: rgba(255,255,255,0.30)
color/text/ghost: rgba(255,255,255,0.20)

// Surface
color/surface/card: rgba(255,255,255,0.03)
color/surface/card-cyan: rgba(0,212,255,0.03)
color/surface/card-orange: rgba(255,107,53,0.03)

// Border
color/border/default: rgba(255,255,255,0.08)
color/border/cyan: rgba(0,212,255,0.14)
color/border/cyan-strong: rgba(0,212,255,0.19)
color/border/orange: #ff6b35

// Nav
color/nav/topbar/bg: rgba(5,5,16,0.92)
color/nav/bottombar/bg: rgba(5,5,16,0.96)
color/nav/border: rgba(255,255,255,0.06)

// Zones (canônicas)
z1: #3b82f6  // Recuperação
z2: #22c55e  // Aeróbico base
z3: #eab308  // Aeróbico leve
z4: #f97316  // Limiar
z5: #ef4444  // VO2max
```

---

**FIM DO DOCUMENTO**
