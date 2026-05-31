# Runnin.AI — Jornadas de Usuário & Funcionalidades

> Mapeamento completo das jornadas, fluxos e funcionalidades extraídas do Figma.
> Baseado em todas as telas documentadas em `docs/figma/screens/`.

---

## 1. Visão Geral do Produto

**Runnin.AI** é um app de treinamento de corrida com coach de IA personalizado. A proposta central é:
- Plano de corrida gerado por IA a partir de um assessment inicial
- Coach conversacional que adapta o plano em tempo real
- Gamificação (XP, badges, streak) para retenção
- Monitoramento de saúde via wearables
- Histórico e benchmarks de performance

### Arquitetura de navegação
```
App Shell
├── BottomNav (5 tabs principais)
│   ├── HOME — Dashboard + coach card + notificações
│   ├── TREINO — Plano semanal/mensal + relatórios + ajustes via coach chat
│   ├── RUN — Sessão ativa de corrida (FAB central)
│   ├── HIST — Histórico de corridas + dados de saúde + benchmark
│   └── PERFIL — Perfil do usuário + gamificação + saúde + settings
└── Fluxo de onboarding (pré-app, 13 passos)
```

---

## 2. Jornada 1 — Onboarding (13 passos)

**Arquivo:** `screens/ONBOARDING_01.md`, `ONBOARDING_02.md`, `ONBOARDING_03.md`, `LOGIN.md`, `ASSESSMENT.md`, `PLAN_LOADING.md`

### Fluxo completo

```
SPLASH
  └─► ONBOARDING 01 (1/13) ──► ONBOARDING 02 (2/13) ──► ONBOARDING 03 (3/13)
        └─► LOGIN (4/13)
              └─► ASSESSMENT 01 (5/13) ──► 02 ──► 03 ──► 04 ──► 05 ──► 06 ──► 07 ──► 08 ──► 09 (13/13)
                    └─► PLAN LOADING
                          └─► HOME (entrada no app)
```

### Passos e CTAs

| Posição | Tela | CTA | PULAR? |
|---|---|---|---|
| — | Splash | (auto) | — |
| 1/13 | Onboarding 01 | CONTINUAR ↗ | Sim |
| 2/13 | Onboarding 02 | CONTINUAR ↗ | Sim |
| 3/13 | Onboarding 03 | CONTINUAR ↗ | Sim |
| 4/13 | Login | PRÓXIMO ↗ | Não |
| 5/13 | Assessment 01 | PRÓXIMO ↗ | Não |
| 6/13 | Assessment 02 | PRÓXIMO ↗ | Não |
| 7/13 | Assessment 03 | PRÓXIMO ↗ | Não |
| 8/13 | Assessment 04 | PRÓXIMO ↗ | Não |
| 9/13 | Assessment 05 | PRÓXIMO ↗ | Não |
| 10/13 | Assessment 06 | PRÓXIMO ↗ | Não |
| 11/13 | Assessment 07 | PRÓXIMO ↗ | Não |
| 12/13 | Assessment 08 | PRÓXIMO ↗ | Não |
| 13/13 | Assessment 09 | CRIAR MEU PLANO ↗ | Não |
| pós-13 | Plan Loading | (gate — sem CTA) | Não |

### Funcionalidades do onboarding
- **Barra de progresso global (13 passos)** — 2px no topo, fill ciano proporcional
- **Slides de apresentação** — 3 slides (feature cards: IA, tracking, gamificação)
- **Autenticação** — email/senha + OTP + Google Sign-In
- **Assessment conversacional** — Coach.AI guia 9 etapas de coleta de dados pessoais
- **Geração de plano** — tela de loading com etapas animadas enquanto IA cria o plano

### Dados coletados no Assessment
(inferidos dos 9 nós extraídos)
1. Objetivo de corrida (velocidade, resistência, primeira corrida, etc.)
2. Nível de experiência
3. Disponibilidade semanal (frequência e período do dia — manhã/tarde/noite)
4. Dados físicos (peso, altura, idade)
5. Histórico de lesões/condições de saúde (chips multi-select)
6. Frequência cardíaca de repouso (input numérico)
7. Ritmo/pace atual
8. Equipamento disponível (GPS, wearable)
9. Meta específica (tempo, distância, evento)

---

## 3. Jornada 2 — Coach Intro (pós-onboarding, 1ª vez)

**Arquivo:** `screens/COACH_INTRO.md`
**Nós:** 1:5770–1:5922 (4 telas)

### Fluxo
```
HOME (1ª vez)
  └─► COACH_INTRO 01 ──► 02 ──► 03 ──► 04
        └─► HOME (com coach ativo)
```

### Funcionalidades
- Apresentação do Coach.AI ao usuário
- 4 slides de onboarding do coach
- Introdução aos conceitos de zone training, plano adaptativo e gamificação

---

## 4. Jornada 3 — Tab HOME

**Arquivo:** `screens/HOME.md`
**Nó:** 1:5269

### Funcionalidades
- **Dashboard diário** — data, estado do plano do dia
- **Coach.AI card** — análise diária personalizada com CTA "VER PLANO"
- **WeeklyDayGrid** — 7 dias da semana com estados: ✓ completo / HOJE / futuro dim
- **Métricas rápidas** — cards de volume semanal, pace médio, BPM médio
- **Notificações** — cards com left-border colorida por categoria (5 categorias)
- **AlertToggleRow** — gerenciamento de alertas inline
- **BadgeChip** — preview de badges próximos de desbloquear

### Estados da semana (WeeklyDayGrid)
```
✓ Completo: check verde + dados reais
HOJE: destaque ciano + treino do dia
Futuro: dim, dados do plano
Descanso: label especial
```

---

## 5. Jornada 4 — Tab TREINO

**Arquivo:** `screens/TREINO.md`
**Nós:** 1:7230–1:8498 (10 telas)

### Sub-jornadas

#### 5.1 Plano Semanal → Plano Mensal
```
TREINO (entrada)
  ├─► Plano Semanal (1:7230) — lista de 7 dias
  └─► Plano Mensal (1:7546) — cards de semana + gráfico de barras
```

**Funcionalidades:**
- Lista de dias com estado OK/HOJE/FUTURO/DESCANSO
- Stats row: VOLUME / SESSÕES / DESCANSO
- Coach.AI card com análise do período
- Visualização mensal com foco (ex: "RESISTÊNCIA"), volume e status por semana
- Gráfico de barras de volume (4 barras semanais)

#### 5.2 Relatórios
```
TREINO
  └─► Relatórios lista (1:7697)
        └─► Relatório Detalhe (1:7816)
```

**Funcionalidades:**
- Lista de relatórios com ADERÊNCIA/KM/SESSÕES/FREE
- Preview clipped da análise coach
- Detalhe: card de aderência 48px, métricas row, banner free runs, análise coach completa, destaques (+ e !), adaptação sugerida, META row

#### 5.3 Solicitar Alteração de Plano → Coach Chat
```
TREINO
  └─► Solicitar Alteração — não selecionado (1:7964)
        └─► Solicitar Alteração — selecionado (1:8062)
              └─► Coach Chat 1 (1:8168) — opções iniciais
                    └─► Coach Chat 2 (1:8215) — confirmação de seleção
                          └─► Coach Chat 3 (1:8281) — confirmação final
                                ├─► VER PLANO ATUALIZADO
                                └─► HOME
```

**Funcionalidades:**
- Grid 2-col de 10 tipos de alteração
- Estado selecionado: borda/bg ciano + summary bar + CTA "CONVERSAR COM COACH ↗"
- Chat com Coach.AI: bubbles de usuário + coach
- 4 botões de opção inline no chat
- Confirmação em 2 etapas
- CTAs finais: ver plano atualizado ou voltar ao HOME

#### 5.4 Histórico de Ajustes
```
TREINO
  └─► Histórico de Ajustes (1:8498)
```

**Funcionalidades:**
- Tab AJUSTES ativo
- Card de alerta vermelho (limite de revisões)
- Info block com borda esquerda apenas
- Histórico de entradas com data + descrição + tag
- Calendário de revisões

---

## 6. Jornada 5 — Tab RUN (Sessão Ativa)

**Arquivo:** `screens/RUN_JOURNEY.md`
**Nós:** 1:5974–1:7105

### Fluxo completo
```
HOME / TREINO
  └─► RUN (FAB tap)
        └─► Pre-run / Confirmação
              └─► Sessão Ativa (HUD)
                    ├─► Grade 2×2 de métricas em tempo real
                    ├─► Zone Bar (zona atual)
                    ├─► Split Cards (KM atual)
                    └─► Pause / Stop
                          └─► Pós-corrida
                                ├─► Stats (grade 3 colunas)
                                ├─► Split Rows (relatório por KM)
                                ├─► Badge Unlock Modal (se desbloqueou badge)
                                ├─► Compartilhar (ShareCardPreview)
                                │     └─► Foto + overlay chips
                                └─► HOME / HIST
```

### Funcionalidades do HUD ativo
- Grade 2×2: DISTÂNCIA / PACE / TEMPO / BPM (valores grandes 28px)
- Zone Bar: zona atual Z1–Z5 com cor canônica
- Split Cards: scroll horizontal de KMs completos
- Coach.AI feedback em tempo real (card flutuante)

### Funcionalidades pós-corrida
- Grid 3-col de stats: distância, pace médio, BPM médio, XP ganho, calorias, cadência
- Split report: barra horizontal por KM (melhor=ciano, outros=dim)
- Badge Unlock Modal: overlay com anéis concêntricos + XP ganho
- Share card: branded, distância hero 48px, mapa SVG da rota
- Foto overlay: chips de dados sobre foto

---

## 7. Jornada 6 — Tab HIST

**Arquivo:** `screens/HIST.md`
**Nós:** 1:9956–1:11403 (5 telas)

### Sub-jornadas

#### 7.1 Dados — Tendências (3 meses)
**Nó:** 1:9956
- 10 stat cards 2-col (volume, pace, BPM, aderência, etc.)
- Zone distribution: barra empilhada + tabela %
- Volume semanal: gráfico de linha
- Pace evolution: gráfico de linha
- BPM trend: gráfico de linha
- Evolution 2×2: grade de deltas (↑↓ com cor)
- Coach.AI análise laranja

#### 7.2 Corridas — Lista
**Nó:** 1:10393
- Lista de corridas (~scroll 2488px, ~10 entradas)
- RunCard: badge de tipo (40px) + stats row + preview coach clipped
- Tap para detalhe

#### 7.3 Corrida — Detalhe
**Nó:** 1:10991
```
Lista de corridas
  └─► Detalhe da corrida (1:10991)
        ├─► 3-col metric cards
        ├─► Coach card ciano
        ├─► KM1–KM5 splits com barras horizontais
        ├─► COMPARTILHAR (CTA ciano)
        └─► VER CONVERSA COM COACH (CTA laranja)
              └─► Coach Chat post-run (1:11403)
```

#### 7.4 Coach Chat Pós-Corrida
**Nó:** 1:11403
- Stats bar: DIST / PACE / BPM / XP
- 6 mensagens de chat (usuário + coach)
- Banner "ANÁLISE VERIFICADA"

#### 7.5 Benchmark
**Nó:** 1:11114
- TOP 30% — valor 48px
- Curva normal (bell curve) SVG com posição do usuário
- 4 métricas de benchmark: valor usuário (ciano) vs comparação muted

---

## 8. Jornada 7 — Tab PERFIL

**Arquivo:** `screens/PERFIL.md`
**Nós:** 1:11209–1:12759 (8 telas documentadas)

### Estrutura do PERFIL

```
PERFIL (raiz) (1:11209)
├─► GAMIFICAÇÃO (menu item 1)
│   ├─► BADGES (1:11797) — grid de 21 badges
│   ├─► XP (1:12146) — level card + earnings table
│   └─► STREAK (1:12238) — contador + calendar grid
├─► SAÚDE (menu item 2)
│   ├─► TENDÊNCIAS (1:12329) — 4 metric cards BPM/sono/recovery
│   ├─► ZONAS (1:12419) — 5 zone cards Z1-Z5
│   ├─► DISPOSITIVOS (1:12542) — wearable connect + permissões + compatíveis
│   └─► EXAMES (1:12759) — upload + seus exames + recomendados
├─► AJUSTES (menu item 3) — ⚠️ PENDENTE
│   ├─► Coach settings — ⚠️ PENDENTE
│   ├─► Alertas/Notificações — ⚠️ PENDENTE
│   └─► Unidades — ⚠️ PENDENTE
├─► ASSINATURA (menu item 4) — ⚠️ PENDENTE
└─► Editar Perfil — ⚠️ PENDENTE (botão na tela raiz)
```

### Funcionalidades documentadas

**Raiz PERFIL:**
- Avatar + nome + nível + badge PREMIUM
- Gamification stats row (STREAK / XP / BADGES)
- Body metrics row (PESO / ALTURA / IDADE / FREQ)
- Skin palette selector (4 temas)
- Menu de 4 itens navegáveis
- "Editar perfil" + "Logout"

**GAMIFICAÇÃO:**
- 21 badges com estados desbloqueado/bloqueado (progress bar nos bloqueados)
- 7 desbloqueados no estado exemplo
- XP: nível atual (7 "Corredor"), barra de progresso, tabela de ganhos por ação
- Streak: contador "12 dias", calendar grid 7×4 com gradiente de opacidade

**SAÚDE:**
- Tendências: BPM repouso/corrida, sono médio, recovery score com tendências mensais
- Zonas: cards Z1–Z5 com range BPM, % de tempo, barra de progresso
- Dispositivos: Galaxy Watch 5 conectado, toggles de permissão, 8 dispositivos compatíveis
- Exames: upload dashed, 2 exames com análise Coach, coach summary, 5 exames recomendados (ALTO/MÉDIO)

---

## 9. Telas Pendentes (não extraídas)

> As telas abaixo existem na navegação do app mas ainda não foram fornecidas para extração.

### 9.1 PERFIL > AJUSTES (3+ telas estimadas)

| Sub-tela | Funcionalidade esperada |
|---|---|
| Ajustes — Coach | Configurar personalidade/intensidade do coach, preferências de feedback |
| Ajustes — Alertas | Gerenciar notificações push, lembretes de treino, alertas de zona |
| Ajustes — Unidades | Km/milhas, pace min/km vs min/milha, sistema métrico/imperial |

### 9.2 PERFIL > ASSINATURA (1+ telas)

| Sub-tela | Funcionalidade esperada |
|---|---|
| Assinatura Premium | Planos, benefícios, comparação free vs premium, CTA de upgrade |

### 9.3 PERFIL > Editar Perfil (1 tela)

| Sub-tela | Funcionalidade esperada |
|---|---|
| Editar Perfil | Edição de nome, foto, dados físicos (PESO/ALTURA/IDADE/FREQ) |

### 9.4 Estados não documentados

| Estado | Contexto |
|---|---|
| Empty states | HIST sem corridas, TREINO sem plano, BADGES todos bloqueados |
| Error states | Falha de conexão, erro de autenticação |
| Loading states | Telas com skeleton/shimmer enquanto carregam dados |
| Notificações push | Design do payload (não aplicável no Figma) |

---

## 10. Funcionalidades por Feature Area

### 10.1 IA & Coach

| Funcionalidade | Tela(s) |
|---|---|
| Geração de plano inicial | PLAN_LOADING |
| Coach card diário | HOME |
| Análise de treino | TREINO > Relatório Detalhe |
| Ajuste conversacional de plano | TREINO > Coach Chat (3 etapas) |
| Feedback pós-corrida | HIST > Coach Chat pós-run |
| Análise de exames médicos | PERFIL > SAÚDE > EXAMES |
| Análise de wearable | PERFIL > SAÚDE > DISPOSITIVOS |
| Breadcrumb "COACH.AI > [AÇÃO]" | Universal (todos os contextos) |

### 10.2 Gamificação

| Funcionalidade | Tela(s) |
|---|---|
| Streak diário | PERFIL > GAMIFICAÇÃO > STREAK |
| Sistema de XP | PERFIL > GAMIFICAÇÃO > XP |
| Badges (21 total) | PERFIL > GAMIFICAÇÃO > BADGES |
| Badge unlock modal | RUN_JOURNEY (pós-corrida) |
| Percentil/benchmark | HIST > BENCH |
| Skin themes | PERFIL (raiz) |

### 10.3 Saúde & Wearable

| Funcionalidade | Tela(s) |
|---|---|
| BPM em corrida (tempo real) | RUN_JOURNEY (HUD) |
| Zone training | RUN_JOURNEY + PERFIL > SAÚDE > ZONAS |
| Tendências de saúde | PERFIL > SAÚDE > TENDÊNCIAS |
| Conexão de wearable | PERFIL > SAÚDE > DISPOSITIVOS |
| Exames médicos | PERFIL > SAÚDE > EXAMES |

### 10.4 Plano & Treinamento

| Funcionalidade | Tela(s) |
|---|---|
| Plano semanal | TREINO > Semanal |
| Plano mensal | TREINO > Mensal |
| Relatório de aderência | TREINO > Relatórios |
| Solicitação de alteração | TREINO > Solicitar Alteração |
| Histórico de ajustes | TREINO > Histórico de Ajustes |

### 10.5 Corrida

| Funcionalidade | Tela(s) |
|---|---|
| Sessão ativa (HUD) | RUN_JOURNEY |
| KM splits em tempo real | RUN_JOURNEY |
| Resumo pós-corrida | RUN_JOURNEY |
| Compartilhamento de corrida | RUN_JOURNEY |
| Histórico de corridas | HIST > Corridas |
| Detalhe de corrida | HIST > Detalhe |

---

## 11. Regras de Negócio Identificadas

| Regra | Evidência no Figma |
|---|---|
| Plano gerado somente após assessment completo | PLAN_LOADING é gate obrigatório |
| Limite de revisões de plano por mês | HIST > Ajustes — alerta card vermelho "revisão usada" |
| Usuário Premium tem acesso a funcionalidades adicionais | Badge "PREMIUM" + menu ASSINATURA |
| Exames até 5 uploads/mês, máx 10MB | PERFIL > SAÚDE > EXAMES — stats card |
| Streak quebrado se dia sem corrida | GAMIFICAÇÃO > STREAK — células inativas |
| HRV/Recovery requer wearable com permissão | DISPOSITIVOS — toggle HRV/Recovery OFF por padrão |
| Zone 4 recalibrada com base em ergométrico real | Análise Coach no exame ergométrico |

---

## 12. Inventário Completo de Telas

| # | Tela | Node(s) | Seção | Status |
|---|---|---|---|---|
| 1 | Splash | 1:4283 | Onboarding | ✅ Extraído |
| 2 | Onboarding 01 | 1:4295 | Onboarding | ✅ Extraído |
| 3 | Onboarding 02 | 1:4364 | Onboarding | ✅ Extraído |
| 4 | Onboarding 03 | 1:4437 | Onboarding | ✅ Extraído |
| 5 | Login | 1:4510 | Onboarding | ✅ Extraído |
| 6–14 | Assessment 01–09 | 1:4566–1:5078 | Onboarding | ✅ Extraído |
| 15 | Plan Loading | 1:5143 | Onboarding | ✅ Extraído |
| 16 | Home | 1:5269 | App | ✅ Extraído |
| 17–20 | Coach Intro 01–04 | 1:5770–1:5922 | App | ✅ Extraído |
| 21–N | Run Journey (múltiplas) | 1:5974–1:7105 | App | ✅ Extraído |
| N+1–N+10 | Treino (10 telas) | 1:7230–1:8498 | App | ✅ Extraído |
| N+11–N+15 | HIST (5 telas) | 1:9956–1:11403 | App | ✅ Extraído |
| N+16–N+23 | PERFIL (8 telas) | 1:11209–1:12759 | App | ✅ Extraído |
| — | PERFIL > AJUSTES (Coach, Alertas, Unidades) | desconhecido | App | ⚠️ Pendente |
| — | PERFIL > ASSINATURA | desconhecido | App | ⚠️ Pendente |
| — | PERFIL > Editar Perfil | desconhecido | App | ⚠️ Pendente |
