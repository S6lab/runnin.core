# Tela: SPLASH SCREEN

> Extraído via Figma MCP — Fonte canônica: nó `1:4283`  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> URL: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-4283

---

## Visão geral

Tela de splash do app Runnin.AI. Fundo escuro quase preto, logo centralizado verticalmente e horizontalmente, tagline e linha de destaque ciano.

**Dimensões do frame:** 393 × 851 px  
**Jornada:** Abertura do app (pré-autenticação)

---

## Hierarquia de nós

```
SPLASH (1:4283)  — frame raiz, 393 × 851 px
└── Splash (1:4284)  — container fullscreen, centraliza conteúdo
    └── Container (1:4285)  — bloco do logo, 201.59 × 109.95 px, centrado
        ├── Container (1:4286)  — linha "RUNNIN .AI", 148.31 × 41.98 px
        │   ├── Text (1:4287)  — "RUNNIN" wordmark, 100.75 × 41.98 px
        │   │   └── text (1:4288)  — texto "RUNNIN"
        │   └── Text (1:4289)  — badge ".AI", 41.58 × 25.98 px, bg ciano
        │       └── text (1:4290)  — texto ".AI"
        ├── Paragraph (1:4291)  — tagline, 201.59 × 17.98 px, opacity 40%
        │   └── text (1:4292)  — texto "FEITO PARA VENCEDORES"
        └── Container (1:4293)  — linha decorativa ciano, 121.93 × 2 px
```

---

## Tokens de cor

| Token (proposto)       | Hex / RGBA                   | Uso na tela                        |
|------------------------|------------------------------|------------------------------------|
| `color/bg/base`        | `#050510`                    | Fundo da tela inteira              |
| `color/brand/accent`   | `#00D4FF`                    | Badge `.AI` e linha decorativa     |
| `color/text/high`      | `#FFFFFF`                    | Wordmark "RUNNIN"                  |
| `color/text/muted`     | `rgba(255, 255, 255, 0.55)`  | Tagline "FEITO PARA VENCEDORES"    |
| `color/badge/text`     | `#050510`                    | Texto ".AI" sobre badge ciano      |

> Nota: `get_variable_defs` retornou vazio para este nó — tokens ainda não publicados no Figma. Valores acima são extraídos diretamente dos atributos de estilo dos nós.

---

## Tipografia

### Wordmark — "RUNNIN" (nó 1:4288)

| Propriedade    | Valor                             |
|----------------|-----------------------------------|
| Fonte          | JetBrains Mono                    |
| Peso           | Bold (700)                        |
| Tamanho        | 28 px                             |
| Line-height    | 42 px (150%)                      |
| Letter-spacing | 3.36 px (≈ 0.12 em / 12%)         |
| Cor            | `#FFFFFF`                         |
| Casing         | ALL CAPS                          |

### Badge — ".AI" (nó 1:4290)

| Propriedade    | Valor                             |
|----------------|-----------------------------------|
| Fonte          | JetBrains Mono                    |
| Peso           | Bold (700)                        |
| Tamanho        | 12 px                             |
| Line-height    | 18 px (150%)                      |
| Letter-spacing | padrão (0)                        |
| Cor            | `#050510` (dark, sobre bg ciano)  |
| Casing         | `.AI` (ponto + maiúsculas)        |

### Tagline — "FEITO PARA VENCEDORES" (nó 1:4292)

| Propriedade    | Valor                             |
|----------------|-----------------------------------|
| Fonte          | JetBrains Mono                    |
| Peso           | Regular (400)                     |
| Tamanho        | 12 px                             |
| Line-height    | 18 px (150%)                      |
| Letter-spacing | 2.4 px (0.20 em / 20%)            |
| Cor            | `rgba(255, 255, 255, 0.55)`       |
| Container opacity | 40%                            |
| Casing         | ALL CAPS                          |

---

## Layout e espaçamento

### Container principal do logo (nó 1:4285)

- **Posição:** centrado na tela (tanto horizontal quanto vertical)
- **Tamanho:** 201.59 × 109.95 px
- O frame pai (1:4284) usa `padding-top: 370.77 px` e `padding-bottom: 370.80 px` para forçar centralização

### Linha "RUNNIN .AI" (nó 1:4286)

- **Posição dentro de 1:4285:** `left: 26.64 px`, `top: 0`
- **Tamanho:** 148.31 × 41.98 px
- **Layout:** row, gap entre wordmark e badge = `5.99 px`
- **Alinhamento:** items-center

### Badge ".AI" (nó 1:4289)

- **Tamanho:** 41.58 × 25.98 px
- **Background:** `#00D4FF`
- **Padding:** `4 px` vertical × `10 px` horizontal
- **Conteúdo:** centralizado (flex center)

### Tagline (nó 1:4291)

- **Posição dentro de 1:4285:** `left: 0`, `top: 57.98 px`
- **Tamanho:** 201.59 × 17.98 px
- **Opacity:** 40% (no container)

### Linha decorativa ciano (nó 1:4293)

- **Posição dentro de 1:4285:** `left: 36.78 px`, `top: 107.96 px`
- **Tamanho:** 121.93 × 2 px
- **Cor:** `#00D4FF`

---

## Componentes identificados

| Componente           | Tipo          | Reutilizável | Descrição                                               |
|----------------------|---------------|:------------:|---------------------------------------------------------|
| `SplashLogo`         | Widget        | Sim          | Wordmark + badge `.AI` em linha                         |
| `SplashTagline`      | Widget        | Não          | Tagline com opacity e tracking alto                     |
| `BrandAccentLine`    | Widget base   | Sim          | Linha decorativa ciano — pode aparecer em outras telas  |

---

## Comportamento / UX

- **Objetivo:** Exibir a identidade da marca enquanto o app inicializa (carregamento de dados, autenticação, etc.)
- **Navegação:** Após o splash, o app deve navegar para o fluxo de onboarding ou home (dependendo do estado do usuário)
- **Duração:** **indefinido no design** — requer decisão de produto (ex: 2–3 s fixo ou aguardar carregamento)
- **Animação de entrada/saída:** **indefinida no design** — requer decisão de produto
- **Estado de erro:** não existe na tela — sem fallback visual para erros de inicialização
- **Acessibilidade:** logo deve ter `semanticsLabel: "Runnin AI"` ou equivalente; tagline pode ser `ExcludeSemantics`

---

## Screenshot de referência

> URL da imagem (curta duração — válida por ~7 dias a partir da extração):  
> `https://www.figma.com/api/mcp/asset/db2716ba-1cd5-4e2d-8d17-6ba9cba31b47`

A tela exibe:
- Fundo inteiramente preto-azulado (`#050510`)
- Logo "RUNNIN" em branco + badge ".AI" em ciano ao centro da tela
- Tagline "FEITO PARA VENCEDORES" com baixa opacidade, logo abaixo do logo
- Linha ciano de 2 px abaixo da tagline

---

## Tarefas Flutter (referência para tasks.md)

| ID    | Descrição                                       | Depende de        |
|-------|-------------------------------------------------|-------------------|
| T-S01 | Criar `SplashPage` com fundo `#050510`          | AppColors         |
| T-S02 | Implementar `SplashLogo` (wordmark + badge AI)  | AppColors, AppTypography |
| T-S03 | Implementar `SplashTagline` com opacity e tracking | AppColors, AppTypography |
| T-S04 | Implementar linha decorativa `BrandAccentLine`  | AppColors         |
| T-S05 | Configurar rota e lógica de duração/navegação   | Decisão de produto |

---

## Lacunas / Decisões pendentes

1. **Duração do splash:** quanto tempo a tela fica visível antes de navegar?
2. **Animação:** há fade-in do logo? Fade-out para a próxima tela?
3. **Fonte JetBrains Mono:** já está no projeto ou precisa ser adicionada ao `pubspec.yaml`?
4. **Rota destino:** após o splash, vai para onboarding ou home (depende de `isFirstLaunch` / autenticação)?
