# Documentação Figma — Runnin.AI

> Extração MCP das telas do Figma para especificação de implementação Flutter.  
> Arquivo Figma: `gmfDCcbt5mQ4Yc6wa0PAye` (telas-runnin)  
> Estratégia: cada bloco de telas extraído é documentado aqui com tokens, layout, tipografia e lacunas de produto.

---

## Telas extraídas

| Tela              | Arquivo                                              | nodeId  | Posição | Status      |
|-------------------|------------------------------------------------------|---------|---------|-------------|
| Splash            | [screens/SPLASH.md](screens/SPLASH.md)               | 1:4283  | —       | ✅ Extraído |
| Onboarding 01     | [screens/ONBOARDING_01.md](screens/ONBOARDING_01.md) | 1:4295  | 1/13    | ✅ Extraído |
| Onboarding 02     | [screens/ONBOARDING_02.md](screens/ONBOARDING_02.md) | 1:4364  | 2/13    | ✅ Extraído |
| Onboarding 03     | [screens/ONBOARDING_03.md](screens/ONBOARDING_03.md) | 1:4437  | 3/13    | ✅ Extraído |
| Login             | [screens/LOGIN.md](screens/LOGIN.md)                 | 1:4510  | 4/13    | ✅ Extraído |
| Assessment 01–09  | [screens/ASSESSMENT.md](screens/ASSESSMENT.md)       | 1:4566–1:5078 | 5-13/13 | ✅ Extraído |
| Plan Loading      | [screens/PLAN_LOADING.md](screens/PLAN_LOADING.md)   | 1:5143        | pós-13  | ✅ Extraído |
| Home              | [screens/HOME.md](screens/HOME.md)                   | 1:5269        | app     | ✅ Extraído |
| Coach Intro 01–04 | [screens/COACH_INTRO.md](screens/COACH_INTRO.md)     | 1:5770–1:5922 | app     | ✅ Extraído |
| Run Journey       | [screens/RUN_JOURNEY.md](screens/RUN_JOURNEY.md)     | 1:5974–1:7105 | app     | ✅ Extraído |
| Treino (10 telas) | [screens/TREINO.md](screens/TREINO.md)               | 1:7230–1:8498 | app     | ✅ Extraído |

---

## Tokens globais identificados

> Consolidados a partir das extrações — atualizar conforme novas telas forem processadas.

### Cores

| Token (proposto)            | Hex / RGBA                       | Fonte                  |
|-----------------------------|----------------------------------|------------------------|
| `color/bg/base`             | `#050510`                        | Splash, Onboarding     |
| `color/brand/accent`        | `#00D4FF`                        | Splash, Onboarding     |
| `color/text/high`           | `#FFFFFF`                        | Splash, Onboarding     |
| `color/text/medium`         | `rgba(255, 255, 255, 0.60)`      | Onboarding (corpo)     |
| `color/text/muted`          | `rgba(255, 255, 255, 0.55)`      | Splash, Onboarding     |
| `color/badge/text`          | `#050510`                        | Badge .AI              |
| `color/surface/card`        | `rgba(255, 255, 255, 0.03)`      | Onboarding feature cards |
| `color/border/card`         | `rgba(255, 255, 255, 0.08)`      | Onboarding cards, top bar bg |
| `color/dot/active`          | `#00D4FF`                        | Dot ativo no page indicator |
| `color/dot/inactive`        | `rgba(255, 255, 255, 0.06)`      | Dots inativos          |
| `color/dot/visited`         | `rgba(255, 255, 255, 0.20)`      | Dots de slides visitados |
| `color/btn/back/bg`         | `rgba(255, 255, 255, 0.06)`      | Botão VOLTAR (fundo)   |
| `color/btn/back/border`     | `rgba(255, 255, 255, 0.10)`      | Botão VOLTAR (borda)   |
| `color/input/bg`            | `rgba(255, 255, 255, 0.03)`      | Background campos de texto (Login) |
| `color/input/border`        | `rgba(255, 255, 255, 0.08)`      | Borda campos de texto (Login) |
| `color/input/placeholder`   | `rgba(255, 255, 255, 0.50)`      | Placeholder dos campos (Login) |
| `color/btn/google/bg`       | `rgba(255, 255, 255, 0.05)`      | Background botão Google Sign-In |
| `color/brand/coach`         | `#FF6B35`                        | Cor COACH.AI — blocos conversacionais (Assessment) |
| `color/info/bg`             | `rgba(0, 212, 255, 0.14)`        | Background blocos de info ciano (Assessment) |
| `color/selection/active/bg` | `rgba(0, 212, 255, 0.10)`        | Background opção selecionada (Assessment) |
| `color/selection/active/border` | `rgba(0, 212, 255, 0.30)`    | Borda opção selecionada (Assessment) |
| `color/text/dim`                | `rgba(255, 255, 255, 0.25)`  | Sub-detalhe das tarefas (Plan Loading) |
| `color/progress/track`          | `rgba(255, 255, 255, 0.05)`  | Track da barra de progresso (Plan Loading) |

### Tipografia

| Token (proposto)              | Fonte           | Peso    | Tamanho | LS       | LH      |
|-------------------------------|-----------------|---------|---------|----------|---------|
| `type/display/brand`          | JetBrains Mono  | Bold    | 28 px   | 3.36 px  | 42 px   |
| `type/display/heading`        | JetBrains Mono  | Bold    | 28 px   | −0.84 px | 28 px   |
| `type/label/badge`            | JetBrains Mono  | Bold    | 12 px   | 0        | 18 px   |
| `type/label/tagline`          | JetBrains Mono  | Regular | 12 px   | 2.4 px   | 18 px   |
| `type/label/slide`            | JetBrains Mono  | Regular | 12 px   | 1.8 px   | 18 px   |
| `type/label/slide-number`     | JetBrains Mono  | Bold    | 14 px   | −0.84 px | 14 px   |
| `type/label/nav`              | JetBrains Mono  | Medium  | 14 px   | 1.12 px  | 21 px   |
| `type/label/skip`             | JetBrains Mono  | Medium  | 13 px   | 1.3 px   | 19.5 px |
| `type/body/main`              | JetBrains Mono  | Regular | 15 px   | 0        | 25.5 px |
| `type/card/title`             | JetBrains Mono  | Bold    | 13 px   | 0        | 19.5 px |
| `type/card/description`       | JetBrains Mono  | Regular | 12 px   | 0        | 18 px   |
| `type/cta/button`             | JetBrains Mono  | Bold    | 12 px   | 1.2 px   | 18 px   |
| `type/header/logo`            | JetBrains Mono  | Bold    | 14 px   | 1.4 px   | 21 px   |
| `type/label/field`            | JetBrains Mono  | Medium  | 11 px   | 1.65 px  | 16.5 px |
| `type/label/assessment`       | JetBrains Mono  | Regular | 13 px   | 1.95 px  | 19.5 px |
| `type/heading/assessment`     | JetBrains Mono  | Bold    | 24 px   | −0.48 px | 24 px   |
| `type/input/value`            | JetBrains Mono  | Bold    | 28 px   | −0.84 px | 28 px   |
| `type/body/assessment`        | JetBrains Mono  | Regular | 14 px   | 0        | 23.8 px |

### Componentes compartilhados (Onboarding)

Identificados a partir dos 3 slides — todos reutilizáveis:

| Componente                  | Descrição                                                          |
|-----------------------------|--------------------------------------------------------------------|
| `OnboardingTopProgressBar`  | Barra 2px no topo; fill ciano proporcional ao slide atual (N/13)   |
| `OnboardingHeader`          | Logo+PULAR à direita; variante com/sem botão VOLTAR à esquerda     |
| `OnboardingSlideLabel`      | "// SLIDE_XX" — ciano, tracking 1.8px                             |
| `OnboardingHeading`         | Título em branco + número do slide em ciano (top-right do heading) |
| `OnboardingFeatureCard`     | Ícone 22px + título Bold 13px + descrição Regular 12px, borda sutil |
| `OnboardingContinueButton`  | CTA ciano fullwidth "CONTINUAR ↗"                                  |
| `OnboardingPageIndicator`   | 13 dots: ativo (20×4px ciano), visitado (6×4px 20% branco), inativo (6×4px 6% branco) |

### Componentes — Login

| Componente           | Descrição                                                                    |
|----------------------|------------------------------------------------------------------------------|
| `FormFieldLabel`     | Label ALL CAPS 11px Medium tracking 1.65px, cor `rgba(255,255,255,0.55)`     |
| `FormTextField`      | Campo 48.5px, bg `rgba(255,255,255,0.03)`, borda sutil, placeholder muted    |
| `OtpTextField`       | Variante FormTextField — placeholder "_ _ _ _ _ _" tracking 4.2px           |
| `GoogleSignInButton` | Outline escuro `rgba(255,255,255,0.05)`, ícone Google 16px, texto branco     |

### Componentes — Assessment

| Componente           | Descrição                                                                    |
|----------------------|------------------------------------------------------------------------------|
| `AssessmentLabel`    | "// ASSESSMENT_XX" — ciano 13px Regular tracking 1.95px (≠ onboarding 12px) |
| `AssessmentHeading`  | H2 Bold 24px tracking -0.48px (≠ onboarding H1 28px)                        |
| `CoachAIBlock`       | Bloco COACH.AI com borda esquerda 2px `#FF6B35`, bg `rgba(255,107,53,0.06)` |
| `CyanInfoBlock`      | Bloco informativo com borda 1px `rgba(0,212,255,0.14)`, texto branco 14px   |
| `SelectionButton`    | Botão fullwidth 56.5px, estado selecionado com borda ciano + bg 10% ciano   |
| `TimePeriodCard`     | Card 109.8×138.5px — seleção de período (manhã/tarde/noite)                 |
| `NumericInputField`  | Input com valor Bold 28px + unidade 14px + setas ±                          |
| `HealthChip`         | Chip multi-select largura variável para condições de saúde                  |

### Componentes — Plan Loading

| Componente           | Descrição                                                                    |
|----------------------|------------------------------------------------------------------------------|
| `CoachAIBreadcrumb`  | `[■] COACH.AI > {AÇÃO}` — quadrado laranja 10px + texto orange 12px 1.8ls   |
| `PlanTaskRow`        | Row com 3 estados (done/active/pending), label OK/●/○, texto + sub-detalhe  |
| `PlanProgressBar`    | Track 4px + fill animado ciano, sem border-radius, sem label de %            |

### Componentes globais — Home + Run Journey

| Componente              | Descrição                                                                    |
|-------------------------|------------------------------------------------------------------------------|
| `BottomTabBar`          | 5 tabs: HOME/TREINO/RUN(FAB)/HIST/PERFIL; RUN = 56px quad ciano elevado     |
| `TopNavBar`             | Frosted bg, back button 40px, logo lockup "RUNNIN .AI", breadcrumb página   |
| `SectionHeading`        | Bold 22px + superscript 6.6px ciano — padrão de todas as seções app         |
| `CoachAICard`           | Left-border laranja/ciano, breadcrumb, corpo; variante con/sem botões        |
| `NotificationCard`      | Left-border colorida por categoria (5 cores), ícone + título + sub + time   |
| `WeeklyDayGrid`         | 7 colunas, 3 estados (✓completo/HOJE/futuro dim), header + corpo separados  |
| `MetricCard`            | Label 11px + valor 28px Bold (colorido) + delta + sub; variante ciano sólido|
| `ZoneBar`               | 5 zonas Z1–Z5 com cores canônicas e barra proporcional                       |
| `BadgeChip`             | Chip ciano-tintado, ícone 18px + texto 13px, border rgba(0,212,255,0.25)    |
| `ExerciseCard`          | Ícone 28px + nome + reps (ciano) + descrição dim, border sutil              |
| `AlertToggleRow`        | Título + sub, pill toggle ON(ciano)/OFF(dim) à direita                      |
| `RunMetricCell`         | Label + superscript 9px ciano + valor 28px + unidade; na grade 2x2 do HUD  |
| `SplitCard`             | KM## + tempo (OK=laranja, PEND=dim), scroll horizontal                       |
| `SplitRow`              | KM label + barra (melhor=ciano, outros=dim) + tempo, relatório pós-corrida  |
| `BadgeUnlockModal`      | Overlay escuro + card top/bottom ciano, badge icon com anéis concêntricos   |
| `PostRunStatCard`       | Label + valor 22px Bold (colorido) + unidade, grade 3 colunas               |
| `ShareCardPreview`      | Card branded ciano-bordado, distância hero 48px, mapa rota SVG, stats       |
| `PhotoOverlayChip`      | Label + valor sobre foto, bg rgba(5,5,16,0.60), border dim                  |
| `OverlayDataToggleChip` | Multi-select chip: ativo=ciano tintado+✓, inativo=dim                       |

### Fluxo completo de 13 passos (barra de progresso)

| Posição | Tela            | CTA               | PULAR? |
|---------|-----------------|-------------------|--------|
| 1/13    | Onboarding 01   | CONTINUAR ↗       | Sim    |
| 2/13    | Onboarding 02   | CONTINUAR ↗       | Sim    |
| 3/13    | Onboarding 03   | CONTINUAR ↗       | Sim    |
| 4/13    | Login           | PRÓXIMO ↗         | Não    |
| 5/13    | Assessment 01   | PRÓXIMO ↗         | Não    |
| 6/13    | Assessment 02   | PRÓXIMO ↗         | Não    |
| 7/13    | Assessment 03   | PRÓXIMO ↗         | Não    |
| 8/13    | Assessment 04   | PRÓXIMO ↗         | Não    |
| 9/13    | Assessment 05   | PRÓXIMO ↗         | Não    |
| 10/13   | Assessment 06   | PRÓXIMO ↗         | Não    |
| 11/13   | Assessment 07   | PRÓXIMO ↗         | Não    |
| 12/13   | Assessment 08   | PRÓXIMO ↗         | Não    |
| 13/13   | Assessment 09   | CRIAR MEU PLANO ↗ | Não    |
| pós-13  | Plan Loading    | (nenhum — gate)   | Não    |

---

## Pendências globais

- Verificar se `JetBrains Mono` já está no `pubspec.yaml` (não confirmado no Figma via `get_variable_defs`)
- `get_variable_defs` retornou vazio — tokens Figma não publicados; valores extraídos diretamente dos estilos dos nós
