# Tela: HOME (Dashboard Principal)

> Extraído via Figma MCP — Fonte canônica: nó `1:5269`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> URL: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-5269

---

## Visão geral

Dashboard principal do app após o onboarding. Tela scrollável longa (~3666 px) com 6 seções numeradas. O viewport é 393.545 × 851.519 px. Sem page indicators — esta é a tela principal do app, não pertence ao fluxo de onboarding.

**Layout:** `#050510` fullscreen, sem barra de progresso de onboarding.  
**Navegação:** Bottom tab bar fixa com 5 tabs (HOME, TREINO, RUN, HIST, PERFIL).  
**Altura scrollável:** ~3666 px (viewport: 851.5 px).

---

## Hierarquia de nós (estrutura de alto nível)

```
home (1:5269) — frame raiz 393.545×851.519 px
└── Body (1:5270) — container fullscreen
    └── Layout (1:5271) — bg #050510, height 3666 px (scrollável)
        ├── Hero / header area (top 0–490.73 px)
        │   └── imgContainer — mapa de fundo + overlays de ícones
        └── Container (1:5272) — conteúdo principal (top 490.73)
            ├── Seção 01 — Brief COACH.AI + botão INICIAR SESSÃO
            ├── Seção 02 — NOTIFICAÇÕES COACH.AI (5 cards)
            │   └── Coach expanded card (fechamento mensal)
            ├── Seção 03 — SEMANA (grid 7 colunas)
            ├── Seção 04 — PERFORMANCE (grade 2×2)
            ├── Seção 05 — COACH.AI RESUMO SEMANAL
            ├── Seção 06 — STATUS CORPORAL (grade 2×2)
            └── Seção 07 — ÚLTIMA CORRIDA
```

---

## Hero / Header (topo, ~490 px)

- Background: imagem de mapa de rota (asset `imgContainer`)
- 12 ícones sobrepostos (18–22 px, assets MuiSvgIconRoot)
- Gráficos de área vetoriais (imgVector, imgVector1, imgVector2)
- Informações de perfil e stats do usuário (sem header de navegação tradicional — full-bleed)

---

## Seção 01 — Coach.AI Brief + Iniciar

### Card Coach.AI (1:5274)
- **Background:** `rgba(255, 107, 53, 0.02)`
- **Borda esquerda:** 1.741 px `#FF6B35`
- **Padding:** pt 16, pl 17.74, pr 16
- **Label:** "COACH.AI" — Regular 11 px, `#FF6B35`, tracking 1.1 px
- **Texto:** "Easy Run hoje — pace controlado entre 6:00 e 6:30. Foco em cadência e respiração nasal. Não acelere nos últimos 2km, ontem foi intervalado."
  - Regular 13 px, `rgba(255,255,255,0.70)`, line-height 21.45 px, width 294 px

### Botão INICIAR SESSÃO (1:5280)
- **Background:** `#00D4FF`
- **Tamanho:** fullwidth × 45.955 px, padding px 20, py 14
- **Texto:** "INICIAR SESSÃO ↗" — Bold 12 px, `#050510`, tracking 1.2 px

---

## Seção 02 — Notificações COACH.AI

### Header da seção
- Dot ciano (5.986 px, opacity 98%, `#00D4FF`)
- Label: "COACH.AI > NOTIFICAÇÕES" — Regular 11 px, `#00D4FF`, tracking 1.65 px
- Badge "5": Bold 9 px, `#050510` sobre retângulo `#00D4FF` (17.386 × 17.468 px)
- Botão "LIMPAR": Medium 10 px, `rgba(255,255,255,0.55)`, tracking 1 px

### 5 Cards de Notificação
**Dimensões:** 327.428 × 62.444 px cada  
**Estilo:** border 1.741 px sólido (cor varia), bg `rgba(255,255,255,0.03)`

| # | Cor borda | Título | Hora |
|---|-----------|--------|------|
| 1 | `#00D4FF` | MELHOR HORÁRIO: 06:30 | AGORA |
| 2 | `#EAB308` | PREPARO NUTRICIONAL | 05:30 |
| 3 | `#3B82F6` | HIDRATAÇÃO: 72% (1.8L/2.5L) | CONTÍNUO |
| 4 | `#FF6B35` | CHECKLIST PRÉ-EASY RUN | 06:00 |
| 5 | `#8B5CF6` | SONO → PERFORMANCE | 21:00 |

**Estrutura interna de cada card:**
- Ícone 18 × 18 px (MuiSvgIconRoot)
- Título: Bold 11 px, cor do accent da categoria
- Subtítulo: Medium 11 px, `rgba(255,255,255,0.55)` (truncado com "...")
- Timestamp/status: Medium 9 px, `rgba(255,255,255,0.55)` (top-right)
- Caret "▼" 10 px (expansão)

### Card COACH.AI Expandido — Fechamento Mensal (1:5374)
- **Posição:** left 44, width 279.4, height 253.9 px
- **Background:** `rgba(0,212,255,0.02)`, border `rgba(0,212,255,0.14)` 1.741 px
- **Breadcrumb:** "COACH.AI > FECHAMENTO MENSAL" — Regular 10 px, `#FF6B35`, tracking 1.5 px
- **Dot laranja:** 5.605 × 5.986 px, opacity 98%
- **Heading:** "Tem exames novos?" — Bold 13 px, branco
- **Corpo:** "Estamos fechando o mês. Exames atualizados me ajudam a calibrar zonas e limites para o próximo ciclo de treinos." — Regular 12 px, `rgba(255,255,255,0.55)`, line-height 19.2 px
- **Botão primário:** "ENVIAR EXAME ↗" — `#00D4FF`, h 48.975, w 126.928, Bold 11 px `#050510`, tracking 0.88 px
- **Botão secundário:** "DEPOIS" — border `rgba(255,255,255,0.08)`, h 48.975, w 75.041, Medium 11 px `rgba(255,255,255,0.55)`

---

## Seção 03 — Semana (Grid semanal)

**Heading:** "Semana" + superscript "02" (6.6 px `#00D4FF`)  
**Subtítulo:** "Sem 2 · Mar 3-9 · 2/5 sessões · 37% volume" — Regular 12 px, `rgba(255,255,255,0.55)`

### Grid de 7 dias (colunas iguais 43.343 px cada)

| Dia | Cabeçalho bg | Cor texto | Status | Tipo | Distância | Pace/Duração |
|-----|-------------|-----------|--------|------|-----------|--------------|
| SEG | `#00D4FF` | `#050510` | ✓ | EASY | 4K | 6:10/km · 26:00 |
| TER | `#00D4FF` | `#050510` | ✓ | INT | 4x800m | 4:50/km · 24:00 |
| QUA | `rgba(0,212,255,0.09)` | `#00D4FF` | HOJE | EASY | 5K (laranja) | 6:30 alvo (laranja) |
| QUI | transparente | `rgba(255,255,255,0.55)` | DESC | — | — | — |
| SEX | transparente | `rgba(255,255,255,0.55)` | ● | TEMPO | 5K (dim) | 5:30 (dim) |
| SAB | transparente | `rgba(255,255,255,0.55)` | DESC | — | — | — |
| DOM | transparente | `rgba(255,255,255,0.55)` | ● | LONG | 8K (dim) | 6:45 (dim) |

**Célula — header:** h 37.711 px, bottom-border 1.741 px  
**Célula — corpo:** bg `rgba(255,255,255,0.03)`, border l/r/b 1.741 px, h 110.44 px, pb 9.741, pt 8, px 9.741  
- Ícone ✓ ou ●: ciano (completo) ou dim (futuro)
- Tipo corrida: 9 px Regular `#00D4FF` ou dim
- Distância: Bold 13 px — ciano (completo) / laranja hoje / dim (futuro)

### Barra de volume semanal
- Label: "VOLUME" / "8.8 / 24 km"
- Track: bg `rgba(255,255,255,0.04)`, fill `#00D4FF` a 37%

---

## Seção 04 — Performance (Grade 2×2)

Cada card: 159.714 px de largura, ~179 px de altura  
**Estilo padrão:** bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08)` 1.741 px

### Card 1 — PACE TREND
- Label: "PACE TREND" — 11 px dim
- Valor: "5:26" — Bold 28 px `#00D4FF`
- Delta: "↓18s" — 11 px `#00D4FF`
- Sub: "/km · último treino" — 10 px dim
- Gráfico de área ciano (Vector assets, bottom do card)

### Card 2 — CARDÍACO
- Label: "CARDÍACO" — 11 px dim
- Valor: "62" — Bold 28 px `#FF6B35`
- Delta: "↓3" — 11 px `#00D4FF`
- Sub: "bpm repouso"
- "CORRIDA 152" — Bold 13 px laranja
- Barra de zonas cardíacas (5 segmentos, h 8 px):
  - Z1 `#3B82F6` · Z2 `#22C55E` · Z3 `#EAB308` · Z4 `#F97316` · Z5 `#EF4444`

### Card 3 — BENCHMARK (fundo ciano sólido)
- **Background:** `#00D4FF` (full-bleed — diferente dos demais)
- Label: "BENCHMARK" — 11 px `#050510` opacity 70%
- Valor: "TOP 30%" — Bold 36 px `#050510`
- Sub: "intermediários · esta semana ↗" — 10 px `#050510` opacity 60%

### Card 4 — STREAK
- Label: "STREAK" — 11 px dim
- Valor: "12" — Bold 28 px branco
- Unidade: "dias" — 11 px dim
- Lista (separada por top-border):
  - "MARÇO" → "24.0 km" (Bold 13 px branco)
  - "CORRIDAS" → "6" (Bold 13 px branco)
  - "PACE MÉD" → "5:38" (Bold 13 px `#FF6B35`)

---

## Seção 05 — Coach.AI Resumo Semanal

**Card com left-border `#FF6B35`, bg `rgba(255,107,53,0.02)`, padding pl 21.74, pr 20, pt 20**  
**Breadcrumb:** dot laranja (8×8 px) + "> RESUMO SEMANAL · SEM 2" — Regular 11 px `#FF6B35`, tracking 1.65 px

3 sub-blocos com label ciano (10 px Regular `#00D4FF`, tracking 1 px) + texto corpo (14 px Regular `rgba(255,255,255,0.80)`, line-height 23.1 px):

1. **PROGRESSO:** "2 de 5 sessões concluídas. Volume em 37% — ritmo adequado para bater a meta até domingo."
2. **PERFORMANCE:** "Pace médio no percentil 70 entre intermediários. Intervalado de terça teve splits consistentes — sinal de maturidade aeróbica. BPM em repouso caindo: adaptação cardiovascular positiva."
3. **RECOMENDAÇÃO:** "Hoje é recuperação ativa. Mantenha zona 2, respiração nasal, e stride rate acima de 170spm. Sexta será Tempo Run — descanse quinta para chegar preparado."

---

## Seção 06 — Status Corporal (Grade 2×2)

Cada card: ~159.714 × 159 px

### Card 1 — PRONTIDÃO
- Valor: "82" — Bold 36 px `#00D4FF`
- Unidade: "/100"
- Sub: "Pronto para treinar" — 10 px dim
- Barra de progresso: bg `rgba(255,255,255,0.04)`, fill ciano a ~82%

### Card 2 — SONO
- Valor: "7h20" — Bold 28 px `#FF6B35`
- Sub: "Qualidade: boa" — 10 px dim
- Gráfico de barras (7 barras SEG→HOJE):
  - Hoje: `#FF6B35`, h ~22.5 px
  - Outros: dim branco, alturas variáveis
- Labels: "SEG" dim, "HOJE" `#FF6B35`

### Card 3 — CARGA MUSCULAR
- Valor: "MEDIA" — Bold 22 px `#EAB308`
- Sub: "Impacto acumulado 48h"
- Seletor de 3 estados (BAIXA | MEDIA | ALTA):
  - Ativo: bg `rgba(234,179,8,0.19)`, border `rgba(234,179,8,0.31)`, texto `#EAB308`
  - Inativo: bg/border dim

### Card 4 — HIDRATAÇÃO
- Valor: "1.8L" — Bold 28 px `#3B82F6`
- Unidade: "/2.5L"
- Sub: "72% da meta diária"
- Barra de progresso: fill `#3B82F6` a 72%

---

## Seção 07 — Última Corrida

**Card com border `rgba(255,255,255,0.08)` 1.741 px**  
- Header: "06.MAR · EASY RUN" — Regular 11 px `#00D4FF`, tracking 1.1 px
- Distância: "5.2K" — Bold 28 px branco
- Label "DURAÇÃO": 11 px dim, right-aligned
- Duração: "28:15" — Bold 22 px `#FF6B35`

---

## Bottom Tab Bar (componente global)

> Presente em todas as telas pós-onboarding. Descrito aqui como fonte canônica.

- **Background:** `rgba(5,5,16,0.96)`
- **Border-top:** 1.741 px `rgba(255,255,255,0.06)`
- **Height:** ~72 px, padding px 8, pt 9.741, pb 16

| Tab | Ícone | Label | Estado padrão |
|-----|-------|-------|---------------|
| HOME | 18 px | HOME | Inativo |
| TREINO | 18 px | TREINO | Inativo |
| **RUN** | — | RUN | **CTA central elevado** |
| HIST | 18 px | HIST | Inativo |
| PERFIL | 18 px | PERFIL | Inativo |

**Tab padrão (inativo):**
- Ícone + label: `rgba(255,255,255,0.55)`
- Label: Medium 10 px, tracking 1 px

**Botão RUN (FAB central):**
- Tamanho: 55.995 × 55.995 px (quadrado, não redondo)
- Background: `#00D4FF`
- Elevação: top -3.06 px (flutua acima da barra)
- Sombra: `rgba(0,212,255,0.31)` 0px 0px 30px + `rgba(0,0,0,0.5)` 0px 4px 20px
- Label "RUN": Bold 11 px, `#050510`, tracking 1.1 px
- Anel externo: border `#00D4FF` 2.015 px, 65.05 px, opacity 12%

---

## Top Navigation Bar (componente global)

> Presente em todas as telas pós-onboarding com conteúdo interno. Descrito aqui como fonte canônica.

- **Background:** `rgba(5,5,16,0.92)` (frosted/translúcido)
- **Border-bottom:** 1.741 px `rgba(255,255,255,0.06)`
- **Height:** ~73.7 px, padding pt 16, pb 17.741, pl 24

**Botão VOLTAR:**
- 39.987 × 39.987 px
- Background: `rgba(255,255,255,0.06)`, border `rgba(255,255,255,0.1)` 1.741 px
- Ícone chevron-left SVG

**Logo lockup:**
- "RUNNIN": Bold 14 px, `#FFFFFF`, tracking 1.4 px
- ".AI" badge: bg `#00D4FF`, px 6, py 2, texto Bold 9 px `#050510`
- Separador "/": Regular 12 px, `rgba(255,255,255,0.12)`
- Breadcrumb da página (ex: "PREP", "RELATÓRIO", "SHARE"): Regular 13 px, `rgba(255,255,255,0.55)`, tracking 1.3 px

---

## Padrão de Section Heading (componente global)

> Padrão "SectionHead" — presente em todas as telas de conteúdo pós-onboarding.

- Texto: JetBrains Mono Bold 22 px, `#FFFFFF`, tracking -0.44 px
- Superscript numérico (ex: "01", "02"): JetBrains Mono Regular **6.6 px**, `#00D4FF`
- Altura total: ~24.2 px

---

## Tokens de cor — novos desta tela

| Token (proposto)           | Hex / RGBA                       | Uso                                              |
|----------------------------|----------------------------------|--------------------------------------------------|
| `color/yellow`             | `#EAB308`                        | Notificação nutrição, Carga MEDIA                |
| `color/blue`               | `#3B82F6`                        | Notificação hidratação, Zona Z1                  |
| `color/purple`             | `#8B5CF6`                        | Notificação sono→performance                     |
| `color/green`              | `#22C55E`                        | Zona cardíaca Z2                                 |
| `color/zone/z3`            | `#EAB308`                        | Zona cardíaca Z3 (amarelo = mesma cor de MEDIA)  |
| `color/zone/z4`            | `#F97316`                        | Zona cardíaca Z4                                 |
| `color/zone/z5`            | `#EF4444`                        | Zona cardíaca Z5                                 |
| `color/nav/bg`             | `rgba(5, 5, 16, 0.96)`           | Bottom tab bar                                   |
| `color/topnav/bg`          | `rgba(5, 5, 16, 0.92)`           | Top navigation bar (frosted)                     |
| `color/text/body`          | `rgba(255, 255, 255, 0.80)`      | Texto body do Coach resumo semanal               |
| `color/benchmark/bg`       | `#00D4FF`                        | Card Benchmark (único card com bg sólido ciano)  |
| `color/benchmark/text`     | `#050510`                        | Texto sobre fundo ciano sólido                   |

---

## Tipografia — novas

| Token (proposto)           | Fonte          | Peso  | Tamanho | LS       | LH      |
|----------------------------|----------------|-------|---------|----------|---------|
| `type/section/heading`     | JetBrains Mono | Bold  | 22 px   | −0.44 px | 24.2 px |
| `type/section/index`       | JetBrains Mono | Reg   | 6.6 px  | —        | —       |
| `type/metric/large`        | JetBrains Mono | Bold  | 28 px   | —        | 28 px   |
| `type/metric/xl`           | JetBrains Mono | Bold  | 36 px   | —        | 36 px   |
| `type/coach/label`         | JetBrains Mono | Reg   | 11 px   | 1.1 px   | 16.5 px |
| `type/notification/title`  | JetBrains Mono | Bold  | 11 px   | —        | 16.5 px |
| `type/notification/sub`    | JetBrains Mono | Med   | 11 px   | —        | 16.5 px |
| `type/tab/label`           | JetBrains Mono | Med   | 10 px   | 1 px     | 15 px   |
| `type/tab/run`             | JetBrains Mono | Bold  | 11 px   | 1.1 px   | 16.5 px |
| `type/timestamp`           | JetBrains Mono | Med   | 9 px    | —        | 13.5 px |

---

## Componentes identificados

| Componente               | Tipo   | Reutilizável | Descrição                                                            |
|--------------------------|--------|:------------:|----------------------------------------------------------------------|
| `BottomTabBar`           | Widget | Sim          | 5 tabs, RUN FAB elevado com sombra ciano, bg frosted                |
| `TopNavBar`              | Widget | Sim          | Frosted bg, back button, logo lockup, breadcrumb                    |
| `SectionHeading`         | Widget | Sim          | Bold 22px + superscript 6.6px ciano                                  |
| `CoachAICard`            | Widget | Sim          | Left-border laranja, breadcrumb, texto, botões opcionais            |
| `NotificationCard`       | Widget | Sim          | Left-border colorida por categoria, ícone, título, sub, timestamp    |
| `WeeklyDayGrid`          | Widget | Sim          | 7 colunas, 3 estados (completo/hoje/futuro), header e corpo separados |
| `MetricCard`             | Widget | Sim          | Label + valor grande + delta + sub-linha; variante invertida (ciano) |
| `SegmentedStateSelector` | Widget | Sim          | 3 segmentos (BAIXA/MEDIA/ALTA), estado ativo colorido                |
| `BarChart`               | Widget | Sim          | 7 barras verticais, barra hoje em destaque                           |
| `ProgressBarInline`      | Widget | Sim          | Track + fill, sem label, 4–5 px de altura                           |
| `ZoneBar`                | Widget | Sim          | 5 zonas coloridas (Z1–Z5) com fill proporcional                     |
| `BadgeChip`              | Widget | Sim          | Chip ciano-tintado, ícone + texto, border ciano                      |

---

## Comportamento / UX

- **Scroll:** longo scroll vertical (~3666 px); sem paginação
- **Hero:** área de mapa no topo com sobreposição de dados de perfil
- **CTA principal:** "INICIAR SESSÃO ↗" leva para o fluxo de preparação da corrida (pre_corrida)
- **Notificações:** 5 cards expandíveis com ações; badge contador no header
- **Grid semanal:** dias completos têm fundo ciano sólido; hoje tem tint ciano; futuros são dim
- **Seção Status Corporal:** dados do dia — prontidão, sono, carga, hidratação

---

## Lacunas / Decisões pendentes

1. **Aba ativa:** qual tab fica ativa ao chegar na Home? HOME ativo não tem destaque visual explícito além da posição.
2. **Pull to refresh:** não especificado no design.
3. **Hero map:** imagem estática ou mapa interativo (Mapbox/Google Maps)?
4. **Notificações:** expandem inline ou abrem uma tela separada?
5. **Seção Últimas corridas:** parece ser um preview — existe uma tela de histórico completo?
6. **Personalização:** os dados (Lucas, 12 dias de streak, etc.) são hardcoded ou dinâmicos?
