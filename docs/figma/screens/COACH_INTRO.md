# Telas: COACH INTRO (Briefing Inicial — 4 slides)

> Extraído via Figma MCP — Nós `1:5770`, `1:5818`, `1:5870`, `1:5922`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)

---

## Visão geral

Fluxo de 4 slides apresentando o Coach.AI ao usuário logo antes da primeira corrida. Exibido após o Plan Loading e antes do Pre-Run. Cada slide tem barra de progresso animada no topo (25%/50%/75%/100%), breadcrumb "COACH.AI > BRIEFING INICIAL", botão PULAR à direita, ícone 36 px, título, parágrafo e bullet cards.

**Dimensões:** 393.545 × 851.519 px  
**Sem bottom tab bar.** Sem botão VOLTAR. CTA muda no último slide.

---

## Mapeamento dos 4 slides

| nodeId | Nome interno | Slide | Progress | CTA | Dots ativos |
|--------|-------------|-------|----------|-----|-------------|
| 1:5770 | preparar_primeira_corrida01 | 1/4 | 25% | CONTINUAR ↗ | Dot 1 ativo |
| 1:5818 | perara_primeira_corrida02 | 2/4 | 50% | CONTINUAR ↗ | Dot 1 visitado, 2 ativo |
| 1:5870 | preparar_primeira_corrida03 | 3/4 | 75% | CONTINUAR ↗ | Dots 1-2 visitados, 3 ativo |
| 1:5922 | preparar_primeira_corrida04 | 4/4 | 100% | **[ VAMOS CORRER ] ↗** | Dots 1-3 visitados, 4 ativo |

---

## Layout arquitetura (compartilhado)

```
CoachIntro (frame 393.545×851.519)
├── Progress bar (h 1.986 px, topo)
├── Top nav bar (h 49.982 px)
│   ├── Esquerda: [■] COACH.AI > BRIEFING INICIAL
│   └── Direita: PULAR
├── Content area (flex-1, justify-center)
│   ├── Label "// SEÇÃO_DO_SLIDE"
│   ├── Ícone 36×36 px + Heading 26 px (row)
│   ├── Parágrafo 15 px
│   └── Bullet cards (3 ou 4 itens)
└── Bottom actions (h 101.978 px)
    ├── Botão CTA fullwidth
    └── 4 page indicator dots
```

---

## Barra de progresso (topo)

- **Track:** `rgba(255,255,255,0.08)`, fullwidth, h 1.986 px
- **Fill:** `#00D4FF`
- **Largura do fill:** 25% / 50% / 75% / 100% por slide (implementar como `pr` offset no Figma → usar `width` proporcional)

---

## Top Navigation Bar

| Elemento | Valor |
|----------|-------|
| Padding | px 24, py 16, h 49.982 px |
| Dot indicador | 9.986 × 9.986 px quadrado, `#FF6B35`, opacity variável (83%/62%/70%/36%) |
| Label | "COACH.AI > BRIEFING INICIAL" — Regular 12 px, `#FF6B35`, tracking 1.8 px |
| Botão PULAR | Medium 12 px, `rgba(255,255,255,0.55)`, tracking 1.2 px |

> Nota: a opacidade variável do dot laranja (83% → 62% → 70% → 36%) sugere animação de pulso — implementar como `AnimationController` oscillating.

---

## Tipografia (compartilhada)

| Elemento | Fonte | Peso | Tamanho | LS | LH | Cor |
|----------|-------|------|---------|----|----|-----|
| Label de seção (ex: "// QUEM SOU EU") | JetBrains Mono | Regular | 12 px | 2.4 px | 18 px | `#00D4FF` |
| Heading principal | JetBrains Mono | Bold | 26 px | −0.78 px | 27.3 px | `#FFFFFF` |
| Parágrafo | JetBrains Mono | Regular | 15 px | 0 | 25.5 px | `rgba(255,255,255,0.70)` |
| Bullet marker "▸" | JetBrains Mono | Regular | 12 px | 0 | 18 px | `#00D4FF` |
| Bullet texto | JetBrains Mono | Regular | 13 px | 0 | 19.5 px | `rgba(255,255,255,0.65)` |
| CTA botão | JetBrains Mono | Bold | 12 px | 1.2 px | 18 px | `#050510` |

---

## Bullet Feature Card (componente compartilhado)

- **Tamanho:** 345.549 × 66.498 px (2 linhas) ou 46.989 px (1 linha)
- **Background:** `rgba(255,255,255,0.03)`
- **Border:** 1.741 px `rgba(255,255,255,0.08)`
- **Padding:** pt 13.74, pb 13.741, px 17.74
- **Layout:** row, gap 12 px (marker + texto)
- **Marker "▸":** `#00D4FF`, 12 px

---

## Page Indicator Dots

- **Track:** flex row, gap 8, justify-center
- **Dot ativo:** `#00D4FF`, 23.998 × 4 px, pill
- **Dot visitado:** `rgba(255,255,255,0.20)`, 5.986 × 4 px
- **Dot inativo:** `rgba(255,255,255,0.06)`, 5.986 × 4 px

---

## Bottom Actions

- **Height:** 101.978 px, padding px 24, gap 16
- **Botão CTA:** fullwidth × 49.982 px, bg `#00D4FF`, Bold 12 px `#050510`, tracking 1.2 px

---

## Slide 1/4 — "Quem sou eu" (nó 1:5770)

**Label:** `// QUEM SOU EU`  
**Ícone:** 36 px (brain/AI icon)  
**Heading:** "Eu sou seu Coach.AI"

**Parágrafo:**
> "Não sou um app de cronômetro. Sou um treinador de inteligência artificial que te conhece, se adapta a você e evolui junto. Cada corrida que você faz me torna mais preciso."

**Bullet cards (3 itens):**
1. "Analiso seu pace, BPM, splits e padrão de recuperação"
2. "Comparo com milhares de corredores do seu nível"
3. "Aprendo com cada sessão para refinar seu plano"

**Layout do conteúdo:**
- Padding: pt 98.386, pb 130.383, px 24
- Container: 345.549 × 468.803 px
- Label em top 0, heading em top 33.98, parágrafo em top 93.98, bullets em top 253.31

---

## Slide 2/4 — "Durante a corrida" (nó 1:5818)

**Label:** `// DURANTE A CORRIDA`  
**Ícone:** 36 px (microfone/voz)  
**Heading:** "Corro com você"

**Parágrafo:**
> "Vou te guiar por voz em tempo real. Aviso quando acelerar, quando frear, quando respirar fundo. Você só precisa correr — eu cuido dos números."

**Bullet cards (4 itens):**
1. "Alertas de pace quando sair da zona alvo"
2. "Comentários a cada km sobre seu desempenho"
3. "Motivação nos últimos quilômetros mais difíceis"
4. "Volume da música abaixa automaticamente quando falo"

**Layout do conteúdo:**
- Padding: pt 73.871, pb 105.869, px 24
- Container: 345.549 × 517.833 px
- Bullets em top 227.84

---

## Slide 3/4 — "Primeira corrida" (nó 1:5870)

**Label:** `// PRIMEIRA CORRIDA`  
**Ícone:** 36 px (gráfico/analytics)  
**Heading:** "Essa é a calibração"

**Parágrafo:**
> "Na primeira corrida, vou te avaliar. Corra no seu ritmo natural — sem pressão. Preciso entender seu corpo para criar o plano perfeito."

**Bullet cards (4 itens, alturas mistas):**
1. "Vou medir seu pace natural em diferentes intensidades" (66.498 px)
2. "Identifico suas zonas cardíacas reais" (46.989 px — 1 linha)
3. "Calibro a progressão semanal pro seu nível" (66.498 px)
4. "Após essa corrida, refino todo o plano automaticamente" (66.498 px)

**Layout do conteúdo:**
- Padding: pt 83.612, pb 115.636, px 24
- Container: 345.549 × 498.325 px

---

## Slide 4/4 — "Seu plano" (nó 1:5922)

**Label:** `// SEU PLANO`  
**Ícone:** 36 px (calendário)  
**Heading:** "Planejamento inteligente"

**Parágrafo:**
> "Trabalho com ciclos mensais e ajustes semanais. Você pode pedir revisão do plano quando precisar — eu reorganizo tudo mantendo o foco no seu objetivo."

**Bullet cards (4 itens):**
1. "Periodização mensal com mesociclos de 4 semanas"
2. "Ajuste semanal baseado em como você está respondendo"
3. "Se não puder correr num dia, reequilibro a semana"
4. "1 revisão de plano por semana disponível"

**CTA diferente:** `[ VAMOS CORRER ] ↗` (não "CONTINUAR ↗")  
**Dots:** 3 visitados + 1 ativo (último)

**Layout do conteúdo:**
- Padding: pt 64.566, pb 96.59, px 24

---

## Componentes identificados

| Componente            | Reutilizável | Descrição |
|-----------------------|:------------:|-----------|
| `CoachIntroBreadcrumb`| Sim          | `[■] COACH.AI > BRIEFING INICIAL` + PULAR à direita |
| `CoachSlideProgressBar`| Sim         | Track 2px + fill ciano animado (25%/50%/75%/100%) |
| `CoachSlideLabel`     | Sim          | "// SECTION_NAME" — 12px Regular ciano tracking 2.4px |
| `CoachSlideHeading`   | Sim          | Ícone 36px + Bold 26px −0.78px tracking |
| `CoachFeatureBulletCard`| Sim        | "▸" ciano + texto 13px, altura auto (1 ou 2 linhas) |
| `CoachSlideCTA`       | Sim          | Fullwidth cyan button, label configurável |
| `CoachPageDots`       | Sim          | 4 dots com estados ativo/visitado/inativo |
| `CoachIntroPage`      | Não          | Monta tudo acima com conteúdo por slide |

---

## Comportamento / UX

- **Navegação:** CONTINUAR avança slide; PULAR vai direto para pré-corrida
- **Não tem VOLTAR** — usuário pode apenas avançar ou pular
- **Dot animation:** ativa → pill largo ciano, visitada → dim, futura → muito dim
- **Dot laranja pulsante:** opacidade oscila por slide (83%/62%/70%/36%) — implementar como pulso animado
- **CTA final:** "[ VAMOS CORRER ] ↗" leva para `pre_corrida` (fluxo de aquecimento)

---

## Lacunas / Decisões pendentes

1. **PULAR:** destino ao pular — vai direto para `pre_corrida` ou para a home?
2. **Persistência:** o briefing é exibido sempre antes da primeira corrida ou apenas uma vez?
3. **Ícones:** brain/microfone/gráfico/calendário — usar Material Icons ou assets customizados?
4. **Animação do dot laranja:** oscila de forma contínua ou dispara ao entrar no slide?
