# Design System do Protótipo

> Baseado nos prints em `references/` e consolidado para implementação Flutter.

## 1. Direção visual

- Estética: performance-tech + brutalismo editorial + interface de treino de alta intensidade.
- Sensação: precisa, atlética, quase "terminal", sem parecer enterprise genérico.
- Padrão visual: fundo muito escuro, grids rígidos, blocos retangulares, contrastes fortes, pouca curva, muita hierarquia tipográfica.
- Navegação: shell fixa com bottom nav e fluxos fullscreen para onboarding, preparação, corrida ativa e relatório.

## 2. Fundamentos

### Cores base

- `bg/base`: preto azulado profundo, próximo de `#060814`.
- `surface/01`: bloco principal escuro.
- `surface/02`: bloco escuro elevado para cards selecionados.
- `border/subtle`: linhas finas azuladas/cinza grafite.
- `text/high`: branco quase puro.
- `text/medium`: cinza frio para labels e apoio.

### Paletas de skin

- `Artico`: ciano + laranja + azul elétrico. É a paleta-padrão do protótipo.
- `Magenta`: rosa neon + aqua + violeta. Variante mais premium/editorial.
- `Sangue`: vermelho vivo + azul frio + coral. Variante mais agressiva.
- `Volt`: lima neon + roxo + cyan. Variante mais arcade/performance.

### Cores semânticas

- Zona Z1: azul.
- Zona Z2: verde.
- Zona Z3: amarelo.
- Zona Z4: laranja.
- Zona Z5: vermelho.
- Sucesso: verde saturado.
- Atenção: âmbar.
- Erro: vermelho quente.

### Tipografia

- `Display`: caixa alta, peso pesado, com sensação de terminal atlético.
- `Body`: compacta, bem espaçada, leitura rápida.
- `Data`: números grandes, monoespaçados ou com alinhamento tabular para pace, tempo, bpm e distância.
- `Label`: microcopy em caps, com tracking alto.

### Espaçamento e forma

- Grid de 4/8/12/16/20/24/32.
- Bordas retas ou raio mínimo.
- Separação feita por blocos e linhas, não por sombras.
- Cards com padding generoso, mas conteúdo muito alinhado à esquerda.

## 3. Componentes-base

- `AppShell`: topo enxuto + bottom nav + área de conteúdo scrollável.
- `Hero Session Card`: card principal da sessão do dia com métrica, CTA e nota do coach.
- `Narrative Card`: bloco textual do Coach com borda lateral colorida.
- `Metric Card`: card de valor numérico para distância, bpm, xp, pace, streak e benchmark.
- `Week Grid`: grade semanal com estado `done`, `today`, `rest`, `planned`.
- `Training Row`: linha de treino do plano semanal/mensal.
- `Segmented Tabs`: usado em treino, histórico e gamificação.
- `Toggle Row`: usado em alertas, notificações e ajustes.
- `Palette Card`: seletor de skin no perfil.
- `Achievement Card`: conquista desbloqueada ou em progresso.
- `Chart Panel`: painel para tendência, volume, bpm e zonas cardíacas.
- `CTA Primary`: botão preenchido na cor primária.
- `CTA Secondary`: botão outline ou ghost em superfície.

## 4. Estados de UX extraídos dos prints

- Loading de plano gerado por IA.
- Sessão do dia sem plano.
- Sessão do dia pronta para iniciar.
- Revisão semanal disponível.
- Corrida ativa.
- Relatório pós-corrida pendente e pronto.
- Conquista desbloqueada.
- Histórico com filtros por período.
- Perfil com skin ativa.

## 5. Módulos visuais

- Home.
- Onboarding.
- Treino.
- Preparação pré-corrida.
- Corrida ativa.
- Relatório pós-corrida.
- Coach/chat.
- Histórico/analytics.
- Gamificação.
- Perfil.
- Saúde.
- Ajustes.

## 6. Decisões para implementação Flutter

- O design system precisa nascer orientado por tokens, não por cores hardcoded por tela.
- O seletor de skin pertence ao `Profile` e deve persistir localmente.
- Métricas e painéis devem reutilizar componentes genéricos para não duplicar visual em `home`, `history`, `report` e `training`.
- As zonas cardíacas precisam de tokens próprios, independentes da skin.
- O app já ganhou a fundação inicial para skins em:
  - `app/lib/core/theme/app_palette.dart`
  - `app/lib/core/theme/theme_controller.dart`
  - `app/lib/core/theme/app_theme.dart`

## 7. Migração recomendada

1. Remover uso progressivo de `AppColors` estático em favor do palette/token atual do tema.
2. Extrair componentes reutilizáveis (`MetricCard`, `CoachNarrativeCard`, `SegmentedTabBar`, `RunBottomNav`).
3. Criar tokens de tipografia, spacing, motion e chart.
4. Garantir paridade das quatro skins em telas críticas: `home`, `training`, `profile`, `active run`, `report`.
