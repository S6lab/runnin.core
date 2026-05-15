# Tela: ONBOARDING — SLIDE 03

> Extraído via Figma MCP — Fonte canônica: nó `1:4437`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> URL: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-4437

---

## Visão geral

Terceira tela do fluxo de onboarding. Apresenta o sistema de **gamificação e evolução** do app. Mesmo padrão dos slides anteriores, com 2 dots visitados e o 3º ativo.

**Dimensões do frame:** 393 × 851 px  
**Jornada:** Onboarding (3ª tela)  
**Slide ID no design:** `// SLIDE_03`  
**Número na barra de progresso:** posição 3/13

---

## Hierarquia de nós

```
onboarding 3 (1:4437) — frame raiz, 393 × 851 px
└── Onboarding (1:4438) — container fullscreen
    ├── Container (1:4439) — barra de progresso topo, 393.5 × 2 px
    │   └── Container (1:4440) — fill ciano, ~90.8 px (≈ 3/13 da largura)
    ├── Container (1:4441) — cabeçalho, h=72.5 px (com VOLTAR)
    │   ├── Container (1:4442) — botão VOLTAR (esquerda)
    │   │   └── Button (1:4443) — "← VOLTAR"
    │   └── Container (1:4448) — logo + PULAR (direita)
    │       ├── Container (1:4449) — logo RUNNIN .AI
    │       └── Button (1:4454) — "PULAR"
    ├── Container (1:4456) — área de conteúdo principal
    │   └── Container (1:4457) — bloco de conteúdo, 345.5 × 530.7 px
    │       ├── Paragraph (1:4458) — label "// SLIDE_03"
    │       ├── Heading 1 (1:4460) — título + número do slide
    │       │   ├── texto "Evolua e conquiste"
    │       │   └── Text (1:4462) — número "03" ciano
    │       ├── Paragraph (1:4464) — corpo do texto
    │       └── Container (1:4466) — lista de 3 feature cards
    │           ├── Container (1:4467) — card "Badges e XP"
    │           ├── Container (1:4475) — card "Benchmark"
    │           └── Container (1:4483) — card "Periodização IA"
    └── Container (1:4491) — rodapé: botão CONTINUAR + indicador de página
        ├── Button (1:4492) — "CONTINUAR ↗"
        └── Container (1:4495) — 13 dots (3º ativo ciano, 1º e 2º dim-branco, 10 inativos)
```

---

## Diferenças em relação aos slides anteriores

### Barra de progresso topo (nó 1:4440)

- Fill ciano: ≈ 90.8 px de 393.5 px (≈ 23.1% = 3/13)

### Indicador de página (nó 1:4495)

- **Dot 1 (visitado):** `rgba(255, 255, 255, 0.20)`, 6 × 4 px
- **Dot 2 (visitado):** `rgba(255, 255, 255, 0.20)`, 6 × 4 px
- **Dot 3 (ativo):** `#00D4FF`, 20 × 4 px
- **Dots 4–13 (inativos):** `rgba(255, 255, 255, 0.06)`, 6 × 4 px

> Confirma o padrão: todos os dots anteriores ao ativo ficam em `rgba(255,255,255,0.20)` ("visitado").

### Título

- **"Evolua e conquiste"** — cabe em 1 linha (vs 2 linhas nos slides 1 e 2)
- **Número "03"** posicionado em `left: 293.09 px` (vs 330.45 px nos slides 1 e 2) — ajuste para ficar ao final do texto de 1 linha

### Corpo do texto (nó 1:4465)

- **Texto:** "Gamificação, metas e recompensas que te fazem voltar todo dia. Não é só correr — é um jogo de evolução pessoal."
- **Altura:** 101.9 px (≈ 4 linhas, mesma que o slide 1)
- **Top offset dentro do container:** 85.98 px (vs 113.98 px nos slides 1 e 2) — começa mais cedo porque o heading é de 1 linha (28 px) vs 2 linhas (56 px) nos outros

### Espaçamento interno do conteúdo (dentro de 1:4457)

| Elemento                    | Top offset |
|-----------------------------|------------|
| Label "// SLIDE_03"         | 0 px       |
| Heading "Evolua e conquiste"| 34 px      |
| Parágrafo descritivo        | 85.98 px   |
| Container de feature cards  | 219.85 px  |

---

## Tokens de cor

> Idênticos ao SLIDE_01 e SLIDE_02. Ver [ONBOARDING_01.md](ONBOARDING_01.md#tokens-de-cor).  
> Token `color/dot/visited` (`rgba(255,255,255,0.20)`) confirmado — agora em 2 dots.

---

## Tipografia

> Estilos idênticos aos slides anteriores. Ver [ONBOARDING_01.md](ONBOARDING_01.md#tipografia).

Especificidades do SLIDE_03:

### Título — "Evolua e conquiste" (nó 1:4461)

| Propriedade    | Valor                |
|----------------|----------------------|
| Texto          | "Evolua e conquiste" |
| Linhas         | 1 linha (28 px)      |
| Letter-spacing | −0.84 px             |

> Heading menor (1 linha = 28px) vs slides 1 e 2 (2 linhas = 56px). Isso empurra os demais elementos para cima dentro do container.

---

## Layout e espaçamento

### Área de conteúdo principal (nó 1:4456)

- **Padding:** top 56.2 px, bottom 88.2 px, horizontal 24 px
- Ligeiramente diferente dos slides anteriores (ajustes finos de ±2 px)

---

## Feature cards — conteúdo

| Ordem | Título           | Descrição                                                         | nodeId ícone |
|-------|------------------|-------------------------------------------------------------------|--------------|
| 1     | Badges e XP      | Conquiste marcos, suba de nível, desbloqueie recompensas          | 1:4468       |
| 2     | Benchmark        | Compare seu desempenho com outros corredores do seu nível         | 1:4476       |
| 3     | Periodização IA  | Planejamento mensal/semanal que se adapta ao seu progresso        | 1:4484       |

> Estrutura dos cards idêntica aos slides anteriores.

---

## Componentes identificados

> Mesmos componentes dos slides anteriores — todos reutilizáveis.

| Componente                  | Variante usada neste slide                               |
|-----------------------------|----------------------------------------------------------|
| `OnboardingTopProgressBar`  | progress = 3/13                                          |
| `OnboardingHeader`          | com botão VOLTAR (variante com VOLTAR)                   |
| `OnboardingSlideLabel`      | "// SLIDE_03"                                            |
| `OnboardingHeading`         | "Evolua e conquiste" + "03" (heading de 1 linha)         |
| `OnboardingFeatureCard`     | 3 instâncias                                             |
| `OnboardingContinueButton`  | idêntico aos slides anteriores                           |
| `OnboardingPageIndicator`   | currentIndex = 2 (0-based), visitedCount = 2             |

---

## Comportamento / UX

- **Objetivo:** apresentar o sistema de gamificação, recompensas e progressão
- **Navegação de entrada:** vem do slide 02 (botão CONTINUAR) ou de slide 04 (botão VOLTAR, se existir)
- **Navegação de saída:**
  - VOLTAR → slide 02
  - CONTINUAR → slide 04 (não recebido ainda)
  - PULAR → destino indefinido no design
- **Padrão do indicador de progresso:** 2 dots visitados (`rgba(255,255,255,0.20)`) + 1 ativo (ciano) + 10 inativos (`rgba(255,255,255,0.06)`)
- **Padrão da barra topo:** cresce linearmente a cada slide (≈ +30.3 px por slide = 393.5/13)

---

## Screenshot de referência

> Slide 3 confirma: header com "← VOLTAR", barra de progresso ~23% preenchida, label "// SLIDE_03", título "Evolua e conquiste 03" em 1 linha, 3 cards (Badges e XP / Benchmark / Periodização IA), botão CONTINUAR, dots com 2 visitados + 1 ativo.

---

## Tarefas Flutter (referência para tasks.md)

| ID     | Descrição                                                        | Depende de             |
|--------|------------------------------------------------------------------|------------------------|
| T-OB14 | Montar `OnboardingSlide03Page` com todos os componentes          | T-OB01 a T-OB07        |
| T-OB15 | Implementar conteúdo: ícones dos cards (slide 03)                | Assets / Icon pipeline |
| T-OB16 | Validar que `OnboardingHeading` adapta corretamente para 1 linha | T-OB04                 |

---

## Lacunas / Decisões pendentes

1. **Slides 04–13:** ainda não recebidos — aguardando próximo bloco
2. **Ícones:** troféu, gráfico de tendência, calendário — mapear para Flutter Material Icons ou assets customizados
3. **Slide "CONTINUAR" final:** qual o destino da última tela de onboarding?
4. **Lógica de estado "visitado":** a cor mais clara (`rgba(255,255,255,0.20)`) deve persistir se o usuário navegar para frente novamente?
