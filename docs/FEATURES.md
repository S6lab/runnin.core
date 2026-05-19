# Principais Funcionalidades do App

> Consolidação baseada em `PRODUCT_BLUEPRINT.md`, `ROADMAP.md`, `STACK.md` e `ARCHITECTURE.md`.
> Status em 2026-05-19.

---

## 1. Autenticação

- Login com Google (Google Sign-In)
- Login anônimo (acesso imediato sem cadastro)
- Login com telefone via OTP (SMS)
- Guarda de rotas — usuário não autenticado não acessa telas protegidas
- Logout

---

## 2. Onboarding

- Splash / tela de boas-vindas com proposta de valor
- Wizard multi-etapa com persistência local (Hive)
- Coleta de dados pessoais: nome, data de nascimento, peso, altura
- Nível atual do corredor (iniciante / intermediário / avançado)
- Meta principal (5K, 10K, meia, maratona, condicionamento, emagrecimento…)
- Frequência semanal de treino e horário preferido
- Condições de saúde e medicações
- Rotina de sono
- Pace alvo opcional
- Opção de conectar wearable no onboarding ou depois
- Geração automática do plano de treino pela IA ao final do wizard

---

## 3. Home / Dashboard

- Saudação contextual ao usuário
- Sessão do dia: tipo, distância, pace alvo e duração estimada
- Briefing textual do Coach para a sessão
- Inbox de notificações acionáveis:
  - melhor horário para correr
  - preparo nutricional pré-corrida
  - hidratação
  - checklist pré-run
  - sono e recovery
- Visão semanal resumida (dias treinados vs. planejados)
- Cards de performance (pace médio, distância semanal, calorias)
- Status corporal
- Última corrida com CTA de detalhes e compartilhamento
- Resumo semanal do Coach

---

## 4. Treino (Plano Semanal e Mensal)

- Plano semanal gerado e gerenciado por IA
- Periodização mensal por mesociclo
- Briefing de cada treino com zonas de esforço alvo
- Relatórios semanais de progresso
- Histórico de ajustes e revisões do plano
- Regra de uma revisão por semana (evita overfit de plano)
- Dicas de nutrição e mobilidade pré-corrida
- Visualização de sessões passadas e futuras

---

## 5. Corrida Ativa

- Seleção entre sessão do plano ou Free Run
- Tela de preparo (warmup, configuração de alertas)
- Integração com música (ducking de áudio durante voz do coach)
- Corrida ativa em tempo real:
  - timer de duração
  - pace em tempo real
  - distância percorrida
  - BPM (frequência cardíaca)
  - calorias estimadas
  - splits por quilômetro
- Mapa da rota (flutter_map + OpenStreetMap)
- GPS local-first: dados salvos no dispositivo (Hive), sincronizados ao finalizar
- Coach em tempo real por voz (TTS streaming, Dual-LLM):
  - eventos de km atingido
  - alerta de pace
  - respostas a perguntas do corredor
- Pausar e retomar corrida
- Finalizar corrida com confirmação
- Integração com wearables via Health Connect (Android) e HealthKit (iOS)

---

## 6. Pós-corrida e Relatório

- Resumo imediato pós-corrida (distância, duração, pace médio, BPM médio)
- Relatório detalhado gerado por IA (LLM assíncrono)
- Splits por quilômetro
- Distribuição de zonas cardíacas
- Benchmark comparativo
- Conquistas e XP ganhos na corrida
- Compartilhamento do resultado (share card)

---

## 7. Coach IA

- Coaching em tempo real durante a corrida (modelo rápido, streaming SSE)
- Chat assíncrono com o Coach fora da corrida
- Relatório pós-corrida com análise e sugestões (modelo grande, async)
- Voz sintetizada (Google Neural2 TTS, PT-BR)
- Notificações inteligentes fora da corrida (FCM)
- Ajustes de persona do Coach: frequência de fala, idioma, autoajuste de plano
- Dual-LLM: Gemini / Groq (real-time) + Gemini / Together AI (análise assíncrona)

---

## 8. Histórico e Analytics

- Listagem paginada de corridas passadas
- Filtros por aba: dados, corridas, benchmark
- Filtros de período: semana, mês, 3 meses
- Totais consolidados (distância, tempo, calorias)
- Distribuição de zonas cardíacas agregadas
- Volume semanal (gráfico)
- Tendência de pace ao longo do tempo
- Tendência de BPM ao longo do tempo
- Resumo evolutivo com análise do Coach

---

## 9. Perfil, Saúde e Ajustes

- Resumo do usuário (nome, nível, meta)
- Estatísticas: streak, XP total, badges desbloqueados, distância total
- Condições de saúde e medicações cadastradas
- Skin / theme switcher (múltiplas identidades visuais)
- Edição de perfil (nome, nível, meta, frequência, horário)
- Menu para gamificação, saúde e ajustes avançados
- Ajustes de voz e persona do Coach
- Configuração de alertas de corrida padrão
- Configuração de notificações fora da corrida
- Unidades (km/mi, kg/lb)
- Vibração, integração musical, exportação de dados
- Configurações de privacidade
- Preview de notificações
- Upload de exames médicos (planejado)
- Status e configuração de wearable

---

## 10. Gamificação

- Sistema de XP ganho por corridas e metas atingidas
- Níveis de progressão baseados em XP
- Galeria de badges (bloqueados e desbloqueados)
- Regras de desbloqueio de badges (distância total, streak, tipos de corrida…)
- Calendário de streak (dias consecutivos treinados)
- Progresso visual por badge

---

## Módulos planejados / em roadmap

| Módulo | Status |
|--------|--------|
| Notificações push inteligentes | Parcialmente implementado |
| Gamificação completa | Planejado |
| Integração Wearables (BLE Polar) | Planejado |
| Exames médicos e saúde avançada | Planejado |
| Billing / Premium / Freemium gate | Planejado |
| Multi-tenant / white-label | Planejado |
| Exportação de dados | Planejado |

---

*Veja também: [PRODUCT_BLUEPRINT.md](PRODUCT_BLUEPRINT.md) (mapa funcional completo) e [../ROADMAP.md](../ROADMAP.md) (status de implementação).*
