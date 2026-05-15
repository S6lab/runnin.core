# Telas: TREINO (Plano, Relatórios, Ajustes, Coach Chat)

> Extraído via Figma MCP — Nós `1:7230`, `1:7546`, `1:7697`, `1:7816`, `1:7964`, `1:8062`, `1:8168`, `1:8215`, `1:8281`, `1:8498`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)

---

## Visão geral

Seção TREINO com 3 abas principais (PLANO / RELATÓRIOS / AJUSTES) + fluxo de Coach Chat para solicitação de alterações. Total de 10 telas documentadas.

**Fluxo:**  
`Plano Semanal` → `Plano Mensal` → `Relatórios` → `Relatório Detalhe` → `Solicitar Alteração` → `Coach Chat` (4 estados) → `Histórico de Ajustes`

---

## Componentes Globais do TREINO

### TopNav (padrão sem back button — 54.708px)

| Elemento | Valor |
|----------|-------|
| Background | `rgba(5,5,16,0.92)` |
| Border bottom | `1.735px solid rgba(255,255,255,0.06)` |
| Height | 54.708px |
| Padding | top 16px, bottom 17.735px, left 23.992px |
| Logo | `RUNNIN` Bold 14px white + `.AI` badge cyan |
| Separator `/` | 12px Regular `rgba(255,255,255,0.12)` |
| Breadcrumb | `TREINO` — Regular 13px, `rgba(255,255,255,0.55)`, tracking 1.3px |

### TopNav com back button (telas de detalhe — 73.712px)

- Height aumentado para 73.712px
- Back button: 39.987×39.987px, bg `rgba(255,255,255,0.06)`, border `rgba(255,255,255,0.1) 1.735px`
- Breadcrumb muda para contexto (ex: `RELATÓRIO`, `COACH CHAT`)

### Tab Bar Primária (PLANO / RELATÓRIOS / AJUSTES)

| Tab | Width | Ativo BG | Ativo Border | Ativo Text | Inativo Text |
|-----|-------|----------|--------------|-----------|--------------|
| PLANO | 106.623–115.298px | `#00d4ff` | `#00d4ff 1.735px` | `#050510` | `rgba(255,255,255,0.55)` |
| RELATÓRIOS | same | `#00d4ff` | `#00d4ff 1.735px` | `#050510` | `rgba(255,255,255,0.55)` |
| AJUSTES | same | `#00d4ff` | `#00d4ff 1.735px` | `#050510` | `rgba(255,255,255,0.55)` |

- Altura: 39.933px
- Typography: JetBrains Mono Bold 11px, tracking 1.1px, line-height 16.5px
- Badge inativo: bg `#00d4ff`, text `#050510`, 15.995×15.995px
- Badge ativo: bg `#050510`, text `#00d4ff` (invertido)

### Bottom Navigation Bar

- Background: `rgba(5,5,16,0.96)`
- Border top: `1.735px solid rgba(255,255,255,0.06)`
- Height: 78.591px
- 5 items: HOME / TREINO / RUN / HIST / PERFIL
- TREINO ativo: texto branco + barra ciano 1.979px × 19.98px abaixo do ícone
- RUN: botão 55.982px quadrado, bg `#00d4ff`, texto `#050510` Bold 11px, tracking 1.1px; anel externo `#00d4ff` border 1.864–2.102px, opacity 0.28–0.30
- Label: JetBrains Mono Medium 10px, tracking 1px, line-height 15px
- Inativo: `rgba(255,255,255,0.55)`

---

## Tela 1 — Plano Semanal (nó 1:7230)

**Nome interno:** `treino/plano/semanal`  
**Viewport:** 367.826 × 851.898px | **Scroll:** 1343.209px  
**Tab primária ativa:** PLANO | **Tab secundária ativa:** SEMANAL

### Tab Bar Secundária (SEMANAL / MENSAL)

| Tab | Estado | BG | Border | Text |
|-----|--------|----|--------|------|
| SEMANAL | Ativo | `rgba(0,212,255,0.08)` | `rgba(0,212,255,0.25) 1.735px` | `#00d4ff` |
| MENSAL | Inativo | transparent | `rgba(255,255,255,0.08) 1.735px` | `rgba(255,255,255,0.55)` |

- Cada tab: 159.921px × 35.975px

### Cabeçalho de seção

- `"Plano semanal"` — Bold 22px, white, tracking -0.44px, uppercase, line-height 24.2px
- Superscript `"01"` — Regular 6.6px, `#00d4ff`
- Subtítulo: `"Semana 2 · Mar 3-9, 2026 · Foco: Intervalado"` — Regular 13px, `rgba(255,255,255,0.55)`, line-height 19.5px

### Coach.AI Card (top: 273.81px)

| Propriedade | Valor |
|-------------|-------|
| Left border | `#ff6b35`, 1.735px |
| Background | `rgba(255,107,53,0.02)` |
| Padding | top 15.995px, left 17.73px, right 15.995px |
| Size | 319.841 × 204.787px |

- Header: `"COACH.AI > PLANO DA SEMANA"` — Regular 11px, `#ff6b35`, tracking 1.1px
- Body: `"Semana 2 introduz intervalados. Segunda e quarta são recuperação ativa. Terça é o treino chave — intervalos de 800m. Sexta será tempo run. Domingo, corrida longa para volume. Descanso estratégico na quinta e sábado."` — Regular 13px, `rgba(255,255,255,0.7)`, line-height 21.45px

### Lista de dias (top: 502.59px, gap 3.985px)

Cada linha: 319.841px, border `1.735px`, padding horizontal 17.73px, vertical 17.735px  
Quadrado de status: 39.987×39.987px

| Dia | Status Box BG | Status Texto | Tipo treino | Distância | Pace | Card BG | Card Border |
|-----|--------------|--------------|-------------|-----------|------|---------|-------------|
| Segunda | `#00d4ff` | `"OK"` Bold 16px `#050510` | Easy Run 13px `rgba(255,255,255,0.55)` | `"4K"` Bold 16px `#ff6b35` | `"6:30/km"` | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |
| Terça | `#00d4ff` | `"OK"` Bold 16px `#050510` | Intervalado | `"4x800m"` Bold 16px `#ff6b35` | `"4:45/km"` | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |
| Quarta | `rgba(0,212,255,0.13)` | `"HOJE"` Bold 12px `#00d4ff` tracking 0.6px | Easy Run | `"5K"` Bold 16px `#ff6b35` | `"6:30/km"` | `rgba(0,212,255,0.03)` | `rgba(0,212,255,0.19)` |
| Quinta | `rgba(255,255,255,0.03)` | — | Descanso 13px `rgba(255,255,255,0.2)` | — | — | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |
| Sexta | `rgba(255,255,255,0.03)` | — | Tempo Run | `"5K"` Bold 16px `#ff6b35` | `"5:30/km"` | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |
| Sábado | `rgba(255,255,255,0.03)` | — | Descanso | — | — | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |
| Domingo | `rgba(255,255,255,0.03)` | — | Long Run | `"8K"` Bold 16px `#ff6b35` | `"6:45/km"` | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |

**Estados do quadrado de status:**
- Completo (OK): `#00d4ff` sólido, texto `"OK"` em `#050510`
- Hoje (HOJE): `rgba(0,212,255,0.13)`, texto `"HOJE"` em `#00d4ff`, card com borda cyan
- Descanso: `rgba(255,255,255,0.03)` vazio, tipo-texto em `rgba(255,255,255,0.2)`
- Futuro: `rgba(255,255,255,0.03)` vazio, tipo-texto em `rgba(255,255,255,0.55)`

### Stats Row (top: 1097.27px, 3 células)

Cada: 101.282×90.438px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`

| Célula | Label | Valor | Cor valor |
|--------|-------|-------|-----------|
| VOLUME | Regular 10px `rgba(255,255,255,0.55)` tracking 1px | `"18K"` Bold 22px | `#00d4ff` |
| SESSÕES | same | `"5"` | `#00d4ff` |
| DESCANSO | same | `"2"` | `#00d4ff` |

- Sub-label: Regular 10px `rgba(255,255,255,0.55)` ("meta" / "treinos" / "dias")

### Links (top: 1211.7px)

- `"Ver plano mensal ↗"` — Medium 13px, `#00d4ff`, left
- `"Ver relatórios ↗"` — Medium 13px, `#ff6b35`, right

---

## Tela 2 — Plano Mensal (nó 1:7546)

**Nome interno:** `treino/plano/mensal`  
**Viewport:** 367.826 × 851.898px | **Scroll:** 1591.047px  
**Tab primária ativa:** PLANO | **Tab secundária ativa:** MENSAL

### Cabeçalho

- `"Periodização"` — Bold 22px, white, tracking -0.44px, uppercase
- Superscript `"01"` — 6.6px, `#00d4ff`
- Subtítulo: `"Março 2026 · Mesociclo 1 · Objetivo: 10K"` — Regular 13px, `rgba(255,255,255,0.55)`

### Mini Stats (top: 258.28px, 4 células)

Cada: 73.956×73.468px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`

| Célula | Label | Valor |
|--------|-------|-------|
| VOL TOTAL | Regular 9px tracking 0.9px | `"65K"` Bold 18px `#00d4ff` |
| SESSÕES | same | `"16"` Bold 18px `#00d4ff` |
| DIAS TREINO | same | `"16"` |
| DESCANSO | same | `"14"` |

### Cards das semanas (top: 355.73px, gap 3.985px)

Cada card: 319.841×146.447px, padding horizontal 17.73px, vertical 17.73px

| Semana | Foco | Volume | Status | Status Cor | Card BG | Card Border |
|--------|------|--------|--------|-----------|---------|-------------|
| Sem 1 | Foco: Base | 15K | COMPLETA | `#00d4ff` | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |
| Sem 2 | Foco: Intervalado | **18K** (cyan) | ATUAL | `rgba(255,255,255,0.55)` | `rgba(0,212,255,0.03)` | `rgba(0,212,255,0.19)` |
| Sem 3 | Foco: Tempo | 20K | PRÓXIMA | `rgba(255,255,255,0.55)` | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |
| Sem 4 | Foco: Recuperação | 12K | PRÓXIMA | `rgba(255,255,255,0.55)` | `rgba(255,255,255,0.03)` | `rgba(255,255,255,0.08)` |

**Textos do corpo dos cards:**
- Sem 1: `"3 easy runs + 1 long run. Foco na construção de base aeróbica e adaptação musculoesquelética."`
- Sem 2: `"2 easy + 1 intervalado + 1 tempo. Introdução de trabalho de velocidade com recuperação adequada."`
- Sem 3: `"2 easy + 1 tempo run + 1 long run. Pico de volume do mesociclo com foco no limiar."`
- Sem 4: `"3 easy runs curtos. Semana de recuperação — supercompensação antes do próximo ciclo."`

- Body: Regular 12px, `rgba(255,255,255,0.4)`, line-height 18px
- Volume semana atual em `#00d4ff` (demais em `#ff6b35`)

### Gráfico de Progressão de Volume (top: 977.47px)

Container: 319.841×181.907px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`

- Label: `"PROGRESSÃO DE VOLUME"` — 11px Regular, `rgba(255,255,255,0.55)`, tracking 1.1px
- 4 barras verticais, largura 62.109px cada

| Barra | Cor barra | Altura | Label valor | Cor label |
|-------|-----------|--------|-------------|-----------|
| S1 | `rgba(0,212,255,0.38)` | 44.975px | `"15K"` Regular 11px | `rgba(255,255,255,0.55)` |
| S2 (atual) | `#00d4ff` sólido | 53.976px | `"18K"` **Bold** 11px | `#00d4ff` |
| S3 | `rgba(255,255,255,0.08)` | 59.994px | `"20K"` Regular 11px | `rgba(255,255,255,0.55)` |
| S4 | `rgba(255,255,255,0.08)` | 35.975px | `"12K"` Regular 11px | `rgba(255,255,255,0.55)` |

- Caption: `"Sem 4 é recovery — padrão de periodização linear 3:1"` — 10px Regular, `rgba(255,255,255,0.3)`, centrado

### Coach.AI Card (top: 1183.37px)

- Left border `#ff6b35`, bg `rgba(255,107,53,0.03)`
- Header: `"COACH.AI > PERIODIZAÇÃO"` — 13px Regular, `#ff6b35`
- Body: `"Volume progressivo nas semanas 1-3, seguido de recovery na semana 4. Padrão clássico de periodização linear 3:1, adaptado ao seu nível. O objetivo é construir base aeróbica sólida antes de introduzir trabalho específico de velocidade no próximo mesociclo."` — 14px Regular, `rgba(255,255,255,0.8)`, line-height 23.8px

### Link de retorno

- `"← Voltar para semanal"` — Medium 13px, `#00d4ff`

---

## Tela 3 — Relatórios (nó 1:7697)

**Nome interno:** `treino/relatorios`  
**Viewport:** 393.851 × 851.898px  
**Tab primária ativa:** RELATÓRIOS

### Cabeçalho

- `"Relatórios semanais"` — Bold 22px, white, tracking -0.44px, uppercase
- Superscript `"01"` — 6.6px, `#00d4ff`
- Subtítulo: `"Análise do Coach ao final de cada semana"` — Regular 13px, `rgba(255,255,255,0.55)`

### Card — Semana 2 (MAIS RECENTE)

Container: 345.867×218.83px, bg `rgba(0,212,255,0.02)`, border `rgba(0,212,255,0.14) 1.735px`

- Badge `"MAIS RECENTE"`: bg `#00d4ff`, 80.706×31.962px, top-right, texto `#050510` Bold 9px

**Header:**
- `"Semana 2"` — Bold 16px, white, line-height 24px
- `"3 Mar - 9 Mar, 2026"` — Medium 12px, `rgba(255,255,255,0.55)`

**Stats:**

| Stat | Valor | Cor |
|------|-------|-----|
| ADERÊNCIA | `"40%"` Bold 18px | `#ff6b6b` |
| KM | `"13.2"` Bold 18px | `#ff6b35` |
| SESSÕES | `"2/5"` Bold 18px | `#ffffff` |
| FREE | `"1"` Bold 18px | `#ff6b35` |

- Label: 10px Medium `rgba(255,255,255,0.55)` tracking 1px; Valor line-height 27px

**Coach quote (clampado em 36px):**  
`Coach: "Semana em andamento. Até agora 2 de 5 sessões concluídas mais 1 free run de 3.2km. O intervalado de terça foi excelente ..."` — Medium 12px, `rgba(255,255,255,0.45)`, line-height 18px

**Status tag:** `"SEM REVISÃO"` — bg `rgba(255,255,255,0.03)`, 80.272×21.471px, Regular 9px `rgba(255,255,255,0.55)`, tracking 0.45px

### Card — Semana 1

Container: bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px` (sem destaque)

**Stats:**

| Stat | Valor | Cor |
|------|-------|-----|
| ADERÊNCIA | `"100%"` | `#00d4ff` |
| KM | `"16.9"` | `#ff6b35` |
| SESSÕES | `"4/4"` | `#ffffff` |

**Coach quote:** `Coach: "Semana inaugural perfeita. Você completou 100% das sessões com pace consistente. Sua base aeróbica está se formando — o ..."` — clampado  
**Status tag:** `"SEM REVISÃO"` — mesmo estilo

---

## Tela 4 — Relatório Semanal Detalhe (nó 1:7816)

**Nome interno:** `relatorio semanal`  
**Viewport:** 368 × 851.898px | **Scroll total:** 1969.175px  
**TopNav:** 73.712px com back button; breadcrumb `RELATÓRIO`

### Cabeçalho do relatório (top: 97.7px)

- `"// RELATÓRIO SEMANAL"` — Regular 12px, `#00d4ff`, tracking 2.4px
- `"Semana 2"` — Bold **28px**, white, tracking -0.84px, line-height 29.4px
- `"3 Mar - 9 Mar, 2026"` — Regular 13px, `rgba(255,255,255,0.55)`

### Card de Aderência (top: 202.59px)

Container: 319.841×163.445px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`, overflow clip

- Badge `"ATENÇÃO"`: bg `#ff6b6b`, 61.729×35.975px, top-right, texto `#050510` Bold 9px
- Label: `"ADERÊNCIA AO PLANO"` — Regular 11px, `rgba(255,255,255,0.55)`, tracking 1.1px
- Valor: `"40"` — Bold **48px**, `#00d4ff` + sufixo `"%"` Regular 18px `rgba(255,255,255,0.55)`
- Barra de progresso: track `rgba(255,255,255,0.06)`, fill `#00d4ff`, height 7.997px, fill ~40%
- Sub-label: `"2/5 sessões concluídas"` — Regular 13px, `rgba(255,255,255,0.55)`

### Métricas (top: 378.02px, 3 células)

Cada: ~103.9×90.438px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`, padding 13.718px

| Célula | Label | Valor | Cor |
|--------|-------|-------|-----|
| KM TOTAL | 10px tracking 1px | `"13.2"` Bold 22px | `#ff6b35` |
| PACE MÉD | same | `"5:38"` Bold 22px | `#ff6b35` |
| SESSÕES | same | `"2"` Bold 22px | `#ff6b35` |

### Banner Treinos Livres (top: 480.44px)

Container: 319.841×74.931px, bg `rgba(255,107,53,0.03)`, border `rgba(255,107,53,0.13) 1.735px`

- Label: `"TREINOS LIVRES INTEGRADOS"` — Regular 11px, `#ff6b35`, tracking 1.1px
- Sub: `"1 free run · 3.2km extras"` — Regular 14px, white, line-height 21px
- Badge `"ADAPTADO"`: bg `#ff6b35`, texto `#050510` Bold 9px

### Seção "Análise do Coach" (top: 579.36px)

Cabeçalho: `"Análise do Coach"` Bold 22px + superscript `"01"` cyan

**Coach.AI Card:** 319.841×286.28px
- Left border `#00d4ff`, bg `rgba(0,212,255,0.03)`
- Header: `"COACH.AI > ANÁLISE SEMANAL"` — Regular 12px, `#00d4ff`, tracking 1.2px
- Corpo: `"Semana em andamento. Até agora 2 de 5 sessões concluídas mais 1 free run de 3.2km. O intervalado de terça foi excelente — pace sub-5 nos intervalos. O free run de quarta foi integrado como volume extra de recuperação ativa. Faltam 3 sessões incluindo o long run de domingo."` — Regular 14px, `rgba(255,255,255,0.85)`, line-height 24.5px

### Seção "Destaques" (top: 929.84px)

Cabeçalho: `"Destaques"` Bold 22px + superscript `"02"` cyan

**Linhas de destaque positivo** (bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`, padding 13.718px):
- Símbolo `"+"` — Regular 14px, `#00d4ff`
- Texto — Regular 13px, white
1. `"Intervalado sub-5 consistente"`
2. `"Free run integrado ao plano"`
3. `"Recuperação BPM excelente entre séries"`

**Linha de alerta** (bg `rgba(255,100,100,0.05)`, border `rgba(255,100,100,0.15) 1.735px`):
- Símbolo `"!"` — Regular 14px, `#ff6b6b`
- Texto: `"Atenção: BPM máx no intervalado foi 185 — próximo do teto. Monitorar na próxima sessão intensa."` — Regular 13px, `rgba(255,200,200,0.85)`, line-height 19.5px

### Seção "Adaptação Sugerida" (top: 1286.82px)

Cabeçalho: `"Adaptação sugerida"` Bold 22px + superscript `"03"` cyan

**Coach.AI Card:** 319.841×261.799px
- Left border `#ff6b35`, bg `rgba(255,107,53,0.03)`
- Header: `"COACH.AI > RECOMENDAÇÃO"` — Regular 12px, `#ff6b35`, tracking 1.2px
- Corpo: `"O free run de 3.2km que você fez na quarta foi computado como recuperação ativa. Considerando esse volume adicional, ajustei levemente o pace alvo do Tempo Run de sexta para 5:25/km (era 5:30). Seu corpo está respondendo bem à carga."` — Regular 14px, `rgba(255,255,255,0.85)`, line-height 24.5px

### Linha META (top: 1600.81px)

Container: 319.841×66.473px, bg `rgba(0,212,255,0.02)`, border `rgba(0,212,255,0.08) 1.735px`, padding 17.73px horizontal, 13.735px vertical

- `"META:"` — Regular 13px, `#00d4ff`
- `"Completar 10K"` — Regular 13px, white
- `"· trajetória mantida"` — Regular 12px, `rgba(255,255,255,0.55)`

### Seção Solicitar Alterações (top: 1699.27px)

Label: `"QUER SOLICITAR ALTERAÇÕES NO PLANO?"` — Regular 12px, `rgba(255,255,255,0.55)`, tracking 1.2px

**CTAs:**

| Botão | BG | Border | Texto | Cor texto |
|-------|----|---------|----|-----------|
| `"CONVERSAR COM COACH ↗"` | `#00d4ff` | — | Bold 12px tracking 1.2px | `#050510` |
| `"MANTER PLANO ATUAL"` | transparent | `rgba(255,255,255,0.2) 1.735px` | Bold 12px tracking 1.2px | `#ffffff` |

### Nota de revisão

- `"1 revisão disponível por semana"` — Regular 11px, `rgba(255,255,255,0.3)`, centrado

---

## Tela 5 — Solicitar Alteração — Estado Inicial (nó 1:7964)

**Nome interno:** `solicitar alteração plano`  
**Canvas:** 393.851 × 1092px  
**TopNav:** 73.712px com back button; breadcrumb `COACH CHAT`

### Cabeçalho de conteúdo (top: 73.71px)

- `"// SOLICITAR ALTERAÇÃO"` — Regular 12px, `#00d4ff`, tracking 2.4px, line-height 18px
- `"O que você quer mudar?"` — Bold 22px, white, line-height 24.2px
- `"Baseado no relatório da Semana 2 · 3 Mar - 9 Mar, 2026"` — Regular 13px, `rgba(255,255,255,0.55)`, line-height 19.5px
- `"Selecione uma ou mais opções"` — Regular 11px, `rgba(255,255,255,0.55)`, tracking 0.55px

### Grid de botões de seleção

Grid container: 327.866px, layout 2 colunas, gap ~7.999px

**Estado deselecionado:**
- Background: `rgba(255,255,255,0.03)`
- Border: `1.735px solid rgba(255,255,255,0.08)`
- Label: Bold 13px, `rgba(255,255,255,0.7)`, line-height 19.5px
- Descrição: Medium 11px, `rgba(255,255,255,0.55)`, line-height 16.5px
- Ícone: 17.974×17.974px, left: 15.99px, top: 18.22px

**Botões (verbatim):**

| # | Título | Descrição | Altura | Col |
|---|--------|-----------|--------|-----|
| 1 | Mais carga | Aumentar volume ou intensidade | 119.961px | L |
| 2 | Menos carga | Reduzir volume ou intensidade | 119.961px | R |
| 3 | Mais dias | Adicionar dias de treino | 119.961px | L |
| 4 | Menos dias | Remover dias de treino | 119.961px | R |
| 5 | Mais tempo runs | Foco em limiar anaeróbico | 139.48px | L |
| 6 | Mais resistência | Foco em corridas longas | 139.48px | R |
| 7 | Mais intervalados | Foco em velocidade | 122.97px | L |
| 8 | Mudar dias | Reorganizar dias disponíveis | 122.97px | R |
| 9 | Dor/Desconforto | Ajustar por condição física | 119.961px | L |
| 10 | Outro | Descrever livremente | 119.961px | R |

---

## Tela 6 — Solicitar Alteração — Estado Selecionado + CTA (nó 1:8062)

**Viewport:** 393.851 × 851.898px  
**Diferença:** 1 botão selecionado (`"Mais carga"`) + barra de resumo + CTA visíveis

### Estado selecionado do botão

| Propriedade | Deselecionado | Selecionado |
|-------------|---------------|-------------|
| Background | `rgba(255,255,255,0.03)` | `rgba(0,212,255,0.07)` |
| Border | `rgba(255,255,255,0.08) 1.735px` | `#00d4ff 1.735px` |
| Label color | `rgba(255,255,255,0.7)` | `#ffffff` |

### Barra de resumo (aparece quando ≥1 selecionado)

Container: 327.866 × 65.931px, bg `rgba(0,212,255,0.03)`, border `rgba(0,212,255,0.13) 1.735px`

- `"1 ALTERAÇÃO SELECIONADA"` — Regular 11px, `#00d4ff`, tracking 1.1px
- `"Mais carga"` — Regular 12px, `rgba(255,255,255,0.55)`

### CTA Button

Container: 327.866 × 49.99px, bg `#00d4ff`

- Label: `"CONVERSAR COM COACH ↗"` — Bold 12px, `#050510`, tracking 1.2px

---

## Tela 7 — Coach Chat — Conversa inicial (nó 1:8168)

**Nome interno:** `COACH CHAT 2`  
**Viewport:** 393.851 × 851.898px

### Área de chat (top: 73.71px, padding: px 19.98px, pt 15.995px)

#### Banner de sessão

Container: 353.891×50.939px, bg `rgba(0,212,255,0.02)`, border `rgba(0,212,255,0.07) 1.735px`, padding px 13.718px, pt 9.732px

- Linha 1: `"SESSÃO DE AJUSTE · MAIS CARGA"` — Regular 10px, `#00d4ff`, tracking 1px
- Linha 2: `"✓ 2 exames integrados · Limites clínicos ativos"` — Regular 9px, `#ff6b35`

#### Bubble usuário (alinhado à direita)

Container: 353.891px, row justify-end  
Bubble: 300.783×99.385px, bg `rgba(0,212,255,0.07)`, border `rgba(0,212,255,0.19) 1.735px`, padding px 17.73px, pt 17.73px

- Mensagem: `"Quero: Mais carga — Aumentar volume ou intensidade"` — Regular 13px, white, line-height 21.45px
- Timestamp: `"08:42"` — Regular 10px, `rgba(255,255,255,0.2)`

#### Bubble Coach.AI (alinhado à esquerda)

Bubble: 300.783×382.926px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`

- Label `"COACH.AI"` — Regular 10px, `#ff6b35`, tracking 1px (left: 15.99px, top: 15.99px)
- Texto: `"Entendi, você quer mais carga. Posso aumentar de diferentes formas. O que faz mais sentido pra você?"` — Regular 13px, `rgba(255,255,255,0.85)`, line-height 21.45px

**Botões de opção** (left: 15.99px, top: 134.84px, coluna, gap: 5.991px):

Cada botão: 265.324×47.415px, bg `rgba(255,107,53,0.03)`, border `rgba(255,107,53,0.14) 1.735px`
- Label: Medium 12px, white, line-height 18px, left: 11.98px, top: 12.45px

| # | Texto |
|---|-------|
| 1 | `+5km/semana` |
| 2 | `+10km/semana` |
| 3 | `Mais intensidade` |
| 4 | `Volume + intensidade` |

- Timestamp: `"08:42"` — Regular 10px, `rgba(255,255,255,0.2)`

---

## Tela 8 — Coach Chat 3 — Resposta de confirmação (nó 1:8215)

**Nome interno:** `COACH CHAT 3`  
**Viewport:** 393.851 × 851.898px | **Scroll total:** ~1200.856px

Adiciona:

#### Bubble usuário — seleção

Bubble: 121.235×77.914px, mesmas cores do bubble anterior
- Mensagem: `"+5km/semana"` — Regular 13px, white, nowrap
- Timestamp: `"08:43"`

#### Bubble Coach.AI — confirmação (533.765px de altura)

Texto longo:
```
Perfeito. Vou aplicar: "Aumentar volume em 5km semanais distribuídos nas sessões 
existentes." Recalculando o plano para esta semana mantendo seu objetivo de "" 
no caminho certo. 📋 Cruzando com seu teste ergométrico: limiar anaeróbico em 
168bpm. Vou respeitar esse limite ao recalcular zonas de intensidade.

Quer confirmar essa alteração?
```
- Font: Regular 13px, `rgba(255,255,255,0.85)`, line-height 21.45px, white-space: pre-wrap

**Botões de ação** (top: 392.5px, coluna, gap: 5.991px):

| Botão | BG | Border | Text | Cor |
|-------|----|---------|----|-----|
| `"Confirmar alteração"` | `rgba(0,212,255,0.08)` | `#00d4ff 1.735px` | Medium 12px | `#00d4ff` |
| `"Cancelar"` | transparent | `rgba(255,255,255,0.10) 1.735px` | Medium 12px | `rgba(255,255,255,0.55)` |

---

## Tela 9 — Coach Chat 4 — Conclusão (nó 1:8281)

**Nome interno:** `COACH CHAT 4`  
**Viewport:** 393.851 × 851.898px | **Scroll total:** ~1207.037px

Adiciona às telas anteriores:

#### Bubble usuário — confirmação

Bubble: 183.615×77.914px
- Mensagem: `"Confirmar alteração"` — Regular 13px, white, nowrap
- Timestamp: `"08:43"`

#### Bubble Coach.AI — "Pronto!"

Bubble: 278.662×163.309px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`
- Label `"COACH.AI"` — Regular 10px, `#ff6b35`, tracking 1px
- Texto: `"Pronto! Plano recalculado e aplicado. As mudanças entram em vigor a partir da sua próxima sessão. Bom treino!"` — Regular 13px, `rgba(255,255,255,0.85)`, line-height 21.45px
- Timestamp: `"08:43"` — Regular 10px, `rgba(255,255,255,0.2)`

#### CTAs finais (row, gap 7.997px)

| Botão | BG | Border | Texto | Cor |
|-------|----|---------|----|-----|
| `"VER PLANO ATUALIZADO ↗"` | `#00d4ff` | — | Bold 12px tracking 1.2px | `#050510` |
| `"HOME"` | transparent | `rgba(255,255,255,0.08) 1.735px` | Medium 12px | `rgba(255,255,255,0.55)` |

- Primário: 255.618px flex | Secundário: 64.25px | Altura: 45.436px

---

## Tela 10 — Histórico de Ajustes (nó 1:8498)

**Nome interno:** `HISTÓRICO DE AJUSTES`  
**Canvas:** 368 × 1484px (longo, scroll)  
**Tab primária ativa:** AJUSTES

### Tab Bar — aba AJUSTES ativa

- PLANO / RELATÓRIOS: inativo, mesmo estilo padrão
- AJUSTES (ativo): bg `#00d4ff`, border `#00d4ff`, texto `#050510`, badge invertido (bg `#050510`, texto `#00d4ff`)

### Cabeçalho

- `"Histórico de ajustes"` — Bold 22px, white, tracking -0.44px, uppercase
- Superscript `"01"` — 6.6px, `#00d4ff`
- Subtítulo: `"Suas solicitações de mudança no plano"` — Regular 13px, `rgba(255,255,255,0.55)`

### Card de Alerta — Revisão usada

Container: 319.841×96.484px, bg `rgba(255,100,100,0.05)`, border `rgba(255,100,100,0.15) 1.735px`, padding 17.73px horizontal, pt 17.73px

- Texto linha 1: `"REVISÃO USADA ESTA SEMANA"` — Regular 12px, `#ff6464`, tracking 1.2px
- Texto linha 2: `"Próxima revisão disponível na Semana 3 (Mar 10-16)"` — Regular 13px, `rgba(255,255,255,0.55)`
- Badge contador `"0"`: 47.984×47.984px, bg `rgba(255,100,100,0.15)`, Bold 18px, `#ff6464`

### Bloco Info — Como funcionam as revisões

Container: 319.841×252.392px, bg `rgba(255,107,53,0.02)`, **border somente à esquerda** `#ff6b35 1.735px`

- Label: `"COACH.AI > COMO FUNCIONAM AS REVISÕES"` — Regular 11px, `#ff6b35`, tracking 1.1px
- Corpo: `"Ao final de cada semana, você recebe um relatório com análise do Coach e sugestão de adaptação automática baseada nos treinos realizados (incluindo free runs). A partir do relatório, você pode abrir uma sessão de chat para solicitar alterações específicas. Limite: 1 revisão por semana para manter consistência na periodização."` — Regular 12px, `rgba(255,255,255,0.55)`, line-height 19.8px

### Seção "SOLICITAÇÕES ANTERIORES"

Label: `"SOLICITAÇÕES ANTERIORES"` — Regular 11px, `rgba(255,255,255,0.55)`, tracking 1.1px

**Card Semana 2** (319.841×279.583px, bg `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08) 1.735px`):

- Header: `"Semana 2"` Bold 14px white + badge `"APLICADO"` (bg `rgba(0,212,255,0.08)`, texto `#00d4ff` Bold 9px) + data `"2026-04-30"` + `"Mais carga"` Regular 13px `#ff6b35`
- Resumo: `"Quero: Mais carga — Aumentar volume ou intensidade → +5km/semana"` — Regular 12px, `rgba(255,255,255,0.50)`, line-height 18px
- Seção com border-top `rgba(255,255,255,0.08)`:
  - Label `"RESPOSTA DO COACH"` — Regular 10px, `#ff6b35`, tracking 1px
  - Texto: `"Plano recalculado e aplicado. As mudanças entram em vigor a partir da próxima sessão."` — Regular 12px, `rgba(255,255,255,0.55)`
- Card cyan de mudança: bg `rgba(0,212,255,0.02)`, border `rgba(0,212,255,0.07) 1.735px`
  - `"Mudanças: Mais carga: ajuste aplicado ao plano semanal."` — Regular 11px, `#00d4ff`

**Card Semana 1** (319.841×201.101px):

- Header: `"Semana 1"` + badge `"APLICADO"` + data `"2026-03-01"` + `"Sem alteração"` `#ff6b35`
- Resumo: `"Nenhuma revisão solicitada — plano mantido conforme original."` — `rgba(255,255,255,0.50)`
- Resposta: `"Plano seguiu sem alterações. Boa semana!"` — `rgba(255,255,255,0.55)`

### Seção "CALENDÁRIO DE REVISÕES"

Label: `"CALENDÁRIO DE REVISÕES"` — Regular 11px, `rgba(255,255,255,0.55)`, tracking 1.1px

Cada linha: 319.841×45.219px, border-bottom `rgba(255,255,255,0.04) 1.735px`, row, gap 11.983px

| # | Dot | Semana | Indicador | Status |
|---|-----|--------|-----------|--------|
| 1 | `#00d4ff` 11.983px | `"Semana 1"` 13px white | — | `"Sem alteração"` 11px `#00d4ff` |
| 2 | `#00d4ff` sólido | `"Semana 2"` 13px white + `"← ATUAL"` 10px cyan | atual | `"Mais carga"` 11px `#00d4ff` |
| 3 | `rgba(255,255,255,0.08)` | `"Semana 3"` 13px `rgba(255,255,255,0.30)` | — | `"—"` 11px `rgba(255,255,255,0.20)` |
| 4 | `rgba(255,255,255,0.08)` | `"Semana 4"` 13px `rgba(255,255,255,0.30)` | — | `"—"` 11px `rgba(255,255,255,0.20)` |

---

## Tokens de Cor — TREINO

| Token | Hex / RGBA | Uso |
|-------|-----------|-----|
| `color/bg/base` | `#050510` | Fundo de todas as telas |
| `color/nav/bg` | `rgba(5,5,16,0.92)` | TopNav frosted |
| `color/bottomnav/bg` | `rgba(5,5,16,0.96)` | Bottom nav |
| `color/brand/accent` | `#00d4ff` | Aba ativa, CTA, valores, dots, borda selecionado |
| `color/brand/coach` | `#ff6b35` | COACH.AI, borda left, labels laranja |
| `color/brand/alert` | `#ff6b6b` / `#ff6464` | Badges de atenção, erros |
| `color/text/high` | `#ffffff` | Títulos, valores, labels selecionados |
| `color/text/medium` | `rgba(255,255,255,0.85)` | Corpo chat coach |
| `color/text/secondary` | `rgba(255,255,255,0.7)` | Corpo coach card (plano) |
| `color/text/muted` | `rgba(255,255,255,0.55)` | Subtítulos, labels inativas |
| `color/text/dim` | `rgba(255,255,255,0.4)` | Corpo semana card |
| `color/text/faint` | `rgba(255,255,255,0.2)` | Timestamps, dia descanso |
| `color/surface/card` | `rgba(255,255,255,0.03)` | Cards padrão |
| `color/surface/card2` | `rgba(255,255,255,0.06)` | Back button bg |
| `color/border/default` | `rgba(255,255,255,0.08)` | Borda padrão |
| `color/surface/selected` | `rgba(0,212,255,0.07–0.08)` | Botão/tab selecionado |
| `color/border/selected` | `#00d4ff` | Borda botão selecionado |
| `color/surface/orange` | `rgba(255,107,53,0.02–0.03)` | Coach card laranja |
| `color/surface/red` | `rgba(255,100,100,0.05)` | Card alerta |
| `color/border/red` | `rgba(255,100,100,0.15)` | Borda alerta |
| `color/chat/user/bg` | `rgba(0,212,255,0.07)` | Bubble usuário |
| `color/chat/user/border` | `rgba(0,212,255,0.19)` | Borda bubble usuário |
| `color/chat/option/bg` | `rgba(255,107,53,0.03)` | Botão opção coach |
| `color/chat/option/border` | `rgba(255,107,53,0.14)` | Borda botão opção coach |

## Tokens de Tipografia — TREINO

| Token | Fonte | Peso | Tamanho | LS | LH |
|-------|-------|------|---------|----|----|
| `type/display/h1` | JetBrains Mono | Bold | 28px | -0.84px | 29.4px |
| `type/heading/h2` | JetBrains Mono | Bold | 22px | -0.44px | 24.2px |
| `type/heading/coach` | JetBrains Mono | Regular | 14px | — | 24.5px |
| `type/day/name` | JetBrains Mono | Medium | 14px | — | 21px |
| `type/body/main` | JetBrains Mono | Regular | 13px | — | 19.5px |
| `type/body/chat` | JetBrains Mono | Regular | 13px | — | 21.45px |
| `type/body/coach-card` | JetBrains Mono | Regular | 12px | — | 19.8px |
| `type/stats/xlarge` | JetBrains Mono | Bold | 48px | — | 48px |
| `type/stats/large` | JetBrains Mono | Bold | 22px | — | 33px |
| `type/stats/medium` | JetBrains Mono | Bold | 18px | — | 27px |
| `type/stats/small` | JetBrains Mono | Bold | 16px | — | 24px |
| `type/tab/label` | JetBrains Mono | Bold | 11px | 1.1px | 16.5px |
| `type/label/section` | JetBrains Mono | Regular | 12px | 2.4px | 18px |
| `type/label/small` | JetBrains Mono | Regular | 10–11px | 1px | 15–16.5px |
| `type/badge` | JetBrains Mono | Bold | 9px | 1.1px | 13.5px |
| `type/superscript` | JetBrains Mono | Regular | 6.6px | — | — |
| `type/cta` | JetBrains Mono | Bold | 12px | 1.2px | 18px |
| `type/chat/option` | JetBrains Mono | Medium | 12px | — | 18px |
| `type/nav/label` | JetBrains Mono | Medium | 10px | 1px | 15px |

---

## Componentes identificados

| Componente | Reutilizável | Descrição |
|-----------|:---:|-----------|
| `TrainingTabBar` | Sim | 3 abas PLANO/RELATÓRIOS/AJUSTES com estados e badges |
| `SecondaryTabBar` | Sim | 2 abas SEMANAL/MENSAL com estado cyan ativo |
| `DayPlanRow` | Sim | Status square 40px + nome + tipo + distância + pace; 4 estados |
| `WeekCard` | Sim | Card de semana com foco, volume, status e texto; 3 estados |
| `VolumeBarChart` | Sim | 4 barras verticais, semana atual sempre em cyan sólido |
| `ReportCard` | Sim | Card de relatório com stats, quote clampado, status tag |
| `AdherenceCard` | Sim | Valor 48px + barra de progresso + badge "ATENÇÃO" |
| `MetricsRow3` | Sim | 3 células de métricas com label/valor/unidade |
| `FreeRunsBanner` | Não | Banner específico de treinos livres integrados |
| `HighlightRow` | Sim | Linha + / ! com texto, 2 variantes (positivo/alerta) |
| `GoalRow` | Sim | Linha META com label, valor e trajetória |
| `SelectionButton` | Sim | Botão 2-col grid, estado selecionado cyan; reutiliza pattern Assessment |
| `SelectionSummaryBar` | Sim | Barra que aparece quando ≥1 selecionado; lista selecionados + count |
| `ChatBubbleUser` | Sim | Bubble direita, bg cyan tintado, borda cyan |
| `ChatBubbleCoach` | Sim | Bubble esquerda, bg dim, label COACH.AI laranja + conteúdo |
| `CoachOptionButton` | Sim | Botão de opção dentro do bubble coach, bg/border laranja |
| `ChatActionButton` | Sim | Botão de ação pós-resposta: confirmar (cyan) / cancelar (dim) |
| `ChatSessionBanner` | Sim | Banner de contexto topo do chat, bg cyan muito tintado |
| `RevisionCalendarRow` | Sim | Linha de calendário com dot + semana + status; 2 estados (passado/futuro) |
| `AdjustmentEntryCard` | Sim | Card de histórico de ajuste com header, resumo, resposta coach, nota de mudança |
| `AlertCardRevision` | Não | Card vermelho de revisão usada com counter badge |
| `CoachInfoBlock` | Sim | Bloco com borda-left somente, info sobre funcionamento |

---

## Lacunas / Decisões pendentes

1. **Coach Chat — paginação:** o scroll das telas 7–9 não tem limite definido — quantas mensagens são exibidas antes de clipar o histórico?
2. **Ícones dos botões de seleção:** não identificados na extração — usar Material Icons ou assets customizados?
3. **Gráfico de barras:** implementar como `CustomPainter` Flutter ou usar biblioteca de gráficos (ex: fl_chart)?
4. **Badge "MAIS RECENTE":** como determinar qual semana tem esse badge — sempre a mais recente com dados?
5. **Tooltip/link `← ATUAL`** no calendário de revisões: é interativo ou apenas label?
6. **Animação do CTA "CONVERSAR COM COACH":** aparece com transição ou imediatamente ao selecionar?
7. **Ícones dos treinos:** os ícones MuiSvgIconRoot são Material UI — substituir por equivalentes Flutter ou usar assets SVG próprios.
