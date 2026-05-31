# Tela: ONBOARDING — SLIDE 02

> Extraído via Figma MCP — Fonte canônica: nó `1:4364`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> URL: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-4364

---

## Visão geral

Segunda tela do fluxo de onboarding. Foca na funcionalidade de **coach por voz em tempo real**. Introduz o botão VOLTAR no header (ausente no slide 1). Mesma estrutura visual do slide 01, com conteúdo diferente.

**Dimensões do frame:** 393 × 851 px  
**Jornada:** Onboarding (2ª tela)  
**Slide ID no design:** `// SLIDE_02`  
**Número na barra de progresso:** posição 2/13

---

## Hierarquia de nós

```
onboarding 2 (1:4364) — frame raiz, 393 × 851 px
└── Onboarding (1:4365) — container fullscreen
    ├── Container (1:4366) — barra de progresso topo, 393.5 × 2 px
    │   └── Container (1:4367) — fill ciano, ~60.5 px (≈ 2/13 da largura)
    ├── Container (1:4368) — cabeçalho, h=72.5 px (maior que slide 1, pois tem VOLTAR)
    │   ├── Container (1:4369) — botão VOLTAR (esquerda)
    │   │   └── Button (1:4370) — "← VOLTAR"
    │   └── Container (1:4375) — logo + PULAR (direita)
    │       ├── Container (1:4376) — logo RUNNIN .AI
    │       └── Button (1:4381) — "PULAR"
    ├── Container (1:4383) — área de conteúdo principal
    │   └── Container (1:4384) — bloco de conteúdo, 345.5 × 533.2 px
    │       ├── Paragraph (1:4385) — label "// SLIDE_02"
    │       ├── Heading 1 (1:4387) — título + número do slide
    │       │   ├── texto "Te guia por voz, em tempo real"
    │       │   └── Text (1:4389) — número "02" ciano
    │       ├── Paragraph (1:4391) — corpo do texto
    │       └── Container (1:4393) — lista de 3 feature cards
    │           ├── Container (1:4394) — card "Alertas inteligentes"
    │           ├── Container (1:4402) — card "Splits ao vivo"
    │           └── Container (1:4410) — card "Integra com música"
    └── Container (1:4418) — rodapé: botão CONTINUAR + indicador de página
        ├── Button (1:4419) — "CONTINUAR ↗"
        └── Container (1:4422) — 13 dots (2º ativo ciano, 1º dim-branco, 11 inativos)
```

---

## Diferenças em relação ao SLIDE_01

### Cabeçalho (nó 1:4368)

- **Altura:** 72.5 px (vs 53 px no slide 1) — maior porque inclui o botão VOLTAR
- **Lado esquerdo:** botão VOLTAR com ícone ← e label "VOLTAR"

### Botão VOLTAR (nó 1:4370)

| Propriedade           | Valor                             |
|-----------------------|-----------------------------------|
| Tamanho               | 103.5 × 40.5 px                   |
| Background            | `rgba(255, 255, 255, 0.06)`       |
| Borda                 | 1.741 px `rgba(255, 255, 255, 0.1)` |
| Padding               | 13.74 px H × 9.74 px V            |
| Layout                | row, gap 8 px, items-center       |
| Ícone ←               | JetBrains Mono Medium 20px, `rgba(255,255,255,0.55)` |
| Label "VOLTAR"        | JetBrains Mono Medium 14px, tracking 1.12px, `rgba(255,255,255,0.55)` |

### Indicador de página (nó 1:4422)

- **Dot 1 (visitado):** `rgba(255, 255, 255, 0.20)`, 6 × 4 px — visitado/anterior
- **Dot 2 (ativo):** `#00D4FF`, 20 × 4 px
- **Dots 3–13 (inativos):** `rgba(255, 255, 255, 0.06)`, 6 × 4 px

> Padrão identificado: dots anteriores ao ativo mudam de `0.06` para `0.20` de opacidade.

### Barra de progresso topo (nó 1:4367)

- Fill ciano: ≈ 60.5 px de 393.5 px (≈ 15.4% = 2/13)

---

## Tokens de cor

> Idênticos ao SLIDE_01. Ver [ONBOARDING_01.md](ONBOARDING_01.md#tokens-de-cor) para referência completa.

Token adicional identificado neste slide:

| Token (proposto)       | Hex / RGBA                       | Uso                              |
|------------------------|----------------------------------|----------------------------------|
| `color/dot/visited`    | `rgba(255, 255, 255, 0.20)`      | Dot de slide já visitado         |
| `color/btn/back/bg`    | `rgba(255, 255, 255, 0.06)`      | Fundo do botão VOLTAR            |
| `color/btn/back/border`| `rgba(255, 255, 255, 0.10)`      | Borda do botão VOLTAR            |

---

## Tipografia

> Mesmos estilos do SLIDE_01. Ver [ONBOARDING_01.md](ONBOARDING_01.md#tipografia) para tabelas completas.

Especificidades do SLIDE_02:

### Título da tela — "Te guia por voz, em tempo real" (nó 1:4388)

| Propriedade    | Valor                                |
|----------------|--------------------------------------|
| Fonte          | JetBrains Mono Bold                  |
| Tamanho        | 28 px                                |
| Line-height    | 28 px (100%) — título ocupa 2 linhas |
| Letter-spacing | −0.84 px                             |
| Cor            | `#FFFFFF`                            |
| Texto          | "Te guia por voz, em tempo real"     |

### Corpo do texto (nó 1:4392)

| Propriedade | Valor                                                                                    |
|-------------|------------------------------------------------------------------------------------------|
| Texto       | "Pace, motivação, dicas — o Coach fala com você durante a corrida. Sem tirar o celular do bolso." |
| Cor         | `rgba(255, 255, 255, 0.60)`                                                              |
| Tamanho     | 15 px, line-height 25.5 px                                                               |
| Altura      | 76.4 px (≈ 3 linhas, vs 101.9 px / 4 linhas no slide 1)                                 |

---

## Layout e espaçamento

### Área de conteúdo principal (nó 1:4383)

- **Padding:** top 54.9 px, bottom 86.9 px, horizontal 24 px
- **Ligeiramente diferente do slide 1** (top 51.9 / bottom 83.9) — ajuste para acomodar o cabeçalho maior

### Espaçamento interno do conteúdo (dentro de 1:4384)

| Elemento                    | Top offset |
|-----------------------------|------------|
| Label "// SLIDE_02"         | 0 px       |
| Heading "Te guia por voz…"  | 34 px      |
| Parágrafo descritivo        | 114 px     |
| Container de feature cards  | 222.4 px   |

> O container de cards começa 25.4 px mais cedo que no slide 1 (247.8 px), compensando o parágrafo mais curto (3 linhas vs 4 linhas no slide 1).

---

## Feature cards — conteúdo

| Ordem | Título               | Descrição                                       | nodeId ícone |
|-------|----------------------|-------------------------------------------------|--------------|
| 1     | Alertas inteligentes | Avisa quando sair da zona de pace ou BPM alvo   | 1:4395       |
| 2     | Splits ao vivo       | Comentários a cada km sobre seu desempenho      | 1:4403       |
| 3     | Integra com música   | Volume baixa automaticamente durante orientações | 1:4411      |

> Estrutura dos cards idêntica ao slide 01: 345.5 × 92.9 px, padding 17.74px, gap 16px entre ícone e texto.

---

## Componentes identificados

> Mesmos componentes do slide 01 — todos reutilizáveis. Este slide usa a variante do `OnboardingHeader` **com botão VOLTAR**.

| Componente                  | Variante usada neste slide          |
|-----------------------------|-------------------------------------|
| `OnboardingTopProgressBar`  | progress = 2/13                     |
| `OnboardingHeader`          | com botão VOLTAR (outlined)         |
| `OnboardingSlideLabel`      | "// SLIDE_02"                       |
| `OnboardingHeading`         | "Te guia por voz, em tempo real" + "02" |
| `OnboardingFeatureCard`     | 3 instâncias com conteúdo diferente |
| `OnboardingContinueButton`  | idêntico ao slide 01                |
| `OnboardingPageIndicator`   | currentIndex = 1 (0-based), visitedCount = 1 |

---

## Comportamento / UX

- **Objetivo:** apresentar o diferencial do coach por voz em tempo real
- **Navegação de entrada:** vem do slide 01 (botão CONTINUAR) ou de slide 03 (botão VOLTAR)
- **Navegação de saída:**
  - VOLTAR → slide 01
  - CONTINUAR → slide 03
  - PULAR → destino indefinido no design
- **Estado do dot anterior:** quando avança, o dot anterior muda de `rgba(255,255,255,0.06)` para `rgba(255,255,255,0.20)` — indica "visitado"

---

## Screenshot de referência

> Slide 2 confirma: header com botão "← VOLTAR" à esquerda, barra de progresso ~15% preenchida, label "// SLIDE_02", título "Te guia por voz, em tempo real 02", 3 cards (Alertas inteligentes / Splits ao vivo / Integra com música), botão CONTINUAR, dots com 1 visitado + 1 ativo.

---

## Tarefas Flutter (referência para tasks.md)

| ID     | Descrição                                                        | Depende de               |
|--------|------------------------------------------------------------------|--------------------------|
| T-OB10 | Montar `OnboardingSlide02Page` com todos os componentes          | T-OB01 a T-OB07          |
| T-OB11 | Implementar conteúdo: ícones dos cards (slide 02)                | Assets / Icon pipeline   |
| T-OB12 | Garantir variante com VOLTAR no `OnboardingHeader`               | T-OB02                   |
| T-OB13 | Implementar lógica de dot "visitado" no `OnboardingPageIndicator`| T-OB07                   |

---

## Lacunas / Decisões pendentes

1. **Ícones:** diferentes dos do slide 01 — precisam ser mapeados para ícones Flutter correspondentes (raio, corredor, nota musical)
2. **Animação de transição entre slides:** não especificada
3. **Comportamento do VOLTAR:** navega para o slide anterior ou para a splash?
