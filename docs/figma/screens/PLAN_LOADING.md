# Tela: PLAN LOADING

> Extraído via Figma MCP — Fonte canônica: nó `1:5143`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> URL: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-5143

---

## Visão geral

Tela de carregamento exibida após o usuário completar todos os 9 assessments e pressionar "CRIAR MEU PLANO ↗". A IA gera o plano personalizado enquanto exibe uma lista de 8 tarefas em estilo terminal, com 3 estados visuais distintos. Esta tela é um **gate não-interativo** — o usuário não pode navegar para frente ou para trás.

**Dimensões do frame:** 394 × 852 px  
**Posição no fluxo:** pós-Assessment 09 (fora do fluxo de 13 passos — sem barra de progresso, sem dots)  
**Sem header, sem CTA, sem navegação.**

---

## Hierarquia de nós

```
plan_loading (1:5143) — frame raiz 394×852 px
└── PlanLoading (1:5144) — container fullscreen, centralizado
    └── Container (1:5145) — bloco de conteúdo 329.55×613.716 px
        ├── Container (1:5146) — status breadcrumb (row, top: 0)
        │   ├── Container (1:5147) — quadrado laranja 9.986×9.986 px
        │   └── Paragraph (1:5148)
        │       └── "COACH.AI > GERANDO PLANO"
        ├── Heading 1 (1:5150) — "Criando seu plano" (top: 37.98)
        ├── Paragraph (1:5152) — "Analisando nível , objetivo: 10K" (top: 72.37)
        ├── Container (1:5154) — lista de 8 tarefas (col, gap 8, top: 123.88)
        │   ├── Container (1:5155) — Task 1: OK — Analisando perfil...
        │   ├── Container (1:5162) — Task 2: OK — Calculando zonas cardíacas...
        │   ├── Container (1:5169) — Task 3: OK — Definindo volume...
        │   ├── Container (1:5176) — Task 4: ● — Gerando plano... (em progresso)
        │   ├── Container (1:5183) — Task 5: ○ — Calibrando alertas... (opacity 15%)
        │   ├── Container (1:5188) — Task 6: ○ — Definindo metas XP... (opacity 15%)
        │   ├── Container (1:5193) — Task 7: ○ — Preparando sessão... (opacity 15%)
        │   └── Container (1:5198) — Task 8: ○ — Plano pronto! (opacity 15%)
        └── Container (1:5203) — barra de progresso 4px (top: 609.72)
            └── Container (1:5204) — fill ciano ~50%
```

---

## Diferença crítica em relação às telas anteriores

Esta tela **não pertence ao fluxo de 13 passos**. Não há:
- Barra de progresso no topo
- Page indicator (dots)
- Botão VOLTAR
- Botão PULAR
- Logo RUNNIN.AI
- CTA button

O único elemento de "cabeçalho" é o breadcrumb de status da IA (`COACH.AI > GERANDO PLANO`), que é estilístico, não navegacional.

---

## Conteúdo verbatim das 8 tarefas

| # | Estado | Label | Texto principal | Detalhe |
|---|--------|-------|-----------------|---------|
| 1 | Completo | `OK` | Analisando seu perfil e histórico de saúde... | Nível, idade, peso, condições |
| 2 | Completo | `OK` | Calculando zonas cardíacas personalizadas... | Z1-Z5 baseadas no seu perfil |
| 3 | Completo | `OK` | Definindo volume e progressão semanal... | Periodização linear 3:1 |
| 4 | Em progresso | `●` | Gerando plano do primeiro mesociclo... | 4 semanas adaptativas |
| 5 | Pendente | `○` | Calibrando alertas de segurança... | — |
| 6 | Pendente | `○` | Definindo metas de XP e gamificação... | — |
| 7 | Pendente | `○` | Preparando sua primeira sessão... | — |
| 8 | Pendente | `○` | Plano pronto! | — |

> Nota: a Task 8 ("Plano pronto!") é a última — quando atingida, o fluxo deve avançar automaticamente para a home/dashboard.

---

## Tokens de cor

| Token (proposto)              | Hex / RGBA                       | Uso                                         |
|-------------------------------|----------------------------------|---------------------------------------------|
| `color/bg/base`               | `#050510`                        | Background da tela (igual a todas as outras) |
| `color/brand/coach`           | `#FF6B35`                        | Breadcrumb COACH.AI — quadrado + texto      |
| `color/brand/accent`          | `#00D4FF`                        | Label "OK", fill da barra de progresso       |
| `color/text/high`             | `#FFFFFF`                        | Heading + bullet "●" in-progress             |
| `color/text/medium`           | `rgba(255, 255, 255, 0.70)`      | Texto principal das tarefas (completas + em progresso) |
| `color/text/muted`            | `rgba(255, 255, 255, 0.55)`      | Subtítulo + texto das tarefas pendentes      |
| `color/text/dim`              | `rgba(255, 255, 255, 0.25)`      | Detalhe/sub-texto das tarefas (linha menor)  |
| `color/progress/track`        | `rgba(255, 255, 255, 0.05)`      | Track da barra de progresso                  |

---

## Tipografia

### Breadcrumb — "COACH.AI > GERANDO PLANO" (nó 1:5149)

| Propriedade    | Valor                     |
|----------------|---------------------------|
| Fonte          | JetBrains Mono Regular    |
| Tamanho        | 12 px                     |
| Line-height    | 18 px                     |
| Letter-spacing | 1.8 px                    |
| Cor            | `#FF6B35`                 |

### Heading — "Criando seu plano" (nó 1:5151)

| Propriedade    | Valor                     |
|----------------|---------------------------|
| Fonte          | JetBrains Mono Bold       |
| Tamanho        | 24 px                     |
| Line-height    | 26.4 px                   |
| Letter-spacing | −0.48 px                  |
| Cor            | `#FFFFFF`                 |

> Mesma tipografia do H2 dos Assessments (24px Bold -0.48px) — não usa o H1 28px do onboarding.

### Subtítulo — "Analisando nível , objetivo: 10K" (nó 1:5153)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono Regular          |
| Tamanho        | 13 px                           |
| Line-height    | 19.5 px                         |
| Letter-spacing | 0                               |
| Cor            | `rgba(255, 255, 255, 0.55)`     |

> O espaço antes da vírgula (`nível , objetivo`) é um placeholder: o nível do usuário deve ser interpolado (ex: `Analisando nível iniciante, objetivo: 10K`). O goal (`10K`) também é dinâmico.

### Label "OK" (nós 1:5157, 1:5164, 1:5171)

| Propriedade    | Valor           |
|----------------|-----------------|
| Fonte          | JetBrains Mono Regular |
| Tamanho        | 12 px           |
| Line-height    | 18 px           |
| Letter-spacing | 0               |
| Cor            | `#00D4FF`       |

### Bullet "●" in-progress (nó 1:5178)

| Propriedade    | Valor           |
|----------------|-----------------|
| Fonte          | JetBrains Mono Regular |
| Tamanho        | 12 px           |
| Line-height    | 18 px           |
| Cor            | `#FFFFFF`       |

### Texto principal das tarefas (nós 1:5159, 1:5166, 1:5173, 1:5180)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono Regular          |
| Tamanho        | 13 px                           |
| Line-height    | 19.5 px                         |
| Letter-spacing | 0                               |
| Cor            | `rgba(255, 255, 255, 0.70)`     |

### Sub-detalhe das tarefas (nós 1:5161, 1:5168, 1:5175, 1:5182)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono Regular          |
| Tamanho        | 11 px                           |
| Line-height    | 16.5 px                         |
| Letter-spacing | 0                               |
| Cor            | `rgba(255, 255, 255, 0.25)`     |

### Texto tarefas pendentes (nós 1:5187, 1:5192, 1:5197, 1:5202)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono Regular          |
| Tamanho        | 13 px                           |
| Line-height    | 19.5 px                         |
| Letter-spacing | 0                               |
| Cor            | `rgba(255, 255, 255, 0.55)`     |
| Opacidade do container | **15% (0.15)** — container inteiro, não o texto |

---

## Layout e espaçamento

### PlanLoading (nó 1:5144)

- **Tamanho:** 394 × 851.519 px (fullscreen)
- **Padding:** 118.901 px vertical, 32 px horizontal
- **Align items:** center
- **Justify content:** center

### Bloco de conteúdo (nó 1:5145) — 329.55 × 613.716 px

| Elemento                     | Top offset |
|------------------------------|------------|
| Breadcrumb COACH.AI          | 0 px       |
| Heading "Criando seu plano"  | 37.98 px   |
| Subtítulo                    | 72.37 px   |
| Lista de tarefas             | 123.88 px  |
| Barra de progresso           | 609.72 px  |

### Dimensões por tipo de task row

| Estado       | Altura   | Layout interno                        |
|--------------|----------|---------------------------------------|
| Completa     | 73.463 px | row, gap 12px, padding 4px V — 2 linhas de texto + detalhe |
| Em progresso | 49.465 px | row, gap 12px, padding 4px V — 2 linhas de texto + detalhe |
| Pendente     | 31.997 px | row, gap 12px, padding 4px V — 1 linha de texto, sem detalhe |

### Quadrado laranja no breadcrumb (nó 1:5147)

- **Tamanho:** 9.986 × 9.986 px (quadrado, sem border-radius)
- **Cor:** `#FF6B35`, opacity 89%

### Barra de progresso (nós 1:5203–1:5204)

- **Track:** 329.55 × 4 px, `rgba(255,255,255,0.05)`, sem border-radius
- **Fill:** `#00D4FF`, ~50% de largura no estado estático do design (task 4/8 em progresso)
- **Posição:** bottom do bloco de conteúdo

---

## Estados visuais das tarefas

### Estado A — Completa

```
[OK]  Texto principal da tarefa...          ← 13px, rgba(255,255,255,0.70)
      Sub-detalhe da tarefa                 ← 11px, rgba(255,255,255,0.25)
```
- Label `OK` em ciano `#00D4FF`, 12px
- Row height: 73.463 px
- Opacity do container: 100%

### Estado B — Em progresso

```
[●]   Texto da tarefa em andamento...       ← 13px, rgba(255,255,255,0.70)
      Sub-detalhe                           ← 11px, rgba(255,255,255,0.25)
```
- Bullet `●` em branco `#FFFFFF`, 12px
- Row height: 49.465 px
- Opacity do container: 100%

### Estado C — Pendente

```
[○]   Texto da tarefa futura...             ← 13px, rgba(255,255,255,0.55)
```
- Bullet `○` em `rgba(255,255,255,0.55)`, 12px
- Row height: 31.997 px
- **Opacity do container inteiro: 15%**
- Sem sub-detalhe

---

## Comportamento / UX

- **Sem interação:** nenhum botão, link ou gesto — o usuário aguarda
- **Animação implícita:** tarefas progridem C → B → A em sequência; barra de progresso anima
- **Bullet pulsante:** o `●` da task em progresso provavelmente pulsa ou pisca (padrão CLI loader)
- **Transição automática:** quando a Task 8 (`Plano pronto!`) chega ao estado A, a tela avança para a Home/Dashboard
- **Dados dinâmicos:** subtítulo usa nível e objetivo do usuário (do Assessment)
- **Navegação:** nenhuma — VOLTAR não existe; é uma tela de gate unidirecional

---

## Componentes identificados

| Componente              | Tipo        | Reutilizável | Descrição                                                    |
|-------------------------|-------------|:------------:|--------------------------------------------------------------|
| `CoachAIBreadcrumb`     | Widget base | Sim          | `[■] COACH.AI > {AÇÃO}` — quadrado laranja 10px + texto orange 12px 1.8ls |
| `PlanTaskRow`           | Widget      | Sim          | Row com estado (done/active/pending), label, texto, sub-detalhe |
| `PlanProgressBar`       | Widget      | Sim          | Track 4px + fill animado em ciano, sem border-radius         |
| `PlanLoadingPage`       | Page        | Não          | Monta todos os componentes acima                             |

---

## Screenshot de referência

> Tela confirma: sem header/nav, breadcrumb laranja `COACH.AI > GERANDO PLANO`, heading "Criando seu plano", subtítulo dinâmico, lista de 8 tarefas com estados OK/●/○, barra de progresso ciano em ~50%, fundo `#050510`.

---

## Tarefas Flutter

| ID      | Descrição                                                                | Depende de              |
|---------|--------------------------------------------------------------------------|-------------------------|
| T-PL01  | Criar `CoachAIBreadcrumb` (quadrado 10px + texto orange 12px tracking 1.8px) | AppColors, AppTypography |
| T-PL02  | Criar `PlanTaskRow` com enum de estados (done/active/pending)            | AppColors, AppTypography |
| T-PL03  | Criar `PlanProgressBar` (track + fill animado)                           | AppColors               |
| T-PL04  | Montar `PlanLoadingPage` com lista animada das 8 tarefas                 | T-PL01–T-PL03           |
| T-PL05  | Implementar lógica de progresso: sequenciar tarefas via API/stream       | Backend de geração      |
| T-PL06  | Navegar automaticamente para Home quando Task 8 chega ao estado done     | Home route              |

---

## Lacunas / Decisões pendentes

1. **Trigger de progresso:** as tarefas avançam via polling REST, WebSocket, ou SSE (Server-Sent Events)?
2. **Duração total:** quanto tempo leva a geração do plano? Há timeout/erro?
3. **Estado de erro:** se a geração falhar, o que acontece? Não previsto no design.
4. **Dados do subtítulo:** de onde vem o "nível" (ex: "iniciante") — calculado no backend ou escolhido no assessment?
5. **Animação do bullet ●:** confirmar se pisca, gira ou anima de outra forma.
6. **Tela seguinte:** qual a rota após "Plano pronto!" — Home? Dashboard? Detalhes do plano?
