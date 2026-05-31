# RUN JOURNEY — Addendum: gate de tipo de corrida por assinatura

> Regra de produto alinhada em 2026-05-16. Complementa `RUN_JOURNEY.md` (não substitui).

## Regra

A escolha do tipo de corrida no fluxo de prep/start é gated pelo tier de assinatura:

| Tier      | Opções de corrida disponíveis                                          |
| --------- | ---------------------------------------------------------------------- |
| Freemium  | **Free Run** apenas                                                    |
| Premium   | **Sessão do plano** (workout prescrito de hoje) **ou Free Run**        |

Quando um usuário Premium escolhe **Free Run**, o Coach.AI **ajusta a próxima sessão planejada** com base no que foi efetivamente corrido (distância, pace, BPM). Free Run no Premium é, portanto, uma corrida livre porém *contabilizada* no plano.

Free Run no Freemium é só "gravar a corrida" — sem coach, sem plano, sem feedback adaptativo.

## UI implications (prep / home)

### Home — botão "INICIAR CORRIDA"
- **Freemium**: tap → vai direto pro `/prep` em modo `runType: free_run`. Não mostra card "SESSÃO DO PLANO". Pode mostrar banner "Assine pra desbloquear sessões guiadas".
- **Premium**: mostra card "SESSÃO DO PLANO" (com nome do workout, distância, pace alvo, badge "RECOMENDADO") + opção alternativa "Free Run" mais discreta.

### Prep page (`/prep`)
- Briefing, mobilidade, alertas e música são mostrados **apenas** quando `runType: planned`. Em Free Run o prep é minimalista (start + opção rápida de alertas).
- Toggle no topo "Plano | Free Run" só aparece se `premium == true`.

### Backend
- `POST /runs` deve rejeitar `runType: 'planned'` quando o caller é freemium (retornar `403 PREMIUM_REQUIRED`).
- Re-balanceamento da próxima sessão planejada quando Premium completa Free Run: lógica futura (não no escopo atual).

## Visuais de referência

Mockups compartilhados em 2026-05-16:
- Home com card "SESSÃO DO PLANO · Easy Run · 5K · 6:30/km · RECOMENDADO"
- Prep completo (briefing Coach.AI, 8 exercícios de mobilidade, 5 toggles de alertas, seleção de app de música)
- Relatório pós-corrida com splits + zonas cardíacas + benchmark "TOP 25%" + conquistas
- Overlay "CONQUISTA DESBLOQUEADA · PACE SUB-5:30 · +30 XP"
- Share page com variantes CARD e CÂMERA + OVERLAY (toggles Pace/Distância/Tempo/BPM/Streak/Plano/Trajeto/Splits/Coach)

Todos os visuais estão **conforme** o spec atual de `RUN_JOURNEY.md` — a única mudança nova é o gate de tier acima.
