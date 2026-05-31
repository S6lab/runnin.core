# Telas: RUN JOURNEY (Fluxo completo de corrida)

> Extraído via Figma MCP — Nós `1:5974`, `1:6193`, `1:6527`, `1:6768`, `1:6980`, `1:7105`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)

---

## Visão geral

Fluxo completo de uma sessão de corrida: pré-corrida → corrida ativa → conquista → relatório → compartilhar. Todas as telas têm o **TopNavBar** e o **BottomTabBar** globais (definidos em HOME.md), exceto a tela de corrida ativa.

---

## Mapa do fluxo

```
[Home → INICIAR SESSÃO] 
    → Coach Intro (4 slides)
        → PRE_CORRIDA (aquecimento + alertas + música)
            → CORRIDA_ATIVA (HUD em tempo real)
                → CONQUISTA BADGE (modal overlay)
                    → REPORT_CORRIDA (relatório pós-corrida)
                        → COMPARTILHAR (card ou foto+overlay)
                            → Home
```

---

# 1. PRE_CORRIDA — Pré-Corrida (nó 1:5974)

**Dimensões:** 367 × 851.519 px (viewport), **2885.495 px** de altura scrollável  
**Seções:** 4 seções numeradas (Briefing · Aquecimento & Mobilidade · Alertas · Música)

## TopNav

- **Background:** `rgba(5,5,16,0.92)`, border-bottom `rgba(255,255,255,0.06)` 1.741 px
- **Left:** botão VOLTAR (40 px) + "RUNNIN" Bold 14px + ".AI" badge ciano + "/" dim + **"PREP"** 13px dim
- **Right:** sem elemento

## Seção 01 — Briefing

**SectionHead:** "Briefing" + superscript "01"

**Card COACH.AI (left-border `#FF6B35`, bg `rgba(255,107,53,0.03)`):**
- Label: "COACH.AI > BRIEFING" — 13 px `#FF6B35`, tracking 1.3 px
- Texto: "Easy Run hoje — pace entre 6:00 e 6:30. Foco: manter constância, sem acelerar no final. Seu corpo precisa de volume, não de intensidade."
  - 15 px Regular, `rgba(255,255,255,0.80)`, line-height 25.5 px

## Seção 02 — Aquecimento & Mobilidade (1545 px de altura)

**SectionHead:** "Aquecimento & Mobilidade" + superscript "02"

**Card intro COACH.AI (left-border `#00D4FF`, bg `rgba(0,212,255,0.03)`):**
- Label: "COACH.AI > MOBILIDADE PRÉ-CORRIDA" — 13 px `#00D4FF`
- Texto: "Prepare articulações e ative cadeias musculares antes de correr. 5-8 minutos reduzem risco de lesão e melhoram economia de corrida."
  - 14 px Regular, `rgba(255,255,255,0.75)`, line-height 23.8 px
- **Tamanho:** 319.428 × 220.036 px, padding pl 21.74, pr 20, pt 20, gap 10

### 8 Cards de Exercício

**Estilo do card:**  
- Tamanho: 319.428 × 134.437 px (padrão) ou 152.422 px (maior)
- Background: `rgba(255,255,255,0.03)`, border 1.741 px `rgba(255,255,255,0.08)`
- Padding: 17.74 px todos os lados, gap 12 px (ícone + info)
- Gap entre cards: 4 px

**Tipografia:**
- Nome do exercício: Regular 14 px, `#FFFFFF`, line-height 21 px
- Repetições/tempo: Regular 12 px, `#00D4FF`, line-height 18 px
- Descrição: Regular 12 px, `rgba(255,255,255,0.55)`, line-height 18 px
- Ícone: 27.998 × 21.985 px (asset SVG)

| # | Nome | Reps | Descrição |
|---|------|------|-----------|
| 1 | Rotação de tornozelos | 10x cada lado | Círculos amplos, sentido horário e anti-horário. Ativa tibial anterior e estabilizadores. |
| 2 | Agachamento profundo (deep squat hold) | 30s | Desça até o fundo, cotovelos empurrando joelhos para fora. Abre quadril e tornozelo. |
| 3 | Lunge com rotação torácica | 6x cada lado | Avanço com o pé, gire o tronco para o lado da perna da frente. Abre T-spine e flexores do quadril. |
| 4 | Leg swings (frente-trás) | 10x cada perna | Segure em algo, balance a perna como pêndulo. Ativa isquiotibiais e flexores do quadril. |
| 5 | Leg swings (lateral) | 10x cada perna | Movimento lateral cruzando a linha média. Ativa adutores e abdutores. |
| 6 | Elevação de panturrilha + dorsiflexão | 12x | Suba na ponta dos pés, depois puxe os dedos para cima. Ativa sóleo, gastrocnêmio e tibial. |
| 7 | Caminhada do inchworm | 5x | Em pé, dobre e caminhe com as mãos até prancha, depois volte. Ativa core e posterior da coxa. |
| 8 | Skip A (elevação de joelhos) | 2x 15m | Elevação alternada de joelhos com braços coordenados. Drill de cadência e ativação neural. |

**Card de dica COACH.AI:**
- Background: `rgba(255,107,53,0.03)`, border `rgba(255,107,53,0.13)` 1.741 px
- Tamanho: 319.428 × 159.905 px, padding pt 17.74, px 17.74, gap 4
- Label: "COACH.AI > DICA" — `#FF6B35`
- Texto: "Para sessões de Easy Run, foque em tornozelos, quadril e panturrilha. Em dias de intervalado, adicione os drills de Skip A e leg swings para ativar fibras rápidas."

## Seção 03 — Alertas

**SectionHead:** "Alertas" + superscript "03"

**5 Toggle rows** (cada 77.980 px ou 97.488 px de altura):
- Background: `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08)` 1.741 px
- Título: Medium 14 px, `#FFFFFF`, line-height 21 px
- Subtítulo: Medium 13 px, `rgba(255,255,255,0.55)`

**Toggle pill:**
- ON: bg `#00D4FF`, thumb `#050510`, tamanho 35.997 × 19.998 px
- OFF: bg `rgba(255,255,255,0.10)`, thumb `rgba(255,255,255,0.30)`

| # | Título | Subtítulo | Estado |
|---|--------|-----------|--------|
| 1 | Alerta a cada km | Coach comenta pace e distância | ON |
| 2 | Pace fora do range | Avisa se sair do alvo | ON |
| 3 | BPM elevado | Alerta se BPM entrar zona 5 | ON |
| 4 | Splits por km | Mostra split detalhado | OFF |
| 5 | Motivação | Mensagens de motivação durante a corrida | ON |

## Seção 04 — Música

**SectionHead:** "Música" + superscript "04"

- Título: "Abra seu app de música" — 14 px, `#FFFFFF`
- Sub: "O Coach fala por cima — volume abaixa automaticamente." — 13 px, `rgba(255,255,255,0.55)`
- **3 botões de app** (row, gap 8):
  - Spotify / YT Music / Apple Music
  - Bg: `rgba(255,255,255,0.05)`, border `rgba(255,255,255,0.08)`, Medium 13 px dim

## CTA Principal

**"[ COMEÇAR CORRIDA ] ↗"** — fullwidth, bg `#00D4FF`, h 45.955 px, Bold 12 px `#050510`

## Bottom Tab Bar

Presente (ver HOME.md). Tabs todas inativas.

---

# 2. CORRIDA_ATIVA — HUD em Tempo Real (nó 1:6193)

**Dimensões:** 393.545 × 851.519 px  
**Sem scroll, sem bottom tab bar, sem TopNavBar padrão.**  
**Estética:** terminal HUD, overlay ciano 2% fullscreen.

## Status Bar (topo)

- **Padding:** px 24, pb 17.741, pt 16, h 53.247 px
- **Border-bottom:** `rgba(255,255,255,0.05)` 1.741 px
- **Left:** dot ciano 8×8 px (opacity 44%) + "RUN.ACTIVE" — Regular 13 px `#00D4FF`, tracking 1.95 px
- **Right:** "EASY_RUN.exe" — Regular 13 px `rgba(255,255,255,0.55)`

## Timer Central

- **"00 : 03"** — Bold **70.838 px**, tracking −3.5419 px, line-height 60.212 px
- **"00" e "03":** `#FFFFFF`
- **":":** `#00D4FF`
- **"TEMPO DECORRIDO":** Regular 13 px, `rgba(255,255,255,0.55)`, tracking 1.3 px

## Grade 2×2 de Métricas

Cada célula: 172.774 px de largura, 100.753 px de altura  
**Border hairline:** 1.741 px `rgba(255,255,255,0.05)` (divisórias entre células)

| Métrica | Label | Superscript | Valor | Unidade/Zona | Cor valor |
|---------|-------|-------------|-------|--------------|-----------|
| PACE | PACE | 01 | 05:42 | /KM | `#FF6B35` |
| DIST | DIST | 02 | 0.01 | KM | `#FFFFFF` |
| BPM | BPM | 03 | 145 | Z3:AEROBIC | `#00D4FF` |
| CAL | CAL | 04 | 0 | KCAL | `#FFFFFF` |

**Tipografia métricas:**
- Label: Regular 13 px, `rgba(255,255,255,0.55)`, tracking 1.56 px
- Superscript: Regular **9 px**, `#00D4FF` (inline após label)
- Valor: Bold **28 px**, line-height 28 px
- Unidade/zona: Regular 13 px, `rgba(255,255,255,0.55)`, tracking 1.3 px

## Splits (scroll horizontal)

**Header:** "SPLITS →" — Regular 13 px `rgba(255,255,255,0.55)`, tracking 1.56 px

**5 Cards de split** (71.422 × 83.421 px cada):
- Border: 1.741 px `rgba(255,255,255,0.05)`
- Padding: 11.727 px todos, pb 1.741

| KM | Pace | Status | Cor status |
|----|------|--------|-----------|
| KM01 | 05:42 | OK | `#FF6B35` |
| KM02 | 05:31 | OK | `#FF6B35` |
| KM03 | --:-- | PEND | `rgba(255,255,255,0.10)` |
| KM04 | --:-- | PEND | `rgba(255,255,255,0.10)` |
| KM05 | --:-- | PEND | `rgba(255,255,255,0.10)` |

**Tipografia dos cards de split:**
- Label KM: Regular 12 px `rgba(255,255,255,0.55)`
- Tempo (completo): Bold 16 px `#FFFFFF`
- Tempo (pendente): Bold 16 px `rgba(255,255,255,0.10)`
- Status "OK": Regular 12 px `#FF6B35`, tracking 1.8 px
- Status "PEND": Regular 12 px `rgba(255,255,255,0.10)`, tracking 1.8 px

## Mapa/Rota

- **Container:** 345.549 × 143.988 px, border 1.741 px `rgba(255,255,255,0.08)`, bg `rgba(255,255,255,0.01)`
- Conteúdo: asset SVG de rota

## Botões de Ação

**Row, gap 12, tamanho 345.549 × 50.962 px total:**

| Botão | Largura | Background | Border | Texto | Cor texto |
|-------|---------|------------|--------|-------|-----------|
| PAUSAR | ~168.5 px | transparente | 1.741 px `rgba(255,255,255,0.15)` | "PAUSAR" | `rgba(255,255,255,0.55)` |
| FINALIZAR ↗ | ~165 px | `#00D4FF` | — | "FINALIZAR ↗" | `#050510` |

**Tipografia botões:** Bold 13 px, tracking 1.3 px

---

# 3. CONQUISTA BADGE — Modal pós-corrida (nó 1:6527)

**Tela de relatório com modal de badge desbloqueado sobreposto.**

## Overlay de Fundo

- **Fullscreen dim:** `rgba(5,5,16,0.92)`

## Modal BadgeUnlock (303.43 × 579.923 px, centralizado)

- **Background:** `#050510`
- **Top line:** 4 px sólido `#00D4FF` (fullwidth do modal)
- **Bottom line:** 1.986 px `rgba(0,212,255,0.25)` (fullwidth do modal)

### Badge Icon Area

- **Anel externo (ciano):** 127.958 × 127.958 px, border 2.785 px `#00D4FF`, opacity 14%
- **Anel intermediário (laranja):** 95.85 × 95.85 px, border 2.086 px `#FF6B35`, opacity 8%
- **Quadrado badge:** 79.993 × 79.993 px, bg `#00D4FF`
- **Ícone SVG:** 35.997 × 35.997 px (asset específico do badge)

### Conteúdo do Modal

| Elemento | Texto | Tipografia | Cor |
|----------|-------|-----------|-----|
| Tag | `// CONQUISTA DESBLOQUEADA` | Regular 12 px, tracking 2.4 px | `#00D4FF` |
| Heading | `Pace Sub-5:30` | Bold **28 px**, −0.84 px | `#FFFFFF` |
| Subtitle | `Pace abaixo de 5:30/km` | Regular 14 px, line-height 22.4 px | `rgba(255,255,255,0.55)` |
| XP chip | `+30 XP` | Bold 16 px | `#FF6B35` |

**XP chip:**
- Tamanho: 101.053 × 47.452 px
- Background: `rgba(255,107,53,0.07)`, border 1.741 px `rgba(255,107,53,0.19)`

**Card COACH.AI** (left-border `#FF6B35`, bg `rgba(255,107,53,0.02)`, 239.435 × 134.165 px):
- Label: "COACH.AI" — Regular 10 px `#FF6B35`
- Texto: "Mais uma conquista no caminho. Pace Sub-5:30 desbloqueado — bora pra próxima."
  - Regular 13 px, `rgba(255,255,255,0.70)`, line-height 20.8 px

**CTA:** "CONTINUAR ↗" — 239.435 × 45.955 px, bg `#00D4FF`, Bold 12 px `#050510`

---

# 4. REPORT_CORRIDA — Relatório Pós-Corrida (nó 1:6768)

**Dimensões:** 367.826 × 851.519 px (viewport), **1807.953 px** scrollável  
**TopNav:** "RUNNIN .AI / RELATÓRIO"  
**BottomTabBar:** presente (ver HOME.md)

## Seção 01 — Resumo

**SectionHead:** "Resumo" + "01"

**Card COACH.AI Análise** (left-border `#00D4FF`, bg `rgba(0,212,255,0.03)`)  
- Label: "COACH.AI > ANÁLISE" — Regular 13 px `#00D4FF`
- Texto: "Boa, Lucas! 5.2km em 28:15, pace médio 5:26. Excelente controle de pace nos km 2-4. Você melhorou 12% vs média de 30 dias. Cadência estável em 174spm — próximo do ideal. Resposta cardíaca saudável, sem picos em Z4."
  - Regular 15 px, `rgba(255,255,255,0.85)`, line-height 25.5 px

**Grade de stats (2 linhas × 3 colunas):**

Cada card: ~103.9 × 93.664 px, bg `rgba(255,255,255,0.03)`, border 1.741 px `rgba(255,255,255,0.08)`, padding 11.98 px

| Row | Label | Valor | Unidade | Cor valor |
|-----|-------|-------|---------|-----------|
| 1 | DISTÂNCIA | 5.2 | KM | `#FFFFFF` |
| 1 | TEMPO | 28:15 | — | `#FFFFFF` |
| 1 | PACE MÉD | 5:26 | /KM | `#FF6B35` |
| 2 | BPM MÉDIO | 152 | BPM | `#00D4FF` |
| 2 | BPM MÁX | 172 | BPM | `#00D4FF` |
| 2 | XP GANHO | +85 | EARNED | `#00D4FF` |

**Tipografia dos cards:**
- Label: Regular 13 px, `rgba(255,255,255,0.55)`, tracking 0.65 px
- Valor: Bold **22 px**, line-height 24.2 px
- Unidade: Regular 13 px dim

## Seção 02 — Splits

**SectionHead:** "Splits" + "02"

**5 linhas de split** (49.692 px cada, border-bottom `rgba(255,255,255,0.04)` 1.741 px):
- Label KM: Regular 13 px dim, width 41.993 px
- Barra (track bg `rgba(255,255,255,0.05)`, h 5.991 px):
  - KM 01–04: fill `rgba(255,255,255,0.25)` (dim)
  - KM 05 (último/melhor): fill `#00D4FF`
- Tempo: Bold 16 px `#FFFFFF`, text-right

| KM | Tempo |
|----|-------|
| KM 01 | 5:42 |
| KM 02 | 5:31 |
| KM 03 | 5:22 |
| KM 04 | 5:18 |
| KM 05 | 5:26 |

## Seção 03 — Zonas Cardíacas

**SectionHead:** "Zonas cardíacas" + "03"

**5 linhas de zona** (31.502 px cada, py 6 px, gap 5.991 px):
- Label zona (ex: Z1): Regular 13 px, cor da zona
- Nome: Regular 13 px, `#FFFFFF`
- Track: bg `rgba(255,255,255,0.04)`, h 15.995 px
- Fill: cor da zona, largura proporcional ao percentual
- Percentual: Bold 12 px `#FFFFFF`, text-right

| Zona | Nome | Cor | Percentual |
|------|------|-----|------------|
| Z1 | Leve | `#3B82F6` | 5% |
| Z2 | Moderado | `#22C55E` | 15% |
| Z3 | Aeróbico | `#EAB308` | 55% |
| Z4 | Limiar | `#F97316` | 20% |
| Z5 | Máximo | `#EF4444` | 5% |

## Seção 04 — Benchmark

**SectionHead:** "Benchmark" + "04"

**Card** (bg `rgba(255,255,255,0.03)`, border 1.741 px dim, padding 21.715 px):
- "TOP 25%" — Bold **36 px** `#00D4FF`, line-height 54 px
- "dos intermediários nessa distância" — Regular 14 px `rgba(255,255,255,0.55)`
- "Pace 12% melhor que sua média de 30 dias" — Regular 14 px `#FF6B35`

## Seção 05 — Conquistas

**SectionHead:** "Conquistas" + "05"

**2 Badge chips** (row):

| Badge | Largura | Ícone | Texto |
|-------|---------|-------|-------|
| Streak 12d | 139.426 px | fire icon 17.974 px | "Streak 12d" |
| Pace Sub-5:30 | 162.794 px | speed icon 17.974 px | "Pace Sub-5:30" |

**Estilo badge chip:**
- Bg: `rgba(0,212,255,0.08)`, border 1.741 px `rgba(0,212,255,0.25)`
- Padding: px 17.73, py 13.735, gap 7.997
- Texto: Regular 13 px `#FFFFFF`

**Linha XP:** "+85 XP → Nível: Corredor (340/500)" — Regular 14 px `#00D4FF`

## Botões de Ação

**Row, gap 11.983, tamanho 319.841 × 49.448 px:**

| Botão | Background | Border | Texto | Cor texto |
|-------|------------|--------|-------|-----------|
| COMPARTILHAR ↗ | `#00D4FF` | — | "COMPARTILHAR ↗" | `#050510` |
| HOME | transparente | 1.741 px `rgba(255,255,255,0.20)` | "HOME" | `#FFFFFF` |

---

# 5. COMPARTILHAR CORRIDA — Card (nó 1:6980)

**Dimensões:** 367.826 × 851.519 px (viewport), 1029.522 px scrollável  
**TopNav:** "RUNNIN .AI / SHARE"  
**BottomTabBar:** presente

## Tab Toggle CARD / CÂMERA

**Dois segmentos, fullwidth, h 45.436 px:**

| Tab | Ativo | Inativo |
|-----|-------|---------|
| CARD | bg `#00D4FF`, texto Bold 12 px `#050510` | bg transparente, border dim |
| CÂMERA + OVERLAY | bg transparente, border dim, texto dim | bg `#00D4FF`, texto Bold `#050510` |

## Preview do Card (319.841 × 352.346 px)

- **Border:** 1.741 px `#00D4FF`
- Background: `#050510`

**Conteúdo interno (padding 23.99 px):**

| Elemento | Valor | Tipografia | Cor |
|----------|-------|-----------|-----|
| Logo "RUNNIN .AI" | RUNNIN + .AI chip | Bold 14px + Bold 9px | `#FFF` + `#050510` |
| Distância | "5.2 km" | Bold 48 px + Bold 18 px (unidade) | `#FFFFFF` |
| Tempo | "28:15" | Bold 20 px | `#FF6B35` |
| Pace | "Pace: 5:26/km" | Regular 14 px | `rgba(255,255,255,0.55)` |
| Mapa de rota SVG | polilinha + marcadores | 7.443 px Regular dim | `rgba(255,255,255,0.55)` |
| Legenda Coach | "Semana 3 do plano 10K — pace melhorou 15%" | Regular 13 px | `rgba(255,255,255,0.55)` |
| Streak | fire icon + "12 dias seguidos" | Bold 14 px | `#00D4FF` |
| BPM | "BPM" label + "152" valor | Regular 12 px + Bold 14 px | dim + `#FFF` |
| Rank | "RANK" label + "TOP 25%" valor | Regular 12 px + Bold 14 px | dim + `#00D4FF` |

## Seletor de Tema do Card

**3 botões horizontais:**

| Botão | Estado | Background | Border | Texto |
|-------|--------|------------|--------|-------|
| Dark | Ativo | `rgba(255,255,255,0.12)` | 1.741 px `#00D4FF` | `#FFFFFF` |
| Color | Inativo | — | 1.741 px dim | dim |
| Minimal | Inativo | — | 1.741 px dim | dim |

**Tipografia:** Medium 13 px, h 42.942 px

## Lista de Destinos de Compartilhamento

**4 opções** (52.43 px cada, bg `rgba(255,255,255,0.03)`, border dim, gap 7.997 px):
1. "Instagram Stories" ↗
2. "WhatsApp" ↗
3. "Twitter/X" ↗
4. "Salvar imagem" ↗

**Tipografia:** Medium 14 px `#FFFFFF`, arrow `rgba(255,255,255,0.55)`

## Botão "VOLTAR HOME"

- Border 1.741 px `rgba(255,255,255,0.20)`, Bold 12 px `#FFFFFF`, h 49.448 px

---

# 6. COMPARTILHAR CORRIDA — Câmera + Overlay (nó 1:7105)

**Dimensões:** 367.826 × 851.519 px (viewport), 1271.26 px scrollável  
**TopNav:** "RUNNIN .AI / SHARE"  
**Tab ativo:** "CÂMERA + OVERLAY" (estados invertidos vs nó 1:6980)

## Preview da Foto (319.841 × 426.437 px)

- **Foto de fundo:** fullbleed, foto aérea de pista de corrida
- **Gradient overlay:** linear top→bottom, `rgba(5,5,16,0.30)` → `rgba(5,5,16,0.85)`
- **Rota SVG sobreposta:** 276.412 × 49.99 px

## Chips de Stats Sobrepostos na Foto

**Estilo dos chips:** bg `rgba(5,5,16,0.60)`, border 1.741 px `rgba(255,255,255,0.15)`, padding pt 9.732, px 13.718

| Chip | Label | Valor | Cor valor | Dimensões |
|------|-------|-------|-----------|-----------|
| PACE | PACE | 5:26/km | `#00D4FF` | 94.64 × 56.659 px |
| DISTÂNCIA | DISTÂNCIA | 5.2km | `#FFFFFF` | 92.2 × 56.659 px |
| TEMPO | TEMPO | 28:15 | `#FFFFFF` | 75.447 × 56.659 px |
| STREAK | STREAK | 12 dias seguidos | `#FFFFFF` | 181.012 × 56.659 px |

**Tipografia chips:**
- Label: Regular 12 px `rgba(255,255,255,0.55)`
- Valor: Bold 16 px, line-height 19.2 px

## Seleção de Dados no Overlay (Toggle Chips)

**Label:** "DADOS NO OVERLAY" — Regular 13 px dim, tracking 1.3 px

**Grid de 3 colunas (3 linhas), chips de largura variável:**

| Chip | Estado | Label |
|------|--------|-------|
| Pace | Ativo (✓) | ✓ Pace |
| Distância | Ativo (✓) | ✓ Distância |
| Tempo | Ativo (✓) | ✓ Tempo |
| BPM | **Inativo** | BPM |
| Streak | Ativo (✓) | ✓ Streak |
| Plano | Ativo (✓) | ✓ Plano |
| Trajeto | Ativo (✓) | ✓ Trajeto |
| Splits | **Inativo** | Splits |
| Coach | **Inativo** | Coach |

**Estilo ativo:** bg `rgba(0,212,255,0.09)`, border 1.741 px `#00D4FF`, Medium 13 px `#FFFFFF`  
**Estilo inativo:** bg transparente, border dim, Medium 13 px dim

## Link "Tirar outra foto ↗"

- Medium 13 px `#00D4FF`, sem border/bg (link inline)

---

## Componentes identificados (Run Journey)

| Componente | Tela | Reutilizável | Descrição |
|------------|------|:------------:|-----------|
| `ExerciseCard` | Pre-corrida | Sim | Ícone + nome + reps + descrição, 3 linhas, border sutil |
| `AlertToggleRow` | Pre-corrida | Sim | Título + sub, pill toggle ON/OFF à direita |
| `MusicAppButton` | Pre-corrida | Sim | Botão quadrado com logo do app de música |
| `RunHUDStatusBar` | Corrida ativa | Não | "RUN.ACTIVE" + "EASY_RUN.exe", sem VOLTAR |
| `RunTimer` | Corrida ativa | Não | Bold 70.838 px, colons em ciano |
| `RunMetricCell` | Corrida ativa | Sim | Label + superscript + valor 28px + unidade, divisória hairline |
| `SplitCard` | Corrida ativa | Sim | KM## + tempo + status OK/PEND, scroll horizontal |
| `RunActionButtons` | Corrida ativa | Não | PAUSAR (ghost) + FINALIZAR (ciano) side-by-side |
| `BadgeUnlockModal` | Conquista | Não | Overlay escuro + card ciano/laranja com anel concêntrico |
| `BadgeXPChip` | Conquista/relatório | Sim | "+N XP", bg/border laranja, Bold 16 px |
| `PostRunStatCard` | Relatório | Sim | Label + valor 22px + unidade, cor varia por tipo |
| `SplitRow` | Relatório | Sim | KM label + barra + tempo, barra destaca melhor split |
| `HeartZoneRow` | Relatório | Sim | Zona colorida + nome + barra proporcional + percentual |
| `BadgeChip` | Relatório | Sim | Ícone + texto, bg/border ciano-tintado |
| `ShareCardPreview` | Compartilhar | Não | Card branded com distância hero, mapa, stats |
| `CardThemePicker` | Compartilhar | Sim | 3 botões (Dark/Color/Minimal), ativo com borda ciano |
| `ShareDestinationRow` | Compartilhar | Sim | Plataforma + arrow ↗, bg sutil, fullwidth |
| `PhotoOverlayChip` | Compartilhar foto | Sim | Label + valor sobre foto, bg semi-transparente |
| `OverlayDataToggleChip` | Compartilhar foto | Sim | Multi-select chip, ativo com tint ciano + ✓ |

---

## Tokens de cor — novos do Run Journey

| Token (proposto)             | Hex / RGBA                       | Uso                                             |
|------------------------------|----------------------------------|-------------------------------------------------|
| `color/run/status/bg`        | `rgba(0, 212, 255, 0.02)`        | Tint ciano fullscreen na tela de corrida ativa  |
| `color/run/pausar/border`    | `rgba(255, 255, 255, 0.15)`      | Border botão PAUSAR                             |
| `color/split/pending`        | `rgba(255, 255, 255, 0.10)`      | Tempo/status de split ainda não completado      |
| `color/split/track`          | `rgba(255, 255, 255, 0.05)`      | Track das barras de split                       |
| `color/coach/blue`           | `rgba(0, 212, 255, 0.03)`        | Bg do card de análise COACH.AI (ciano claro)    |
| `color/photo/overlay/bg`     | `rgba(5, 5, 16, 0.60)`           | Bg dos chips sobrepostos na foto                |
| `color/photo/overlay/border` | `rgba(255, 255, 255, 0.15)`      | Border dos chips sobrepostos na foto            |
| `color/badge/modal/top`      | `#00D4FF` (4px solid)            | Linha topo do modal de badge                    |
| `color/badge/ring/cyan`      | `#00D4FF` (opacity 14%)          | Anel externo do badge icon                      |
| `color/badge/ring/orange`    | `#FF6B35` (opacity 8%)           | Anel intermediário do badge icon                |

---

## Tipografia — novas do Run Journey

| Token                          | Fonte          | Peso  | Tamanho | LS         | LH        |
|--------------------------------|----------------|-------|---------|------------|-----------|
| `type/run/timer`               | JetBrains Mono | Bold  | 70.838 px | −3.54 px | 60.2 px   |
| `type/run/metric/value`        | JetBrains Mono | Bold  | 28 px   | 0          | 28 px     |
| `type/run/metric/label`        | JetBrains Mono | Reg   | 13 px   | 1.56 px    | 19.5 px   |
| `type/run/metric/superscript`  | JetBrains Mono | Reg   | 9 px    | 0          | —         |
| `type/run/split/time`          | JetBrains Mono | Bold  | 16 px   | 0          | 24 px     |
| `type/stat/value/medium`       | JetBrains Mono | Bold  | 22 px   | −0.44 px   | 24.2 px   |
| `type/share/hero/distance`     | JetBrains Mono | Bold  | 48 px   | 0          | 48 px     |
| `type/overlay/chip/value`      | JetBrains Mono | Bold  | 16 px   | 0          | 19.2 px   |

---

## Comportamento / UX

### pre_corrida
- Scroll longo (~2885 px); TopNav fixo no topo
- Alertas são toggles independentes — estado persistido
- Botões de música abrem o app externo (deep link)
- "COMEÇAR CORRIDA" inicia o GPS/tracking e navega para corrida_ativa

### corrida_ativa
- Sem navegação de volta — a corrida está ativa
- PAUSAR congela o timer (tela de pausa não especificada)
- FINALIZAR navega para conquista_badge (se badge desbloqueado) ou direto para report
- Timer incrementa a cada segundo; métricas atualizam em tempo real
- Splits aparecem ao completar cada quilômetro

### conquista_badge
- Modal aparece automaticamente após FINALIZAR se badge novo desbloqueado
- CONTINUAR fecha o modal e revela o relatório por baixo
- Múltiplos badges = múltiplos modais em sequência?

### report_corrida
- COMPARTILHAR → compartilhar_corrida (tab CARD por padrão)
- HOME → navega para a tela principal

### compartilhar
- Toggle entre CARD e CÂMERA + OVERLAY sem sair da tela
- CÂMERA: abre câmera nativa para tirar foto de fundo
- Chips de "DADOS NO OVERLAY" são multi-select — escolha do usuário
- Destinos de share usam sistema nativo de compartilhamento (share sheet)

---

## Lacunas / Decisões pendentes

1. **Tela de PAUSA:** não especificada — o que aparece ao pressionar PAUSAR?
2. **Múltiplos badges:** se 2+ badges são desbloqueados, como são exibidos?
3. **Split "melhor":** qual critério destaca o split em ciano — o menor pace?
4. **Foto de câmera:** o app abre câmera nativa ou usa CameraX/image_picker?
5. **Compartilhar:** usa share sheet nativa do iOS/Android ou implementação própria?
6. **Tema Dark/Color/Minimal:** apenas "Dark" implementado — os outros temas têm designs?
7. **GPS/tracking:** qual SDK/serviço — Google Maps, Mapbox, sensor do device?
8. **Coach por voz:** qual TTS (Text-to-Speech) usa — Google TTS, ElevenLabs?
