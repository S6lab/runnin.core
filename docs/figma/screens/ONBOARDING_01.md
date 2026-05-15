# Tela: ONBOARDING — SLIDE 01

> Extraído via Figma MCP — Fonte canônica: nó `1:4295`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> URL: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-4295

---

## Visão geral

Primeira tela do fluxo de onboarding. Apresenta a proposta de valor do Runnin.AI como personal trainer de IA. Sem botão de VOLTAR (é o início do fluxo). Fundo escuro, identidade visual consistente com a splash.

**Dimensões do frame:** 393 × 851 px  
**Jornada:** Onboarding (1ª tela)  
**Slide ID no design:** `// SLIDE_01`  
**Número na barra de progresso:** posição 1/13

---

## Hierarquia de nós

```
onboarding (1:4295) — frame raiz, 393 × 851 px
└── Onboarding (1:4296) — container fullscreen
    ├── Container (1:4297) — barra de progresso topo, 393.5 × 2 px
    │   └── Container (1:4298) — fill ciano, ~30.5 px (≈ 1/13 da largura)
    ├── Container (1:4299) — cabeçalho, h=53 px
    │   ├── Container (1:4300) — espaço vazio à esquerda (sem botão VOLTAR no slide 1)
    │   └── Container (1:4301) — logo + PULAR, agrupados à direita
    │       ├── Container (1:4302) — logo RUNNIN .AI
    │       │   ├── Text (1:4303) — "RUNNIN"
    │       │   └── Text (1:4305) — badge ".AI"
    │       └── Button (1:4307) — "PULAR"
    ├── Container (1:4309) — área de conteúdo principal
    │   └── Container (1:4310) — bloco de conteúdo, 345.5 × 558.7 px
    │       ├── Paragraph (1:4311) — label "// SLIDE_01"
    │       ├── Heading 1 (1:4313) — título + número do slide
    │       │   ├── texto "Seu personal trainer de IA"
    │       │   └── Text (1:4315) — número "01" ciano
    │       ├── Paragraph (1:4317) — corpo do texto (descrição)
    │       └── Container (1:4319) — lista de 3 feature cards
    │           ├── Container (1:4320) — card "Inteligência adaptativa"
    │           ├── Container (1:4329) — card "Coach por voz"
    │           └── Container (1:4337) — card "Análise completa"
    └── Container (1:4345) — rodapé: botão CONTINUAR + indicador de página
        ├── Button (1:4346) — "CONTINUAR ↗"
        └── Container (1:4349) — 13 dots (1 ativo, 12 inativos)
```

---

## Tokens de cor

| Token (proposto)              | Hex / RGBA                       | Uso na tela                                    |
|-------------------------------|----------------------------------|------------------------------------------------|
| `color/bg/base`               | `#050510`                        | Fundo da tela                                  |
| `color/brand/accent`          | `#00D4FF`                        | Barra de progresso topo, slide label, número, botão CTA, ícones |
| `color/text/high`             | `#FFFFFF`                        | Título da tela, títulos dos cards              |
| `color/text/medium`           | `rgba(255, 255, 255, 0.60)`      | Corpo do texto / descrição da tela             |
| `color/text/muted`            | `rgba(255, 255, 255, 0.55)`      | Descrição dos cards, botão PULAR               |
| `color/surface/card`          | `rgba(255, 255, 255, 0.03)`      | Background dos feature cards                   |
| `color/border/card`           | `rgba(255, 255, 255, 0.08)`      | Borda dos feature cards e barra de progresso bg |
| `color/dot/active`            | `#00D4FF`                        | Dot ativo no page indicator                    |
| `color/dot/inactive`          | `rgba(255, 255, 255, 0.06)`      | Dots inativos no page indicator                |
| `color/badge/text`            | `#050510`                        | Texto ".AI" sobre badge ciano                  |

---

## Tipografia

### Label do slide — "// SLIDE_01" (nó 1:4312)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono                  |
| Peso           | Regular (400)                   |
| Tamanho        | 12 px                           |
| Line-height    | 18 px (150%)                    |
| Letter-spacing | 1.8 px                          |
| Cor            | `#00D4FF`                       |

### Título da tela — "Seu personal trainer de IA" (nó 1:4314)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono                  |
| Peso           | Bold (700)                      |
| Tamanho        | 28 px                           |
| Line-height    | 28 px (100%)                    |
| Letter-spacing | −0.84 px (tracking negativo)    |
| Cor            | `#FFFFFF`                       |
| Largura        | 346 px                          |

### Número do slide — "01" (nó 1:4316)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono                  |
| Peso           | Bold (700)                      |
| Tamanho        | 14 px                           |
| Line-height    | 14 px                           |
| Letter-spacing | −0.84 px                        |
| Cor            | `#00D4FF`                       |
| Posição        | `top-right` do bloco do heading |

### Corpo do texto / descrição (nó 1:4318)

| Propriedade    | Valor                                |
|----------------|--------------------------------------|
| Fonte          | JetBrains Mono                       |
| Peso           | Regular (400)                        |
| Tamanho        | 15 px                                |
| Line-height    | 25.5 px (170%)                       |
| Letter-spacing | padrão (0)                           |
| Cor            | `rgba(255, 255, 255, 0.60)`          |
| Texto          | "Um coach que te conhece, planeja seu treino e te acompanha em cada quilômetro. Antes, durante e depois da corrida." |
| Largura        | 346 px                               |

### Título dos feature cards (ex: nó 1:4326)

| Propriedade    | Valor           |
|----------------|-----------------|
| Fonte          | JetBrains Mono  |
| Peso           | Bold (700)      |
| Tamanho        | 13 px           |
| Line-height    | 19.5 px (150%)  |
| Letter-spacing | padrão (0)      |
| Cor            | `#FFFFFF`       |

### Descrição dos feature cards (ex: nó 1:4328)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono                  |
| Peso           | Regular (400)                   |
| Tamanho        | 12 px                           |
| Line-height    | 18 px (150%)                    |
| Letter-spacing | padrão (0)                      |
| Cor            | `rgba(255, 255, 255, 0.55)`     |
| Largura        | 273 px                          |

### CTA "CONTINUAR ↗" (nó 1:4347 / 1:4348)

| Propriedade    | Valor           |
|----------------|-----------------|
| Fonte          | JetBrains Mono  |
| Peso           | Bold (700)      |
| Tamanho        | 12 px           |
| Line-height    | 18 px           |
| Letter-spacing | 1.2 px          |
| Cor            | `#050510`       |
| Casing         | ALL CAPS        |

### Botão "PULAR" (nó 1:4308)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono                  |
| Peso           | Medium (500)                    |
| Tamanho        | 13 px                           |
| Line-height    | 19.5 px                         |
| Letter-spacing | 1.3 px                          |
| Cor            | `rgba(255, 255, 255, 0.55)`     |

---

## Layout e espaçamento

### Barra de progresso topo (nó 1:4297)

- **Tamanho total:** 393.5 × 1.99 px (~2 px)
- **Background:** `rgba(255, 255, 255, 0.08)`
- **Fill ativo (nó 1:4298):** `#00D4FF`, largura ≈ 30.5 px (≈ 7.7% = 1/13 da tela)

### Cabeçalho (nó 1:4299)

- **Altura:** 53 px (sem botão VOLTAR — é o primeiro slide)
- **Padding horizontal:** 24 px
- **Padding vertical:** 16 px
- **Layout:** row, `justify-between`
- **Lado esquerdo:** vazio (espaço reservado para consistência de layout)
- **Lado direito:** logo RUNNIN .AI + "PULAR", gap = 16 px

### Logo RUNNIN .AI no header (nó 1:4302)

- **Tamanho:** 81.1 × 21 px
- **Layout:** row, gap = 4 px, items-center
- **"RUNNIN":** 49 × 21 px, JetBrains Mono Bold 14px, tracking 1.4px, branco
- **Badge ".AI":** 28.2 × 17.5 px, bg `#00D4FF`, padding 6px H × 2px V

### Área de conteúdo principal (nó 1:4309)

- **Padding:** top 51.9 px, bottom 83.9 px, horizontal 24 px
- **Layout:** column, justify-center

### Bloco de conteúdo (nó 1:4310)

- **Tamanho:** 345.5 × 558.7 px
- **Layout:** posicionamento absoluto dos filhos

### Espaçamento interno do conteúdo (distâncias entre elementos, dentro de 1:4310)

| Elemento                    | Top offset desde o início do container |
|-----------------------------|----------------------------------------|
| Label "// SLIDE_01"         | 0 px                                   |
| Heading "Seu personal..."   | 34 px                                  |
| Parágrafo descritivo        | 114 px                                 |
| Container de feature cards  | 247.8 px                               |

### Feature cards container (nó 1:4319)

- **Tamanho:** 345.5 × 310.8 px
- **Layout:** column, gap = 16 px

### Feature card individual (ex: nó 1:4320)

- **Tamanho:** 345.5 × 92.9 px
- **Background:** `rgba(255, 255, 255, 0.03)`
- **Borda:** 1.741 px `rgba(255, 255, 255, 0.08)`, solid
- **Padding:** 17.74 px em todos os lados
- **Layout interno:** row, gap = 16 px, items-start

### Ícone dentro do card (ex: nó 1:4321)

- **Tamanho:** 22 × 22 px
- **Tipo:** imagem/SVG (MuiSvgIcon) em ciano
- **Posição:** alinhado ao topo

### Grupo de texto dentro do card (ex: nó 1:4324)

- **Tamanho:** 272 × 57.5 px
- **Layout:** column, gap = 2 px
- **Título:** 1 linha, 19.5 px de altura
- **Descrição:** 2 linhas, 36 px de altura

### Rodapé — CTA + indicador (nó 1:4345)

- **Altura:** 102 px
- **Padding horizontal:** 24 px
- **Layout:** column, gap = 16 px

### Botão CONTINUAR (nó 1:4346)

- **Tamanho:** 345.5 × 50 px
- **Background:** `#00D4FF`
- **Conteúdo:** "CONTINUAR ↗" centrado
- **O "↗" é um texto separado** (nó 1:4348), posicionado ao lado direito do "CONTINUAR "

### Indicador de página — dots (nó 1:4349)

- **Layout:** row, gap = 5.99 px, justify-center
- **Total:** 13 dots
- **Dot ativo (posição 1):** `#00D4FF`, 20 × 4 px, border-radius máximo (pill)
- **Dots inativos (posições 2–13):** `rgba(255,255,255,0.06)`, 6 × 4 px, border-radius máximo
- **Padding horizontal:** ≈ 91 px (centralização total)

---

## Feature cards — conteúdo

| Ordem | Título                    | Descrição                                    | nodeId ícone |
|-------|---------------------------|----------------------------------------------|--------------|
| 1     | Inteligência adaptativa   | O plano evolui com você a cada corrida       | 1:4321       |
| 2     | Coach por voz             | Orientação em tempo real, sem tirar o celular do bolso | 1:4330 |
| 3     | Análise completa          | Métricas, zonas cardíacas, benchmark e tendências | 1:4338  |

---

## Componentes identificados

| Componente                  | Tipo           | Reutilizável | Descrição                                              |
|-----------------------------|----------------|:------------:|--------------------------------------------------------|
| `OnboardingTopProgressBar`  | Widget base    | Sim          | Barra de 2px topo que avança por slide                 |
| `OnboardingHeader`          | Widget         | Sim          | Logo + PULAR à direita; variante sem VOLTAR (slide 1)  |
| `OnboardingSlideLabel`      | Widget base    | Sim          | "// SLIDE_XX" em ciano com tracking                    |
| `OnboardingHeading`         | Widget base    | Sim          | Título + número do slide (ciano, top-right)            |
| `OnboardingFeatureCard`     | Widget         | Sim          | Ícone + título + descrição, borda sutil                |
| `OnboardingContinueButton`  | Widget         | Sim          | CTA ciano fullwidth com seta ↗                        |
| `OnboardingPageIndicator`   | Widget         | Sim          | 13 dots — ativo largo ciano, inativos menores          |

---

## Comportamento / UX

- **Objetivo:** apresentar a proposta de valor da IA coach aos novos usuários
- **Navegação de entrada:** vem da Splash screen (sem back button no slide 1)
- **Navegação de saída:** CONTINUAR → slide 02; PULAR → destino indefinido no design
- **Variante de cabeçalho:** slide 1 não tem botão VOLTAR; slides 2+ têm
- **Progresso:**
  - Barra topo: fill de 1/13 da largura
  - Dots: 1 ativo, 12 inativos
- **Total de slides:** 13 (inferido pela quantidade de dots)
- **Animação de transição entre slides:** **indefinida no design** — requer decisão de produto
- **Estado de erro:** não previsto no design
- **Acessibilidade:**
  - Label do slide `// SLIDE_01` pode ser `ExcludeSemantics` ou ter semântica de "passo 1 de 13"
  - Botões CONTINUAR e PULAR devem ter `semanticsLabel` adequado
  - Feature cards podem ser `Semantics(container: true)` com label combinando título + descrição

---

## Screenshot de referência

> Imagem extraída do Figma MCP (válida por ~7 dias):  
> Slide 1 confirma: fundo #050510, logo+PULAR no header, label "// SLIDE_01", título "Seu personal trainer de IA 01", 3 feature cards em coluna, botão CONTINUAR ciano e 13 dots de progresso.

---

## Tarefas Flutter (referência para tasks.md)

| ID     | Descrição                                                       | Depende de                      |
|--------|-----------------------------------------------------------------|---------------------------------|
| T-OB01 | Criar `OnboardingTopProgressBar` (barra 2px com fill proporcional) | AppColors               |
| T-OB02 | Criar `OnboardingHeader` c/ variante com/sem VOLTAR             | AppColors, AppTypography        |
| T-OB03 | Criar `OnboardingSlideLabel` ("// SLIDE_XX")                    | AppColors, AppTypography        |
| T-OB04 | Criar `OnboardingHeading` (título + número ciano)               | AppColors, AppTypography        |
| T-OB05 | Criar `OnboardingFeatureCard` (ícone + título + descrição)      | AppColors, AppTypography        |
| T-OB06 | Criar `OnboardingContinueButton` (CTA ciano fullwidth)          | AppColors, AppTypography        |
| T-OB07 | Criar `OnboardingPageIndicator` (13 dots, ativo largo)          | AppColors                       |
| T-OB08 | Montar `OnboardingSlide01Page` com todos os componentes acima   | T-OB01 a T-OB07                 |
| T-OB09 | Implementar conteúdo: ícones dos cards (slide 01)               | Assets / Icon pipeline          |

---

## Lacunas / Decisões pendentes

1. **PULAR:** destino após pular o onboarding — home ou tela de cadastro?
2. **Ícones dos cards:** os ícones são assets externos (MuiSvgIcon) — precisam ser baixados ou substituídos por ícones do Material/Flutter
3. **Total de slides:** 13 dots visíveis — quantos slides existem no total? (restam 10 a enviar)
4. **Animação de transição:** slide, fade, ou sem animação?
5. **"CONTINUAR" no último slide:** redireciona para cadastro ou login?
6. **Persistência:** o onboarding é exibido apenas uma vez (flag `isFirstLaunch`)?
