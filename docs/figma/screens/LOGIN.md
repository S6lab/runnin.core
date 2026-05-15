# Tela: LOGIN

> Extraído via Figma MCP — Fonte canônica: nó `1:4510`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> URL: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-4510

---

## Visão geral

Tela de autenticação do Runnin.AI. Apresenta dois campos de entrada (telefone + OTP) e a opção de login social via Google. Posição 4/13 no fluxo de onboarding — vem logo após os 3 slides de apresentação da feature.

**Dimensões do frame:** 393 × 851 px  
**Jornada:** Onboarding → Login (posição 4/13)  
**Slide ID no design:** `// LOGIN`  
**Número na barra de progresso:** posição 4/13

---

## Hierarquia de nós

```
login (1:4510) — frame raiz
└── Onboarding (1:4511)
    ├── Container (1:4512) — barra de progresso topo (~121 px ciano = 4/13)
    ├── Container (1:4514) — cabeçalho, h=72.5 px
    │   ├── Container (1:4515) — botão VOLTAR
    │   └── Container (1:4521) — logo RUNNIN .AI (sem PULAR — diferente dos slides onboarding)
    ├── Container (1:4526) — área de conteúdo principal
    │   └── Container (1:4527) — bloco de formulário, 345.5 × 336.4 px
    │       ├── Paragraph (1:4528) — label "// LOGIN"
    │       ├── Heading 1 (1:4530) — "Entre na corrida"
    │       ├── Label (1:4532) — "TELEFONE"
    │       ├── Text Input (1:4534) — campo telefone
    │       ├── Label (1:4536) — "CÓDIGO OTP"
    │       ├── Text Input (1:4538) — campo OTP (6 dígitos)
    │       └── Button (1:4540) — "Google Sign-In"
    └── Container (1:4547) — rodapé: botão PRÓXIMO + 13 dots
        ├── Button (1:4548) — "PRÓXIMO ↗" (ciano)
        └── Container (1:4551) — 13 dots (3 visitados, 1 ativo, 9 inativos)
```

---

## Diferença crítica no header vs slides de onboarding

O header desta tela **não tem botão PULAR** — apenas VOLTAR à esquerda e o logo à direita. No onboarding (slides 1-3), o header tinha RUNNIN.AI + PULAR à direita. A tela de login elimina o PULAR.

| Elemento       | Slides Onboarding (1-3) | Login               |
|----------------|-------------------------|---------------------|
| Lado esquerdo  | vazio (slide 1) / VOLTAR (slides 2-3) | VOLTAR |
| Lado direito   | RUNNIN.AI + PULAR       | RUNNIN.AI (apenas)  |
| Altura header  | 53px (slide 1) / 72.5px | 72.5 px             |

---

## CTA: "PRÓXIMO ↗" (não "CONTINUAR")

A partir da tela de LOGIN, o botão CTA muda de label:
- Onboarding slides 01-03: **"CONTINUAR ↗"**
- Login + Assessment 01-08: **"PRÓXIMO ↗"**
- Assessment 09 (último): **"CRIAR MEU PLANO ↗"**

Isso é uma decisão de produto — o CTA pode ser o mesmo componente com label configurável.

---

## Tokens de cor

> Tokens base idênticos ao onboarding. Novos tokens específicos desta tela:

| Token (proposto)           | Hex / RGBA                       | Uso                                    |
|----------------------------|----------------------------------|----------------------------------------|
| `color/input/bg`           | `rgba(255, 255, 255, 0.03)`      | Background dos campos de texto         |
| `color/input/border`       | `rgba(255, 255, 255, 0.08)`      | Borda dos campos de texto              |
| `color/input/placeholder`  | `rgba(255, 255, 255, 0.50)`      | Texto placeholder nos campos           |
| `color/btn/google/bg`      | `rgba(255, 255, 255, 0.05)`      | Background do botão Google Sign-In     |

---

## Tipografia

### Label do slide — "// LOGIN" (nó 1:4529)

| Propriedade    | Valor                                  |
|----------------|----------------------------------------|
| Fonte          | JetBrains Mono Regular                 |
| Tamanho        | 12 px                                  |
| Line-height    | 18 px                                  |
| Letter-spacing | **2.4 px** (maior que nos slides — tracking diferente) |
| Cor            | `#00D4FF`                              |

> Nota: o label de seção do login usa tracking 2.4px vs 1.8px nos slides de onboarding e 1.95px nos assessments.

### Título — "Entre na corrida" (nó 1:4531)

| Propriedade    | Valor              |
|----------------|--------------------|
| Fonte          | JetBrains Mono Bold |
| Tamanho        | 28 px              |
| Line-height    | 28 px              |
| Letter-spacing | −0.84 px           |
| Cor            | `#FFFFFF`          |

### Labels dos campos (ex: nó 1:4533 "TELEFONE")

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono Medium           |
| Tamanho        | 11 px                           |
| Line-height    | 16.5 px                         |
| Letter-spacing | 1.65 px                         |
| Cor            | `rgba(255, 255, 255, 0.55)`     |
| Casing         | ALL CAPS                        |

### Placeholder dos campos (ex: nó 1:4535)

| Campo          | Placeholder                   | Fonte               | Tamanho | Tracking |
|----------------|-------------------------------|---------------------|---------|----------|
| TELEFONE       | "+55 (11) 99999-9999"         | JetBrains Mono Reg  | 14 px   | 0        |
| CÓDIGO OTP     | "_ _ _ _ _ _"                 | JetBrains Mono Reg  | 14 px   | **4.2 px** (tracking especial para separar os dígitos) |

### Botão Google Sign-In (nó 1:4546)

| Propriedade    | Valor                           |
|----------------|---------------------------------|
| Fonte          | JetBrains Mono Medium           |
| Tamanho        | 12 px                           |
| Line-height    | 18 px                           |
| Letter-spacing | 0                               |
| Cor            | `#FFFFFF`                       |
| Casing         | Title case ("Google Sign-In")   |

---

## Layout e espaçamento

### Barra de progresso topo (nó 1:4512)

- Cyan fill: ≈ 121.08 px (393.5 − 272.5) → posição 4/13

### Cabeçalho (nó 1:4514)

- **Altura:** 72.5 px
- **Padding:** 24 px H × 16 px V
- **Lado esquerdo:** botão VOLTAR (idêntico ao onboarding)
- **Lado direito:** logo RUNNIN.AI **sem** botão PULAR

### Área de conteúdo principal (nó 1:4526)

- **Padding:** top 153.3 px, bottom 185.4 px, horizontal 24 px
- Muito mais espaço vertical que os slides — o formulário é menor e fica centralizado

### Bloco de formulário (nó 1:4527) — 345.5 × 336.4 px

| Elemento                    | Top offset |
|-----------------------------|------------|
| Label "// LOGIN"            | 0 px       |
| Heading "Entre na corrida"  | 30 px      |
| Label "TELEFONE"            | 95.2 px    |
| Campo TELEFONE              | 122 px     |
| Label "CÓDIGO OTP"          | 191.7 px   |
| Campo CÓDIGO OTP            | 218.4 px   |
| Botão Google Sign-In        | 290.9 px   |

### Campos de texto (nó 1:4534, 1:4538)

| Propriedade     | Valor                              |
|-----------------|------------------------------------|
| Largura         | 345.5 px (fullwidth)               |
| Altura          | 48.5 px                            |
| Background      | `rgba(255, 255, 255, 0.03)`        |
| Borda           | 1.741 px `rgba(255, 255, 255, 0.08)` |
| Padding         | 16 px H × 12 px V                  |
| Overflow        | clip (hidden)                      |

### Botão Google Sign-In (nó 1:4540)

| Propriedade     | Valor                              |
|-----------------|------------------------------------|
| Tamanho         | 345.5 × 45.5 px                    |
| Background      | `rgba(255, 255, 255, 0.05)`        |
| Borda           | 1.741 px `rgba(255, 255, 255, 0.08)` |
| Ícone           | Google logo 16×16 px, posição left |
| Texto           | "Google Sign-In" centralizado      |
| Gap ícone-texto | ~16 px implícito                   |

### Rodapé (nó 1:4547) — Progress indicator

- 3 dots visitados (rgba 0.20) + 1 ativo (ciano) + 9 inativos (rgba 0.06)
- Confirma que LOGIN é o passo 4/13

---

## Componentes identificados

| Componente                  | Tipo       | Reutilizável | Descrição                                              |
|-----------------------------|------------|:------------:|--------------------------------------------------------|
| `FormFieldLabel`            | Widget base | Sim         | Label ALL CAPS 11px com tracking 1.65px                |
| `FormTextField`             | Widget      | Sim         | Campo de texto com borda sutil, placeholder muted      |
| `OtpTextField`              | Widget      | Sim         | Variante do campo com tracking 4.2px para dígitos      |
| `GoogleSignInButton`        | Widget      | Sim         | Botão outline escuro com ícone Google + label          |
| `OnboardingNextButton`      | Widget      | Sim         | CTA "PRÓXIMO ↗" (variante do ContinueButton)           |

---

## Comportamento / UX

- **Objetivo:** autenticar o usuário via telefone (OTP) ou Google
- **Fluxo de telefone:** usuário digita telefone → recebe SMS → digita OTP de 6 dígitos → PRÓXIMO
- **Fluxo Google:** usuário toca "Google Sign-In" → OAuth
- **Navegação:** VOLTAR → slide 03 do onboarding; PRÓXIMO (após auth) → ASSESSMENT_01
- **Validação:** nenhuma validação visual definida no design (campos vazios, OTP inválido, etc.)
- **Estado de erro:** não previsto no design
- **Estado de carregamento (request OTP):** não previsto no design

---

## Screenshot de referência

> Tela confirma: header com VOLTAR + RUNNIN.AI (sem PULAR), label "// LOGIN", título "Entre na corrida", campo TELEFONE + campo OTP (6 dashes com tracking especial), botão Google Sign-In, CTA "PRÓXIMO ↗", 4 dots (3 visitados + 1 ativo + 9 inativos).

---

## Tarefas Flutter

| ID     | Descrição                                                         | Depende de               |
|--------|-------------------------------------------------------------------|--------------------------|
| T-LG01 | Criar `FormFieldLabel` (11px Medium tracking 1.65px ALL CAPS)     | AppColors, AppTypography |
| T-LG02 | Criar `FormTextField` (campo genérico com borda sutil)            | AppColors                |
| T-LG03 | Criar `OtpTextField` (tracking 4.2px, 6 dígitos)                  | T-LG02                   |
| T-LG04 | Criar `GoogleSignInButton` (outline, ícone Google, texto branco)  | AppColors, AppTypography |
| T-LG05 | Montar `LoginPage` com todos os componentes                       | T-LG01–T-LG04            |
| T-LG06 | Implementar lógica: requisição OTP por SMS                        | Decisão de infra/SMS     |
| T-LG07 | Implementar lógica: Google OAuth                                  | google_sign_in package   |

---

## Lacunas / Decisões pendentes

1. **Fluxo OTP:** após digitar o telefone e pressionar PRÓXIMO, o campo OTP aparece? Ou são passos separados?
2. **Google Sign-In:** usa `google_sign_in` package ou outra lib? O botão segue as diretrizes de branding do Google?
3. **Validação:** estados de erro para telefone inválido, OTP errado, timeout?
4. **Header sem PULAR:** confirmado — LOGIN não tem PULAR. Se o usuário quiser sair sem logar, só VOLTAR.
5. **Estado de "enviando OTP":** feedback visual de carregamento não está no design.
