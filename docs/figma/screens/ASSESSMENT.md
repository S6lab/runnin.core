# Telas: ASSESSMENT 01–09

> Extraído via Figma MCP — 9 telas de assessment  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> nodeIds: `1:4566` · `1:4616` · `1:4666` · `1:4724` · `1:4809` · `1:4863` · `1:4924` · `1:4980` · `1:5078`

---

## Visão geral

O fluxo de assessment ocorre logo após o login e coleta todas as informações necessárias para o Coach.AI personalizar o plano de treinamento. São 9 telas (posições 5–13/13 no indicador de progresso), todas com o mesmo padrão estrutural, mas com tipos de input distintos por tela.

**Total de telas de assessment:** 9  
**Posições no fluxo:** 5/13 a 13/13  
**CTA geral:** "PRÓXIMO ↗" (exceto última: "CRIAR MEU PLANO ↗")  
**Jornada:** Login → Assessment 01 → ... → Assessment 09 → (geração do plano)

---

## Mapa do fluxo completo de onboarding (13 passos)

| Posição | Tela               | Tipo de input           | nodeId   |
|---------|--------------------|-------------------------|----------|
| 1/13    | Onboarding 01      | Informativo (cards)     | 1:4295   |
| 2/13    | Onboarding 02      | Informativo (cards)     | 1:4364   |
| 3/13    | Onboarding 03      | Informativo (cards)     | 1:4437   |
| 4/13    | Login              | Formulário + OAuth      | 1:4510   |
| **5/13**| **Assessment 01**  | **Radio (3 opções)**    | **1:4566**|
| **6/13**| **Assessment 02**  | **Formulário (texto + data)** | **1:4616**|
| **7/13**| **Assessment 03**  | **Numérico (2 campos)** | **1:4666**|
| **8/13**| **Assessment 04**  | **Multi-select chips**  | **1:4724**|
| **9/13**| **Assessment 05**  | **Radio (5 opções)**    | **1:4809**|
| **10/13**|**Assessment 06** | **Radio (8 opções)**    | **1:4863**|
| **11/13**|**Assessment 07** | **Radio (6 opções)**    | **1:4924**|
| **12/13**|**Assessment 08** | **Período + Horário**   | **1:4980**|
| **13/13**|**Assessment 09** | **Binary + Info blocks**| **1:5078**|

---

## Padrões compartilhados (todos os 9 assessments)

### Estrutura da tela

Todos os assessments compartilham a mesma estrutura:

```
[tela] — 393 × 851 px (alguns são scrolláveis)
├── Barra de progresso topo (2px, cyan proporcional)
├── Cabeçalho (72.5px) — VOLTAR + RUNNIN.AI (sem PULAR)
├── Área de conteúdo (flex-grow, centralizada)
│   └── [label // ASSESSMENT_XX] + [título H2] + [descrição] + [inputs]
└── Rodapé (102px) — "PRÓXIMO ↗" + 13 dots
```

### Tipografia dos assessments (diferente dos slides de onboarding)

| Elemento              | Fonte                  | Peso    | Tamanho | LH     | Tracking |
|-----------------------|------------------------|---------|---------|--------|----------|
| Label `// ASSESSMENT` | JetBrains Mono Regular | 400     | 13 px   | 19.5px | 1.95 px  |
| Heading (H2)          | JetBrains Mono Bold    | 700     | 24 px   | 26.4px | −0.48 px |
| Descrição             | JetBrains Mono Regular | 400     | 13 px   | 20.8px | 0        |
| Opções de seleção     | JetBrains Mono Medium  | 500     | 14 px   | 21px   | 0        |

> Assessment usa **24px H2** (não 28px do heading dos slides de onboarding). Tracking do H2 é −0.48px (não −0.84px).

### Tokens de cor dos assessments

| Token                   | Hex / RGBA                       | Uso                              |
|-------------------------|----------------------------------|----------------------------------|
| `color/assessment/label`| `#00D4FF`                        | Label "// ASSESSMENT_XX"         |
| `color/option/text`     | `rgba(255, 255, 255, 0.70)`      | Texto das opções de seleção      |
| `color/option/bg`       | `rgba(255, 255, 255, 0.03)`      | Background das opções            |
| `color/option/border`   | `rgba(255, 255, 255, 0.08)`      | Borda das opções                 |
| `color/coach/orange`    | `#FF6B35`                        | Bloco COACH.AI (borda e label)   |
| `color/coach/orange/bg` | `rgba(255, 107, 53, 0.03)`       | Background bloco COACH.AI        |
| `color/info/cyan/bg`    | `rgba(0, 212, 255, 0.03)`        | Background bloco informativo ciano |
| `color/info/cyan/border`| `rgba(0, 212, 255, 0.14)`        | Borda bloco informativo ciano    |
| `color/hint/text`       | `rgba(255, 255, 255, 0.25)`      | Texto de dica/hint (ex: "pode pular...") |

### Botão de opção (selector) — padrão

| Propriedade     | Valor                              |
|-----------------|------------------------------------|
| Largura         | 345.5 px (fullwidth)               |
| Altura          | 56.5 px                            |
| Background      | `rgba(255, 255, 255, 0.03)`        |
| Borda           | 1.741 px `rgba(255, 255, 255, 0.08)` |
| Padding         | 21.74 px H × 17.74 px V            |
| Layout          | row, justify-between, items-center |
| Texto           | Medium 14px, rgba(255,255,255,0.70) |

### Estado selecionado do botão de opção

**Não definido no design** — nenhuma variante de estado "selected/active" foi fornecida. Requer decisão de produto.

---

## ASSESSMENT_01 — Qual seu nível atual?

**nodeId:** `1:4566` | **Posição:** 5/13

### Conteúdo

- **Label:** `// ASSESSMENT_01`
- **Título:** "Qual seu nível atual?"
- **Descrição:** "O Coach adapta intensidade, volume e progressão ao seu nível."
- **Tipo de input:** radio (seleção única)

### Opções

| Opção | Texto                                   |
|-------|-----------------------------------------|
| A     | Iniciante — nunca corri ou voltando     |
| B     | Intermediário — corro regularmente      |
| C     | Avançado — treino estruturado           |

### Layout de conteúdo

- Container de opções: top offset 139.5 px
- 3 botões em coluna, gap = 8 px

---

## ASSESSMENT_02 — Como te chamo?

**nodeId:** `1:4616` | **Posição:** 6/13

### Conteúdo

- **Label:** `// ASSESSMENT_02`
- **Título:** "Como te chamo?"
- **Descrição:** "Nome e data de nascimento — o Coach usa para personalizar comunicação e calcular zonas cardíacas com precisão."
- **Tipo de input:** formulário (texto + seletor de data)

### Campos

| Campo                 | Tipo         | Placeholder    | Tamanho fonte | Variante            |
|-----------------------|--------------|----------------|---------------|---------------------|
| SEU NOME              | TextField    | "Ex: Lucas"    | **16 px**     | Entrada de texto    |
| DATA DE NASCIMENTO    | DatePicker   | vazio          | —             | Componente nativo?  |

### Especificações dos campos

**Campo SEU NOME (nó 1:4642):**
- Tamanho: 345.5 × 51.5 px (maior que campo de login)
- Placeholder: "Ex: Lucas" — Regular **16px** (maior que os outros campos)
- Borda: 1.741px rgba(255,255,255,0.08)

**Campo DATA DE NASCIMENTO (nó 1:4646 — "Date Picker"):**
- Tamanho: 345.5 × 51.5 px
- Aparece como caixa vazia — sem conteúdo visível
- Identificado como "Date Picker" no Figma — requer componente nativo ou customizado

### Layout de conteúdo

| Elemento              | Top offset |
|-----------------------|------------|
| Label "// ASSESSMENT" | 0 px       |
| Título                | 31.5 px    |
| Descrição             | 65.9 px    |
| Label "SEU NOME"      | 165.5 px   |
| Campo nome            | 192.3 px   |
| Label "DATA DE NASC." | 269 px     |
| Campo data            | 295.7 px   |

---

## ASSESSMENT_03 — Peso e altura

**nodeId:** `1:4666` | **Posição:** 7/13

### Conteúdo

- **Label:** `// ASSESSMENT_03`
- **Título:** "Peso e altura"
- **Descrição:** "Usamos para calcular gasto calórico, zonas cardíacas e carga de impacto nas articulações."
- **Tipo de input:** numérico de 2 colunas (peso + altura)

### Layout dos campos numéricos

Dois campos lado a lado com gap de 16 px:

| Campo         | Largura    | Placeholder | Font Placeholder |
|---------------|------------|-------------|------------------|
| PESO (KG)     | 164.8 px   | "70"        | Bold **28 px**   |
| ALTURA (CM)   | 164.8 px   | "175"       | Bold **28 px**   |

**Cada campo numérico:**
- Container total: 164.8 × 133.9 px
- Label (ex: "PESO (KG)"): 11px Medium, tracking 1.65px, top offset 5.2px
- Input box: 164.8 × 77.5 px, padding 16px, text centrado
- Unidade (ex: "kg"): 11px Regular, rgba(255,255,255,0.55), centralizado, abaixo do campo

> **Destaque:** o placeholder usa Bold 28px — é a única tela onde o texto do input field usa tamanho de heading (28px Bold). Representa o valor padrão/sugerido de forma visual, como em um number picker.

---

## ASSESSMENT_04 — Informações de saúde

**nodeId:** `1:4724` | **Posição:** 8/13 | **Tela scrollável** (frame 1111px)

### Conteúdo

- **Label:** `// ASSESSMENT_04`
- **Título:** "Informações de saúde"
- **Descrição:** "Opcional, mas importante. Selecione condições relevantes para que o Coach ajuste intensidade, alertas e limites de segurança."
- **Tipo de input:** multi-select chips (seleção múltipla)

### Bloco COACH.AI (primeiro aparecimento)

Este design introduz um novo componente de "fala" do Coach.AI:

| Propriedade        | Valor                                  |
|--------------------|----------------------------------------|
| Background         | `rgba(255, 107, 53, 0.03)`             |
| Borda esquerda     | 1.741 px `#FF6B35` (border-left only)  |
| Label "COACH.AI"   | Regular 11px, `#FF6B35`, tracking 1.1px |
| Texto              | Regular 13px, `rgba(255,255,255,0.70)`, line-height 21.45px |
| Padding            | pl=17.74px, pr=16px, pt=16px           |
| Tamanho            | 319.4 × 202.6 px                       |

**Mensagem:** "Vou avaliar todas as suas informações para montar um programa de treino seguro e personalizado. Se você toma medicação que altera frequência cardíaca, por exemplo, ajusto as zonas de BPM automaticamente."

### Chips de condições de saúde

Layout em grid irregular (chips de largura variável, em linhas):

| Linha | Chips |
|-------|-------|
| 1     | Hipertensão · Diabetes tipo 2 · Asma |
| 2     | Histórico de AVC · Problemas cardíacos |
| 3     | Lesão no joelho · Lesão no tornozelo |
| 4     | Hérnia de disco · Toma anticoagulante |
| 5     | Toma betabloqueador · Toma insulina |
| 6     | Artrose · Fibromialgia |
| 7     | Ansiedade/depressão |
| 8     | Cirurgia recente (<6m) |

**Especificação dos chips:**
- Altura: 41.4 px
- Background: `rgba(255, 255, 255, 0.03)`
- Borda: 1.741 px `rgba(255, 255, 255, 0.08)` solid
- Texto: Medium 12px, `rgba(255,255,255,0.55)`, centralizado
- Largura: variável (baseada no texto)
- Gap horizontal entre chips: não uniforme (posicionamento absoluto)

**Botão "+ Adicionar outra condição ou medicação":**
- Borda: **dashed** 1.741 px `rgba(255,255,255,0.08)`
- Tamanho: 319.4 × 54.5 px
- Ícone: "+" em `#00D4FF`, 18px Medium
- Texto: Medium 13px, `rgba(255,255,255,0.55)`

**Nota de skip:**
- Texto: "Pode pular se preferir. Você pode adicionar depois no Perfil."
- Regular 11px, `rgba(255,255,255,0.25)`, line-height 16.5px

---

## ASSESSMENT_05 — Quantas vezes por semana?

**nodeId:** `1:4809` | **Posição:** 9/13

### Conteúdo

- **Label:** `// ASSESSMENT_05`
- **Título:** "Quantas vezes por semana?"
- **Descrição:** "O Coach distribui sessões com descanso adequado entre cada corrida."
- **Tipo de input:** radio (seleção única)

### Opções

| Opção | Texto |
|-------|-------|
| A     | 2x    |
| B     | 3x    |
| C     | 4x    |
| D     | 5x    |
| E     | 6x+   |

---

## ASSESSMENT_06 — Qual sua meta principal?

**nodeId:** `1:4863` | **Posição:** 10/13 | **Tela scrollável** (frame 882px)

### Conteúdo

- **Label:** `// ASSESSMENT_06`
- **Título:** "Qual sua meta principal?"
- **Descrição:** "O Coach monta periodização, volume e progressão com base no seu objetivo."
- **Tipo de input:** radio (seleção única)

### Opções

| Opção | Texto               |
|-------|---------------------|
| A     | Saúde e bem-estar   |
| B     | Perder peso         |
| C     | Completar 5K        |
| D     | Completar 10K       |
| E     | Meia maratona (21K) |
| F     | Maratona (42K)      |
| G     | Ultramaratona       |
| H     | Triathlon           |

> 8 opções = tela com mais radio options do fluxo. Requer scroll.

---

## ASSESSMENT_07 — Você tem um pace alvo?

**nodeId:** `1:4924` | **Posição:** 11/13

### Conteúdo

- **Label:** `// ASSESSMENT_07`
- **Título:** "Você tem um pace alvo?"
- **Descrição:** "Não se preocupe se não sabe — o Coach avalia na primeira corrida e calibra tudo automaticamente."
- **Tipo de input:** radio (seleção única)

### Opções

| Opção | Texto                    |
|-------|--------------------------|
| A     | Não sei o que é pace     |
| B     | Acima de 7:00/km         |
| C     | Entre 6:00 e 7:00/km     |
| D     | Entre 5:00 e 6:00/km     |
| E     | Abaixo de 5:00/km        |
| F     | Deixa o Coach decidir    |

---

## ASSESSMENT_08 — Rotina e horário

**nodeId:** `1:4980` | **Posição:** 12/13

### Conteúdo

- **Label:** `// ASSESSMENT_08`
- **Título:** "Rotina e horário"
- **Descrição:** "O Coach usa seu horário para calcular janela metabólica ideal, lembretes de hidratação, preparo nutricional e sugestão de melhor hora para correr."
- **Tipo de input:** seleção de período + seleção de horário (2 subseções)

### Subseção: "QUANDO PREFERE CORRER?" — 3 cards horizontais

| Propriedade           | Valor                            |
|-----------------------|----------------------------------|
| Tamanho de cada card  | 109.8 × 138.5 px                 |
| Background            | `rgba(255, 255, 255, 0.03)`      |
| Borda                 | 1.741 px `rgba(255,255,255,0.08)`|
| Gap entre cards       | 8 px (implícito)                 |

Conteúdo de cada card (de cima para baixo):
- **Ícone:** 22×22 px (MuiSvgIcon ciano), top 12px
- **Label:** Bold 13px, `rgba(255,255,255,0.55)`, centralizado
- **Horário:** Medium 10px, `rgba(255,255,255,0.55)`, centralizado
- **Dica:** Medium 9px, `rgba(255,255,255,0.25)`, centralizado (multi-linha)

| Card    | Label  | Horário | Dica                           |
|---------|--------|---------|--------------------------------|
| Manhã   | Manhã  | 06-09h  | Cortisol alto, queima de gordura |
| Tarde   | Tarde  | 14-17h  | Pico de temperatura corporal   |
| Noite   | Noite  | 19-21h  | Força muscular elevada         |

### Subseção: "ACORDA" e "DORME" — 2 colunas

Duas colunas de 4 opções de horário cada:

| Coluna  | Opções                      |
|---------|-----------------------------|
| ACORDA  | 05:00 / 06:00 / 07:00 / 08:00 |
| DORME   | 21:00 / 22:00 / 23:00 / 00:00 |

**Especificação de cada opção de horário:**
- Tamanho: 166.8 × 44.5 px
- Background: `rgba(255, 255, 255, 0.03)`
- Borda: 1.741 px `rgba(255,255,255,0.08)`
- Texto: Regular 14px, `rgba(255,255,255,0.55)`, centralizado
- Gap entre botões: 4 px

**Labels das subseções:**
- "QUANDO PREFERE CORRER?": Regular 11px, `#00D4FF`, tracking 1.65px
- "ACORDA" / "DORME": Regular 11px, `rgba(255,255,255,0.55)`, tracking 1.65px

---

## ASSESSMENT_09 — Conectar wearable?

**nodeId:** `1:5078` | **Posição:** 13/13 | **Tela scrollável** (frame 1026px) | **ÚLTIMO ASSESSMENT**

### Conteúdo

- **Label:** `// ASSESSMENT_09`
- **Título:** "Conectar wearable?"
- **Descrição:** "Dados de BPM, sono e atividade permitem que o Coach personalize com mais precisão."
- **Tipo de input:** binary (2 opções) + 2 blocos informativos

### Opções binárias

| Opção | Texto              |
|-------|--------------------|
| A     | Sim (recomendado)  |
| B     | Depois             |

### Bloco COACH.AI (variante assessment_09)

Estrutura ligeiramente diferente do assessment_04:

| Propriedade           | Valor                                |
|-----------------------|--------------------------------------|
| Background            | `rgba(255, 107, 53, 0.02)` (mais claro que assessment_04) |
| Borda esquerda        | `#FF6B35` 1.741 px                   |
| Header do bloco       | Quadrado laranja (8×8px, opacity 50%) + "> COACH.AI" |
| Label "> COACH.AI"    | Regular 11px, `#FF6B35`, tracking 1.65px |
| Texto                 | Regular **14px**, `rgba(255,255,255,0.80)`, line-height 23.1px |
| Padding               | pl=21.74px, pr=20px, pt=20px, gap 12px |

**Mensagem:** "Tenho tudo que preciso — incluindo sua rotina de sono e horário preferido. Vou calcular a janela metabólica ideal para cada tipo de treino, enviar lembretes de hidratação e preparo nutricional, e sugerir o melhor horário com base no seu padrão de sono."

### Bloco informativo ciano (novo componente)

| Propriedade           | Valor                                |
|-----------------------|--------------------------------------|
| Background            | `rgba(0, 212, 255, 0.03)`            |
| Borda                 | 1.741 px `rgba(0, 212, 255, 0.14)`   |
| Padding               | 17.74 px H × 17.74 px V              |
| Layout                | row, gap 12px, items-start           |
| Ícone                 | MuiSvgIcon **24×24 px** ciano        |
| Título                | Bold 13px, `#FFFFFF`                 |
| Corpo                 | Regular 12px, `rgba(255,255,255,0.55)`, lh 19.2px |
| Link inline           | Bold 12px, `#00D4FF` ("Perfil → Saúde → Exames") |

**Título:** "Tem exames médicos recentes?"  
**Corpo:** "Testes ergométricos, exames de sangue e laudos médicos permitem que eu calibre zonas cardíacas com FC máx real, monitore ferritina e identifique restrições. Após criar seu plano, acesse **Perfil → Saúde → Exames** para enviar até 5 arquivos por mês (PDF ou foto, máx 10MB)."

### CTA final — "CRIAR MEU PLANO ↗"

| Propriedade    | Valor             |
|----------------|-------------------|
| Background     | `#00D4FF`         |
| Texto          | "CRIAR MEU PLANO ↗" |
| Fonte          | Bold 12px, tracking 1.2px |
| Cor texto      | `#050510`         |

### Indicador de progresso (último passo)

**Todos os 13 dots são "visitados" (rgba 0.20) exceto o último que é ciano ativo.**  
12 dots visitados + 1 ativo (ciano) = posição 13/13.

---

## Componentes novos identificados

| Componente                  | Tipo       | Aparece em        | Descrição                                              |
|-----------------------------|------------|:-----------------:|--------------------------------------------------------|
| `AssessmentSlideLabel`      | Widget base | Todos            | "// ASSESSMENT_XX" — 13px tracking 1.95px (vs 12px login) |
| `AssessmentHeading`         | Widget base | Todos            | H2 Bold 24px tracking −0.48px (menor que onboarding H1) |
| `AssessmentDescription`     | Widget base | Todos            | Regular 13px, rgba(255,255,255,0.55), lh 20.8px       |
| `SelectionButton`           | Widget      | 01,05,06,07,09   | Radio option: 345.5×56.5px, fullwidth, border sutil    |
| `HealthChip`                | Widget      | 04               | Chip multi-select largura variável, 41.4px altura      |
| `AddConditionButton`        | Widget      | 04               | Botão dashed outline, "+" ciano + texto muted          |
| `CoachAIBlock`              | Widget      | 04, 09           | Bloco fala do Coach com borda laranja left             |
| `CyanInfoBlock`             | Widget      | 09               | Card ciano bg translúcido com ícone + título + corpo   |
| `TimePeriodCard`            | Widget      | 08               | Card 3-col (ícone + label + horário + dica), 109.8×138.5px |
| `TimeOptionButton`          | Widget      | 08               | Botão horário 166.8×44.5px, texto centrado Regular 14px |
| `NumericInputField`         | Widget      | 03               | Campo numérico: placeholder Bold 28px + unidade abaixo |
| `DatePickerField`           | Widget      | 02               | Campo data — aparece vazio no design                   |

---

## Telas scrolláveis

| Tela          | Frame height | Viewport | Overflow |
|---------------|-------------|----------|----------|
| Assessment 04 | 1111 px     | 851 px   | Scroll   |
| Assessment 06 | 882 px      | 851 px   | Scroll   |
| Assessment 09 | 1026 px     | 851 px   | Scroll   |

---

## Tarefas Flutter

| ID     | Descrição                                                          | Depende de          |
|--------|--------------------------------------------------------------------|---------------------|
| T-AS01 | Criar `AssessmentSlideLabel` + `AssessmentHeading` + `AssessmentDescription` | AppColors, AppTypography |
| T-AS02 | Criar `SelectionButton` (radio option, 56.5px, fullwidth)          | AppColors            |
| T-AS03 | Criar `AssessmentPage` template (label + título + descrição + conteúdo + rodapé) | T-AS01   |
| T-AS04 | Montar `Assessment01Page` (nível: 3 opções)                        | T-AS02, T-AS03       |
| T-AS05 | Montar `Assessment02Page` (nome + datepicker)                      | FormTextField, T-LG01 |
| T-AS06 | Montar `Assessment03Page` (peso + altura, NumericInputField)        | T-AS03               |
| T-AS07 | Criar `HealthChip` + `AddConditionButton`                          | AppColors            |
| T-AS08 | Criar `CoachAIBlock` (borda laranja left, label + texto)           | AppColors, AppTypography |
| T-AS09 | Montar `Assessment04Page` (chips + CoachAIBlock, scrollável)       | T-AS07, T-AS08       |
| T-AS10 | Montar `Assessment05Page` (5x por semana, 5 opções)               | T-AS02, T-AS03       |
| T-AS11 | Montar `Assessment06Page` (meta, 8 opções, scrollável)            | T-AS02, T-AS03       |
| T-AS12 | Montar `Assessment07Page` (pace alvo, 6 opções)                   | T-AS02, T-AS03       |
| T-AS13 | Criar `TimePeriodCard` (3-col, ícone + label + horário + dica)    | AppColors, AppTypography |
| T-AS14 | Criar `TimeOptionButton` (166.8×44.5px, horário centralizado)     | AppColors            |
| T-AS15 | Montar `Assessment08Page` (período + acorda/dorme)                | T-AS13, T-AS14       |
| T-AS16 | Criar `CyanInfoBlock` (borda ciano, ícone + título + corpo + link) | AppColors, AppTypography |
| T-AS17 | Montar `Assessment09Page` (wearable, CoachAIBlock, CyanInfoBlock, scrollável) | T-AS08, T-AS16 |
| T-AS18 | Implementar lógica de persistência de dados do assessment          | Backend / local state |

---

## Lacunas / Decisões pendentes

1. **Estado selecionado dos botões de opção:** cor/estilo quando uma opção está selecionada — não definido no design
2. **Assessment 02 — DatePicker:** campo aparece vazio — usar `showDatePicker` nativo Flutter? Custom wheel picker?
3. **Assessment 03 — Numérico:** os campos de peso/altura são teclado numérico ou picker de scroll tipo "roda"?
4. **Assessment 04 — Chips:** quais condições ativam alertas específicos no Coach? Requer mapeamento produto→backend
5. **Assessment 04 — "Adicionar outra condição":** abre modal? Campo de texto livre?
6. **Assessment 08 — Seleção múltipla:** o usuário pode selecionar mais de um período para correr?
7. **Assessment 09 — Wearable:** quais wearables são suportados? Apple Watch, Garmin, Polar?
8. **Assessment 09 — "Depois":** o usuário pode conectar o wearable depois via Perfil → Dispositivos?
9. **Destino após "CRIAR MEU PLANO":** uma tela de loading/geração, ou vai direto para o home?
10. **Validação por tela:** todas as telas requerem seleção antes de avançar, ou são opcionais?
