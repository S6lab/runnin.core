# Telas: HIST (Histórico — Dados, Corridas, Bench, Detalhe, Coach Chat)

> Extraído via Figma MCP — Nós `1:9956`, `1:10393`, `1:10991`, `1:11403`, `1:11114`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)

---

## Visão geral

Seção HIST com 3 abas principais (DADOS / CORRIDAS / BENCH) + telas de detalhe. Total de 5 telas documentadas.

**Fluxo:**  
`Dados (3 meses)` → `Corridas (lista)` → `Corrida Detalhe` → `Coach Chat da Corrida` | `Benchmark`

---

## Componentes Globais do HIST

### TopNav (54.708px — sem back button)

| Elemento | Valor |
|----------|-------|
| Background | `rgba(5,5,16,0.92)` |
| Border bottom | `1.735px solid rgba(255,255,255,0.06)` |
| Height | 54.708px |
| Padding | top 16px, bottom 17.735px, left 23.992px |
| Logo `RUNNIN` | Bold 14px white, tracking 1.4px |
| Badge `.AI` | bg `#00d4ff`, texto `#050510`, Bold 9px, 28.167×17.459px, padding px 6px py 2px |
| Separator `/` | Regular 12px, `rgba(255,255,255,0.12)` |
| Breadcrumb `HIST` | Regular 13px, `rgba(255,255,255,0.55)`, tracking 1.3px |

### Tab Bar Primária (DADOS / CORRIDAS / BENCH)

| Propriedade | Valor |
|-------------|-------|
| Altura container | 41.424px |
| Largura de cada aba | 106.623–115.298px |
| Ativo BG | `#00d4ff` |
| Ativo border | `#00d4ff 1.735px` |
| Ativo texto | `#050510` Bold 12px tracking 0.96px |
| Inativo border | `rgba(255,255,255,0.08) 1.735px` |
| Inativo texto | `rgba(255,255,255,0.55)` Bold 12px tracking 0.96px |

### Bottom Navigation Bar

| Propriedade | Valor |
|-------------|-------|
| Background | `rgba(5,5,16,0.96)` |
| Border top | `1.735px solid rgba(255,255,255,0.06)` |
| Height | 78.591px |
| HIST ativo | texto `#ffffff` + barra ciano `#00d4ff` 19.98×1.979px |
| Inativo texto | `rgba(255,255,255,0.55)` |
| Label font | JetBrains Mono Medium 10px, tracking 1px |
| RUN CTA | 55.982×55.982px, bg `#00d4ff`, texto `#050510` Bold 11px tracking 1.1px |
| RUN sombra | `0 0 30px rgba(0,212,255,0.31), 0 4px 20px rgba(0,0,0,0.5)` |
| RUN anel externo | `#00d4ff` border 1.915–2.166px, opacity 9–12% |

---

## Tela 1 — HIST Dados — 3 Meses (nó 1:9956)

**Nome interno:** `HIST_DADOS_3 MESES`  
**Viewport:** 368px | **Scroll:** 2665px  
**Tab primária ativa:** DADOS | **Sub-tab ativo:** 3 MESES

### Tab Bar de Período (SEMANA / MÊS / 3 MESES)

| Tab | Ativo BG | Ativo border | Ativo texto | Inativo |
|-----|----------|--------------|-------------|---------|
| SEMANA | `rgba(0,212,255,0.09)` | `#00d4ff 1.735px` | `#ffffff` | border `rgba(255,255,255,0.08)` |
| MÊS | same | same | same | same |
| 3 MESES (ativo) | `rgba(0,212,255,0.09)` | `#00d4ff 1.735px` | `#ffffff` | — |

### Grid de Stat Cards (10 cards, 2 colunas)

Cada: 157.915–157.942×89.625px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`, padding 13.718px  
Gap horizontal: 3.985px | Gap vertical: 3.985px

| Label | Valor | Cor valor |
|-------|-------|-----------|
| CORRIDAS | `12` | `#ffffff` |
| DISTÂNCIA TOTAL | `51.0 KM` | `#00d4ff` |
| TEMPO TOTAL | `307:15` | `#ffffff` |
| PACE MÉDIO | `6:08 /KM` | `#ff6b35` |
| BPM MÉDIO | `150 BPM` | `#00d4ff` |
| BPM MÁXIMO | `188 BPM` | `#00d4ff` |
| CALORIAS | `3162 KCAL` | `#ffffff` |
| XP GANHO | `+940 XP` | `#ff6b35` |
| DIST MÉDIA | `4.3 KM/CORRIDA` | `#ffffff` |
| BENCHMARK | `TOP 39%` | `#00d4ff` |

- Label: Regular 12px, `rgba(255,255,255,0.55)`, tracking 0.6px
- Valor: Bold 22px, line-height 24.2px
- Unidade: Regular 12px, `rgba(255,255,255,0.55)`

### Seção "01 — Zonas cardíacas"

Cabeçalho de seção: Bold 22px, white, tracking -0.44px, uppercase + superscript `"01"` 6.6px `#00d4ff`

**Card de distribuição:** 374.847px altura

- Descrição: `"Distribuição média de tempo em cada zona no período"` — Regular 13px, `rgba(255,255,255,0.55)`
- Barra horizontal stacked: 23.992px altura, 284.382px largura

| Zona | Cor | % | Largura approx |
|------|-----|---|----------------|
| Z1 | `#3b82f6` | 4% | 10.9px |
| Z2 | `#22c55e` | 13% | 35.6px |
| Z3 | `#eab308` | 43% | 117.7px |
| Z4 | `#f97316` | 30% | 82.1px |
| Z5 | `#ef4444` | 11% | 30.1px |

**Tabela de zonas** (5 linhas, altura 31.502px cada):

| Zona | Label | BPM range | % | Cor barra |
|------|-------|-----------|---|-----------|
| Z1 | Leve | < 120 | 4% | `#3b82f6` |
| Z2 | Moderado | 120-140 | 13% | `#22c55e` |
| Z3 | Aeróbico | 140-160 | 43% | `#eab308` |
| Z4 | Limiar | 160-175 | 30% | `#f97316` |
| Z5 | Máximo | > 175 | 11% | `#ef4444` |

- Barra track: bg `rgba(255,255,255,0.04)`, height 7.997px

### Seção "02 — Volume semanal"

**Gráfico de linha** (140×284px):

- Linha dados: `#00d4ff`
- Linha meta: `rgba(255,255,255,0.15)` — label `"META 20km"`
- Eixo X: `16/2 · 23/2 · 2/3`
- Eixo Y: `0km · 5km · 10km · 15km · 20km`
- Hint: ícone toque + `"Toque nos pontos para ver valores"` — Regular 9px, `rgba(255,255,255,0.20)`

### Seção "03 — Pace — evolução"

**Gráfico de linha** (140×284px):

- Linha dados com fill gradient
- Linha alvo: `#00d4ff` — label `"ALVO 5:30"`
- Eixo X: `02-19 · 02-23 · 02-27 · 03-01 · 03-04 · 03-07`
- Rodapé: `"↑ mais rápido · ↓ mais lento"` + `"↑ 25s/km"` Bold `#22c55e`

### Seção "04 — BPM — tendência"

**Gráfico de linha** (140×284px):

- Bandas de zona: Z2 `rgba(34,197,94,0.5)` · Z3/Z4 `rgba(249,115,22,0.5)` · Z5 `rgba(239,68,68,0.5)`
- Eixo Y: `130 · 145 · 160 · 175`
- Rodapé: `"Média: 151 bpm"` + `"↑ 2 bpm"` Bold `#ef4444`

### Seção "05 — Evolução — resumo"

**Grid 2×2 de cards de evolução:**

| Métrica | Delta | Cor delta | Detalhe | Histórico |
|---------|-------|-----------|---------|-----------|
| PACE | `-25s ↗` | `#22c55e` | `/km vs período anterior` | `6:20 → 5:55` |
| VOLUME | `+8.6km ↗` | `#22c55e` | `vs período anterior` | `21.2 → 29.8km` |
| BPM MÉDIO | `+2 ↑` | `#ef4444` | `bpm vs período anterior` | `149 → 151 bpm` |
| EFICIÊNCIA | `+8% ↗` | `#22c55e` | `cardíaca (pace/bpm)` | `Mesmo pace, menor BPM` |

- Delta: Bold 24px
- Seta: Regular 16px
- Detalhe: Regular 10px, `rgba(255,255,255,0.55)`
- Histórico: Regular 11px, `rgba(255,255,255,0.35)`
- Border-left positivo: `#22c55e`, negativo: `#ef4444` — 3.985px largura

**Coach.AI Container (variante laranja):**

| Propriedade | Valor |
|-------------|-------|
| Background | `rgba(255,107,53,0.03)` |
| Border left | `1.735px solid #ff6b35` |
| Padding | top 15.995px, left 17.73px, right 15.995px |
| Header | `"COACH.AI > ANÁLISE"` — Regular 13px, `#ff6b35`, line-height 19.5px |
| Corpo | Regular 14px, `rgba(255,255,255,0.80)`, line-height 23.8px |

Texto verbatim: `"Nos últimos 3 meses: 12 corridas, 51.0km. Pace médio 6:08/km — caiu 25s/km no período. BPM médio aumentou 2bpm. Eficiência cardíaca melhorou 8% — mesmo esforço, mais velocidade."`

---

## Tela 2 — HIST Corridas — Lista (nó 1:10393)

**Nome interno:** `HIST_CORRIDAS`  
**Viewport:** 368px | **Scroll:** 2488px  
**Tab primária ativa:** CORRIDAS

### Cabeçalho

- `"Corridas"` — Bold 22px, white, tracking -0.44px, uppercase + superscript `"01"` cyan

### Run Card (anatomia — 179.63px altura)

Container: 319.841px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`

```
RunCard
├── HeaderRow (left:15.99px, top:15.99px, h:39.987px)
│   ├── RunTypeBadge (40×40px)
│   │   ├── bg: rgba(0,212,255,0.07) [padrão] | rgba(255,107,53,0.07) [free]
│   │   ├── border: rgba(0,212,255,0.19) | rgba(255,107,53,0.19)
│   │   └── Number: Bold 16px, #00d4ff | #ff6b35
│   └── RunInfo (flex col)
│       ├── TitleRow (h:20.983px)
│       │   ├── RunTypeName: Medium 14px, #ffffff
│       │   └── [FREE] badge: bg rgba(255,107,53,0.08), "FREE" Bold 8px #ff6b35
│       └── DateRow: Medium 12px, rgba(255,255,255,0.55)
│   └── Distance (direita): Bold 18px #ff6b35 + "km" Regular 11px rgba(255,255,255,0.55)
├── StatsRow (left:15.99px, top:67.96px, border-top rgba(255,255,255,0.08) 1.735px, pt:13.718px, gap:15.995px)
│   ├── [PACE] label 9px rgba(255,255,255,0.55) | valor Bold 14px #ff6b35 + "/km" 10px muted
│   ├── [DURAÇÃO] label 9px | valor Bold 14px #ffffff
│   ├── [BPM] label 9px | valor Bold 14px #00d4ff + "avg" 10px muted
│   └── [XP] label 9px | valor Bold 14px #00d4ff
└── CoachPreview (left:15.99px, top:124.16px, h:36px, overflow:hidden, clampado 2 linhas)
    Medium 12px, rgba(255,255,255,0.40), line-height 18px
```

### Tipos de badge por tipo de corrida

| Tipo | Badge BG | Badge border | Cor número |
|------|----------|--------------|-----------|
| Easy Run / Tempo Run / Long Run / Intervalado | `rgba(0,212,255,0.07)` | `rgba(0,212,255,0.19)` | `#00d4ff` |
| Free Run | `rgba(255,107,53,0.07)` | `rgba(255,107,53,0.19)` | `#ff6b35` |

### Badge "FREE" (inline com título)

- bg `rgba(255,107,53,0.08)`, tamanho 31.203×15.941px
- Texto `"FREE"` — Bold 8px, `#ff6b35`, padding left 5.99px

### Lista de corridas (verbatim)

| # | Tipo | Data | Dist | Pace | Duração | BPM | XP | Preview Coach |
|---|------|------|------|------|---------|-----|----|----|
| 5 | Easy Run | 2026-03-07 | 5.2km | 5:26 | 28:15 | 152 | +85 | "Excelente controle de pace nos km 2-4. Você melhorou 12% vs média de 30 dias..." |
| 5 | Intervalado | 2026-03-05 | 4.8km | 5:00 | 24:00 | 168 | +120 | "Intervalos bem executados. Splits consistentes nos 800m — variação de apenas 3s..." |
| 3 | **Free Run** | 2026-03-04 | 3.2km | 6:43 | 21:30 | 138 | +50 | "Treino livre registrado. Pace leve, BPM controlado em Z2 — boa recuperação ativa..." |
| 5 | Tempo Run | 2026-03-03 | 5km | 5:15 | 26:15 | 162 | +100 | "Boa evolução no tempo run. Negative splits perfeitos — exatamente o que planejamos..." |
| 4 | Easy Run | 2026-03-01 | 3.5km | 6:30 | 22:45 | 138 | +55 | "Boa corrida leve. Seu corpo agradeceu a recuperação ativa após o intervalado..." |
| 8 | Long Run | 2026-02-28 | 8.1km | 6:36 | 53:30 | 148 | +130 | "Long run sólido. Negative splits naturais — sinal de maturidade aeróbica..." |
| 4 | Intervalado | 2026-02-27 | 4.2km | 5:00 | 21:00 | 170 | +115 | "Melhor sessão de intervalados até agora. Pace sub-5 consistente em todas as séries..." |
| 4 | Easy Run | 2026-02-25 | 4km | 6:30 | 26:00 | 140 | +60 | "Corrida de recuperação bem executada. BPM estável em Z2. Cadência 172spm..." |
| 5 | Tempo Run | 2026-02-23 | 4.5km | 5:27 | 24:30 | 158 | +90 | "Primeiro tempo run do plano. Pace controlado, negative splits leves..." |
| 3 | Easy Run | 2026-02-21 | 3km | 6:30 | — | — | — | — |

---

## Tela 3 — HIST Corrida Detalhe (nó 1:10991)

**Nome interno:** `hist_corridas_detalhe corrida`  
**Viewport:** 368px | **Scroll:** 1008px  
**Tab primária ativa:** CORRIDAS

### Back button

- `"← Voltar"` — Medium 13px, `rgba(255,255,255,0.55)`, line-height 19.5px

### Cabeçalho da corrida

- `"Easy Run"` — Bold 22px, white, tracking -0.44px, uppercase + superscript `"01"` cyan
- `"2026-03-07"` — Regular 13px, `rgba(255,255,255,0.55)`, line-height 19.5px

### Metric Cards (3 colunas)

Cada: 103.939–103.966×87.646px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`, padding 11.98px

| Card | Label | Valor | Unidade | Cor valor |
|------|-------|-------|---------|-----------|
| DIST | Regular 12px | `5.2` Bold 22px | `KM` Regular 12px | `#ffffff` |
| PACE | Regular 12px | `5:26` Bold 22px | `/KM` Regular 12px | `#ff6b35` |
| BPM | Regular 12px | `152` Bold 22px | `AVG` Regular 12px | `#00d4ff` |

- Label top: 11.98px; Valor top: 29.98px; Unidade top: 54.19px
- Todos label/unidade: `rgba(255,255,255,0.55)`

### Coach.AI Container (variante ciano — detalhe corrida)

| Propriedade | Valor |
|-------------|-------|
| Top | 221.6px |
| Tamanho | 319.841×198.146px |
| Background | `rgba(0,212,255,0.03)` |
| Border left | `#00d4ff 1.735px` |
| Padding | top 15.995px, left 17.73px, right 15.995px |
| Gap filhos | 3.985px |
| Header | `"COACH.AI"` — Regular 13px, `#00d4ff`, line-height 19.5px |
| Corpo | Regular 14px, `rgba(255,255,255,0.80)`, line-height 23.8px |

Texto verbatim: `"Excelente controle de pace nos km 2-4. Você melhorou 12% vs média de 30 dias. Cadência estável em 174spm — próximo do ideal. Resposta cardíaca saudável, sem picos em Z4."`

### Splits

Label: `"SPLITS"` — Regular 13px, `rgba(255,255,255,0.55)`, tracking 1.3px

Cada linha: 41.722px altura, border-bottom `rgba(255,255,255,0.04) 1.735px`, gap 11.983px, pt 8px, pb 9.735px

| KM | Tempo | Bar fill |
|----|-------|----------|
| KM1 | `5:42` | mínimo (mais lento) |
| KM2 | `5:31` | médio-baixo |
| KM3 | `5:22` | médio-alto |
| KM4 | `5:18` | alto |
| KM5 | `5:26` | máximo (barra cheia) |

- Label KM: Regular 13px, `rgba(255,255,255,0.55)`, width 35.975px
- Barra track: bg `rgba(255,255,255,0.05)`, height 3.985px, flex fill
- Barra fill: bg `rgba(255,255,255,0.15)`, height 3.985px
- Tempo: Bold 16px, white, line-height 24px

### CTA "COMPARTILHAR ↗"

| Propriedade | Valor |
|-------------|-------|
| Top | 679.86px |
| Tamanho | 319.841×45.978px |
| Background | `#00d4ff` |
| Texto | `"COMPARTILHAR ↗"` Bold 12px, `#050510`, tracking 1.2px |
| Padding | px 20px, py 14px |

### Botão "VER CONVERSA COM COACH"

| Propriedade | Valor |
|-------------|-------|
| Top | 737.82px |
| Tamanho | 319.841×46.954px |
| Background | `rgba(255,107,53,0.03)` |
| Border | `rgba(255,107,53,0.13) 1.735px` |
| Padding | px 13.718px, py 13.735px |
| Layout | row, space-between |
| Texto | `"VER CONVERSA COM COACH"` Bold 13px, `#ff6b35`, line-height 19.5px |
| Ícone direito | chevron 13.989px |

---

## Tela 4 — HIST Corrida Detalhe — Coach Chat (nó 1:11403)

**Nome interno:** `HIST_CORRIDA_DETALHE COACH`  
**Viewport:** 368px | **Scroll:** 1153px  
**TopNav breadcrumb:** `COACH` (não `HIST`)  
**Bottom nav ativo:** HIST

### Cabeçalho da sessão

Container (left: 23.99px, top: 70.7px, w: 319.841px):

- **Header row** (h: 36px, gap 11.983px):
  - Back button: 27.95×31.962px (apenas ícone seta)
  - Título: `"Easy Run"` — Bold 18px, white, line-height 18px
  - Subtítulo: `"2026-03-07 · 5.2km · 5:26/km"` — Regular 12px, `rgba(255,255,255,0.55)`, line-height 18px

### Stats Bar (top: 52px, h: 60.13px)

Container: bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`, padding 13.718px, gap 15.995px

| Stat | Label | Valor | Cor |
|------|-------|-------|-----|
| DIST | Regular 9px tracking 0.9px `rgba(255,255,255,0.55)` | `5.2km` Bold 16px | `#ffffff` |
| PACE | same | `5:26` Bold 16px | `#ff6b35` |
| BPM | same | `152` Bold 16px | `#00d4ff` |
| XP | same | `+85` Bold 16px | `#00d4ff` |

### Seção "Conversa"

Cabeçalho: `"Conversa"` Bold 22px, white + superscript `"01"` cyan

### Chat (top: 168.3px, gap: 7.997px)

**Regras de alinhamento:**
- Bubbles COACH.AI: esquerda, 271.857px largura, border `#ff6b35 1.735px`
- Bubbles VOCÊ: direita (justify-end), variável em largura

**Bubble COACH.AI:**
- bg `rgba(255,255,255,0.03)`, border `#ff6b35 1.735px`
- Padding: top 13.718px, left 13.718px, right 13.718px, bottom 1.735px
- Label `"COACH.AI"` — Bold 10px, `#ff6b35`, tracking 1px (! diferente do Coach Chat de TREINO que usa Regular)
- Timestamp — Regular 9px, `rgba(255,255,255,0.20)`
- Corpo — Regular 13px, `rgba(255,255,255,0.80)`, line-height 21.45px

**Bubble VOCÊ:**
- bg `rgba(0,212,255,0.07)`, border `rgba(0,212,255,0.14) 1.735px` (sem borda esquerda neste contexto)
- Padding: top 13.718px, left 11.983px, right 13.718px, bottom 1.735px
- Label `"VOCÊ"` — Bold 10px, `#00d4ff`, tracking 1px
- Timestamp — Regular 9px, `rgba(255,255,255,0.20)`

### Mensagens verbatim

| Sender | Hora | Texto |
|--------|------|-------|
| COACH.AI | 21:15 | `"Hoje é dia de Easy Run. Meta: 5.2km a 5:26/km. Lembre de aquecer 5min antes de começar. Vamos?"` |
| VOCÊ | 21:16 | `"Bora! Estou pronto."` |
| COACH.AI | 21:28 | `"Km 2 concluído em 5:31. BPM controlado, bom ritmo."` |
| COACH.AI | 21:05 | `"Excelente controle de pace nos km 2-4. Você melhorou 12% vs média de 30 dias. Cadência estável em 174spm — próximo do ideal. Resposta cardíaca saudável, sem picos em Z4."` |
| VOCÊ | 21:06 | `"Valeu! Me senti bem nesse treino."` |
| COACH.AI | 21:07 | `"Excelente sessão. Seu percentile subiu para TOP 25%. Continua assim que a evolução vem."` |

### Banner "ANÁLISE VERIFICADA" (bottom, top: 910.7px)

Container: 319.841×60.455px, bg `rgba(255,107,53,0.03)`, border `rgba(255,107,53,0.08) 1.735px`, padding px 13.718px, py 13.735px, gap 11.983px

- Ícone verificado: 19.98×19.98px (MuiSvgIconRoot)
- `"ANÁLISE VERIFICADA"` — Bold 11px, `#ff6b35`, line-height 16.5px
- `"Baseada em dados reais da sua corrida"` — Regular 11px, `rgba(255,255,255,0.55)`, line-height 16.5px

---

## Tela 5 — HIST Benchmark (nó 1:11114)

**Nome interno:** `HIST_BENCH`  
**Viewport:** 393.851 × 851.898px  
**Tab primária ativa:** BENCH

### Cabeçalho

- `"Benchmark"` — Bold 22px, white, tracking -0.44px, uppercase + superscript `"01"` cyan

### Ranking Card (345.867×250.928px)

bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`

- `"TOP 30%"` — Bold **48px**, `#00d4ff`, line-height 72px (left: 19.98px, top: 19.98px)
- `"entre intermediários · Easy Run 5K"` — Regular 13px, `rgba(255,255,255,0.55)`, top: 91.98px
- Gráfico de distribuição (curva de bell): top 127.5px, 302.437×99.981px
  - Curva vetorial (SVG)
  - Linha tracejada da posição do usuário
  - Marker dot
  - Label `"VOCÊ"` — Regular ~9.451px, `#00d4ff` (posicionado no topo da curva ~TOP 30%)

### Metric Rows (4 linhas, gap 3.985px)

Cada: 345.867×48.418px (última flex-grow), bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`, padding 13.718px, layout space-between

| Métrica | Valor usuário | Comparação |
|---------|---------------|------------|
| Pace médio | `5:26` Bold 14px `#00d4ff` | `vs 6:12` Regular 13px `rgba(255,255,255,0.55)` |
| Distância semanal | `14km` Bold 14px `#00d4ff` | `vs 10km` |
| Consistência | `85%` Bold 14px `#00d4ff` | `vs 62%` |
| BPM médio | `152` Bold 14px `#00d4ff` | `vs 158` |

- Label: Regular 13px, `rgba(255,255,255,0.55)`
- Valor usuário sempre em `#00d4ff`
- Gap entre valor e comparação: 15.995px

---

## Tokens de Cor — HIST

| Token | Hex / RGBA | Uso |
|-------|-----------|-----|
| `color/bg/base` | `#050510` | Fundo |
| `color/nav/topnav` | `rgba(5,5,16,0.92)` | TopNav |
| `color/nav/bottomnav` | `rgba(5,5,16,0.96)` | BottomNav |
| `color/brand/accent` | `#00d4ff` | Tab ativa, valores dist/bpm/xp/bench, RUN CTA |
| `color/brand/coach` | `#ff6b35` | Pace, XP secundário, coach bubble border, banner |
| `color/zone/z1` | `#3b82f6` | Zona 1 — Leve |
| `color/zone/z2` | `#22c55e` | Zona 2 — Moderado / positivo |
| `color/zone/z3` | `#eab308` | Zona 3 — Aeróbico |
| `color/zone/z4` | `#f97316` | Zona 4 — Limiar |
| `color/zone/z5` | `#ef4444` | Zona 5 — Máximo / negativo |
| `color/text/high` | `#ffffff` | Títulos, valores neutros |
| `color/text/medium` | `rgba(255,255,255,0.80)` | Corpo coach |
| `color/text/muted` | `rgba(255,255,255,0.55)` | Labels, subtítulos, inativo |
| `color/text/dim` | `rgba(255,255,255,0.40)` | Preview coach clampado |
| `color/text/ghost` | `rgba(255,255,255,0.20)` | Timestamps |
| `color/surface/card` | `rgba(255,255,255,0.03)` | Cards padrão |
| `color/border/default` | `rgba(255,255,255,0.08)` | Bordas padrão |
| `color/surface/active` | `rgba(0,212,255,0.09)` | Sub-tab período ativo |
| `color/surface/coach/cyan` | `rgba(0,212,255,0.03)` | Coach card variante ciano |
| `color/surface/coach/orange` | `rgba(255,107,53,0.03)` | Coach card variante laranja |
| `color/badge/free/bg` | `rgba(255,107,53,0.08)` | Badge FREE |
| `color/badge/run/cyan` | `rgba(0,212,255,0.07)` | Badge ícone corrida padrão |
| `color/badge/run/orange` | `rgba(255,107,53,0.07)` | Badge ícone free run |
| `color/split/track` | `rgba(255,255,255,0.05)` | Track das barras de split |
| `color/split/fill` | `rgba(255,255,255,0.15)` | Fill das barras de split |
| `color/chart/goal` | `rgba(255,255,255,0.15)` | Linha de meta no gráfico volume |
| `color/evolution/positive` | `#22c55e` | Border e delta positivo |
| `color/evolution/negative` | `#ef4444` | Border e delta negativo |

## Tokens de Tipografia — HIST

| Token | Fonte | Peso | Tamanho | LS | LH |
|-------|-------|------|---------|----|----|
| `type/display/h1` | JetBrains Mono | Bold | 28px | -0.84px | 29.4px |
| `type/heading/h2` | JetBrains Mono | Bold | 22px | -0.44px | 24.2px |
| `type/heading/run` | JetBrains Mono | Bold | 18px | — | 18px |
| `type/stats/benchmark` | JetBrains Mono | Bold | 48px | — | 72px |
| `type/stats/large` | JetBrains Mono | Bold | 22px | — | 24.2px |
| `type/stats/medium` | JetBrains Mono | Bold | 24px | — | 24px |
| `type/stats/small` | JetBrains Mono | Bold | 16px | — | 24px |
| `type/stats/run` | JetBrains Mono | Bold | 14px | — | 21px |
| `type/card/label` | JetBrains Mono | Regular | 12px | 0.6px | 18px |
| `type/body/main` | JetBrains Mono | Regular | 13px | — | 19.5px |
| `type/body/coach` | JetBrains Mono | Regular | 14px | — | 23.8px |
| `type/chat/body` | JetBrains Mono | Regular | 13px | — | 21.45px |
| `type/chat/sender` | JetBrains Mono | Bold | 10px | 1px | 15px |
| `type/chat/timestamp` | JetBrains Mono | Regular | 9px | — | 13.5px |
| `type/run/stat/label` | JetBrains Mono | Regular | 9px | 0.9px | 13.5px |
| `type/run/badge/free` | JetBrains Mono | Bold | 8px | — | 12px |
| `type/tab/label` | JetBrains Mono | Bold | 12px | 0.96px | 18px |
| `type/label/section` | JetBrains Mono | Regular | 12px | 2.4px | 18px |
| `type/label/small` | JetBrains Mono | Regular | 10–11px | 1px | 15–16.5px |
| `type/superscript` | JetBrains Mono | Regular | 6.6px | — | — |
| `type/cta` | JetBrains Mono | Bold | 12px | 1.2px | 18px |
| `type/nav/label` | JetBrains Mono | Medium | 10px | 1px | 15px |

---

## Componentes identificados

| Componente | Reutilizável | Descrição |
|-----------|:---:|-----------|
| `HistTabBar` | Sim | 3 abas DADOS/CORRIDAS/BENCH |
| `PeriodTabBar` | Sim | Sub-abas SEMANA/MÊS/3 MESES (somente na aba DADOS) |
| `StatCardGrid` | Sim | Grid 2 colunas de 10 stat cards; label/valor/unidade com cor por tipo |
| `ZoneDistributionCard` | Sim | Barra horizontal stacked + tabela 5 linhas com barras de zona |
| `LineChartCard` | Sim | Card com gráfico de linha, legenda, hint de toque; 3 variantes (volume/pace/bpm) |
| `EvolutionCard` | Sim | Card 2×2 com delta, seta, detalhe e histórico; border-left colorido |
| `CoachAnalysisCard` | Sim | Coach.AI com variante ciano (detalhe) ou laranja (análise) |
| `RunCard` | Sim | Card de corrida com badge de tipo, stats, preview coach; 2 variantes (padrão/free) |
| `RunTypeBadge` | Sim | Quadrado 40×40px com número e cor por tipo (cyan/orange) |
| `RunDetailMetricRow` | Sim | 3 cards métricas DIST/PACE/BPM lado a lado |
| `SplitBarsSection` | Sim | Lista de splits com barra horizontal proporcional |
| `ShareCTA` | Sim | Botão fullwidth cyan "COMPARTILHAR ↗" |
| `CoachConversationButton` | Sim | Botão laranja "VER CONVERSA COM COACH" com chevron |
| `HistChatBubbleCoach` | Sim | Bubble esquerda com borda laranja, sender COACH.AI laranja |
| `HistChatBubbleUser` | Sim | Bubble direita com bg cyan tintado, sender VOCÊ em cyan |
| `AnalysisVerifiedBanner` | Não | Banner bottom com ícone verificado + texto, bg laranja |
| `BenchmarkRankingCard` | Não | Card "TOP X%" com curva de bell SVG + posição VOCÊ |
| `BenchmarkMetricRow` | Sim | Linha label + valor usuário (cyan) + comparação (muted) |

---

## Lacunas / Decisões pendentes

1. **Gráficos (linha + barra):** implementar com `CustomPainter` Flutter ou biblioteca (ex: `fl_chart`)? Os gráficos têm interação de toque para revelar valores.
2. **Períodos DADOS:** o design mostra só `3 MESES` — como SEMANA e MÊS diferem (mais ou menos cards? janela de datas no eixo X)?
3. **Curva de bell do Benchmark:** é SVG estático ou renderizado dinamicamente com a posição real do usuário?
4. **Chat da corrida (1:11403):** os horários (21:15, 21:28, 21:05, 21:07) estão fora de ordem — bug do design ou representação intencional de mensagens de diferentes momentos?
5. **FREE badge na lista:** o número do badge de Free Run continua sendo sequencial global ou reinicia por tipo?
6. **Scroll vs paginação:** as telas DADOS (2665px) e CORRIDAS (2488px) são muito longas — há scroll infinito / paginação ao fundo?
7. **Splits:** a barra de preenchimento é relativa ao KM mais rápido ou ao alvo de pace?
