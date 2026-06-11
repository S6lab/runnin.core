# Matriz de regras de geração de plano — v2 (DRAFT pra revisão)

> **Status: DRAFT.** Cada valor abaixo tem justificativa de 1 linha. Revisar
> valor a valor — editar direto na tabela. Aprovado ⇒ vira
> `plan-windows.constants.ts` v2 (fonte única) ⇒ exposto pelo endpoint
> `GET /plans/admissibility-config` ⇒ validators consomem ⇒ Fase D pluga a
> dimensão "medido vs declarado".
>
> **Regras de desenho** (fixas, não são valores a revisar):
> 1. Capacidade MEDIDA (assessment/corridas reais) pode LIBERAR células;
>    declarado sozinho nunca libera além do conservador.
> 2. Dias disponíveis cortam frequência antes de qualquer outra conta
>    (freq > dias = inválido na origem).
> 3. Rampa de volume ≤10%/sem (Pfitzinger); longão ≤30-35% do volume semanal;
>    distribuição 80/20 fácil/forte.

## Dimensões de ENTRADA

| Dimensão | Valores | Fonte hoje | Fonte na Fase D |
|---|---|---|---|
| Nível (subnível composto) | nunca_corri, esporádico, iniciante_freq, intermediário, avançado | declarado (level+levelHint) | declarado + reclassificação por runs observadas |
| Volume semanal | bucketizado: 0 / <10 / 10-20 / 20-35 / 35+ km/sem | declarado (`currentWeeklyKm`) | medido (28d de runs; drift >30% ⇒ usa conservador) |
| Longão recente | km (contínuo) | declarado (`capacityDistanceKm`) | medido (maior run 28d) |
| Pace base | min/km | declarado (`currentPaceMinKm`) | medido (assessment run / média runs) |
| Dias disponíveis | 1-7 | declarado | declarado |
| Idade | <40 / 40-54 / 55-64 / 65+ | perfil (birthDate) | perfil |
| Condições médicas | nenhuma / leve / séria / 3+ | perfil (lista canônica + texto livre) | perfil |

## SAÍDA 1 — Distâncias permitidas por subnível

Status: **LIB** (liberada) / **SAFE-ONLY** (só janela segura) / **BLOQ** (bloqueada) / **BLOQ→X** (bloqueada com redirect pra X).

| Subnível | 5K | 10K | 21K | 42K | Justificativa |
|---|---|---|---|---|---|
| nunca_corri | LIB | SAFE-ONLY | BLOQ→10K | BLOQ→21K | 21K+ sem base nenhuma = risco de lesão; 10K dá com C25K estendido mas só na janela longa |
| esporádico | LIB | SAFE-ONLY | BLOQ→10K *(v1: BLOQ)* | BLOQ→21K | base aeróbica frágil; v2 mantém 21K bloqueado mas com mensagem de redirect melhor |
| iniciante_freq | LIB | LIB | LIB (freq≥4) | BLOQ→21K | já corre regular: 21K cabe com 4x/sem; 42K exige base sustentada que iniciante não tem |
| intermediário | LIB | LIB | LIB (freq=3 ⇒ SAFE-ONLY) | LIB (freq≥4) | 15-30km/sem sustenta 21K; 42K com 3x/sem não fecha o volume de pico |
| avançado | LIB | LIB | LIB | LIB | base estruturada, decide sozinho |

**Modulação por evidência (Fase D)**: esporádico+10K sobe de SAFE-ONLY pra
FACTÍVEL com `observedWeeklyKm ≥ 12` por 4 semanas OU assessment ≥ 5K;
iniciante_freq+42K sai de BLOQ com `observedWeeklyKm ≥ 35` + longão ≥ 25K
observado (vira intermediário de facto).

## SAÍDA 2 — Janelas (semanas) por distância × nível

Formato: agressiva / factível / segura. `—` = modo não oferecido.
*(v1 atual entre parênteses quando a proposta muda)*

| Distância | Iniciante* | Intermediário | Avançado | Justificativa |
|---|---|---|---|---|
| 5K | 8 / 10 / 12 | 6 / 8 / 10 | 6 / 6 / 8 | C25K clássico = 9sem; avançado é formalidade |
| 10K | 10 / 12 / 14 | 8 / 10 / 12 | 6 / 8 / 10 | dobra do 5K pede +2-4sem de rampa |
| 21K | — / 16 / 20 | 12 / 14 / 18 | 10 / 12 / 14 | meia exige bloco de base + bloco específico; iniciante sem agressiva |
| 42K | — / — / 26 | 16 / 18 / 22 | 14 / 16 / 20 | maratona iniciante só no caminho longo; 16sem é o piso clássico (Pfitz 18/55 = 18) |

*Iniciante na tabela de janelas = `level=iniciante` (os 3 subníveis); o corte
fino por subnível acontece na SAÍDA 1 (bloqueio/safe-only), não nas semanas.

## SAÍDA 3 — Frequência mín/máx recomendada

| Subnível | 5K | 10K | 21K | 42K | Justificativa |
|---|---|---|---|---|---|
| nunca_corri | 2-3 | 3-4 | — | — | walk-run não sustenta 4+ sem lesão |
| esporádico | 2-4 | 3-4 | — | — | consolidar hábito antes de volume |
| iniciante_freq | 2-4 | 3-5 | 4-5 | — | 21K com <4 estoura km/sessão (cap 14km iniciante) |
| intermediário | 2-5 | 3-5 | 3-6 (3 ⇒ só safe) | 4-6 | 42K/3x = sessões de 15km+ médias, inviável |
| avançado | 2-6 | 3-6 | 3-7 | 4-7 | autonomia, cap por km/sessão (32km) segura o resto |

## SAÍDA 4 — Volume inicial S1

Regra única: `S1 = min(1.1 × volume_atual, piso_distância)` com
`volume_atual = max(declarado_validado, floor 5km)`.

| Distância-alvo | Piso S1 | Justificativa |
|---|---|---|
| 5K | 5 km/sem | walk-run from zero (C25K S1 ≈ 4-6km) |
| 10K | 8 km/sem | precisa fechar 10K na última semana partindo daqui em 10-14sem |
| 21K | 15 km/sem | abaixo disso a rampa de 10% não chega no pico 32 em 16-20sem |
| 42K | 25 km/sem | piso pra rampa alcançar 45km/sem em 22-26sem |

## SAÍDA 5 — Volume de pico (km/sem)

| Distância | Pico mínimo | Teto por nível (ini/int/av) | Justificativa |
|---|---|---|---|
| 5K | 0 (sem gate) | 25 / 35 / 50 | janela mínima já cobre; teto evita overshoot do LLM |
| 10K | 18 | 30 / 45 / 60 | completar 10K pede ~2× a distância na semana de pico |
| 21K | 32 | 40 / 55 / 75 | 1.5× da prova como volume de pico |
| 42K | 45 | 55 / 70 / 95 | "completar" permissivo (Pfitz sugere 50+; Galloway aceita menos) |

## SAÍDA 6 — Longão

| Regra | Valor | Justificativa |
|---|---|---|
| Progressão S1-S4 | ≤ 1.5 × longão recente declarado/medido | salto maior = principal preditor de lesão |
| Teto % do volume semanal | 35% (iniciante) / 40% (int/av em pico de 42K) | hoje o enforcer corta em 50% — apertar |
| Incremento semanal | ≤ +2km (ini) / +3km (int/av) | rampa do longão separada da rampa de volume |
| Longão máximo pré-prova | 21K: 18km · 42K: 30-32km | consenso: não correr a distância da prova antes da prova (exceto 5/10K) |
| Cutback | a cada 4ª semana, longão −30% | deload padrão de periodização |

## SAÍDA 7 — Melhora de pace máxima (% sobre pace atual, escala por semanas/12)

| Nível | % em 12sem (v1) | % v2 proposto | Justificativa |
|---|---|---|---|
| iniciante | 8.0 | 8.0 (manter) | destreinado responde rápido |
| intermediário | 5.0 | 5.0 (manter) | curva achatando |
| avançado | 3.0 | 3.0 (manter) | ganhos marginais; acima disso é promessa falsa |

Escala atual `clamp(weeks/12, 0.5, 1.5)` — manter.

## SAÍDA 8 — Base mínima exigida pra liberar a distância

Onde a Fase D pluga o "medido": qualquer linha satisfeita por MEDIÇÃO libera
a célula mesmo que o declarado seja menor.

| Distância | Base mínima (declarada OU medida) | Alternativa por assessment |
|---|---|---|
| 5K | nenhuma | — |
| 10K | 8 km/sem sustentado (2+ sem) | assessment ≥ 3K confortável |
| 21K | 20-25 km/sem sustentado (4 sem) | assessment ≥ 10K OU longão recente ≥ 12K |
| 42K | 35-40 km/sem sustentado (4 sem) + longão ≥ 25K | sem atalho — 42K não se libera por uma corrida só |

## Condições médicas e idade (transversal — modula janela, não bloqueia distância)

| Gatilho | Efeito | Justificativa |
|---|---|---|
| Condição séria (lista canônica `serious:true` + keywords) + 21K+ | força SEGURA | já é assim na v1 — manter |
| 3+ comorbidades + qualquer prova | força SEGURA | carga de monitoramento |
| ≥55 anos + 42K | mínimo FACTÍVEL | recuperação mais lenta |
| ≥65 anos + 21K | mínimo FACTÍVEL | idem |
| ≥65 anos + 42K | força SEGURA | idem |
| **NOVO** betabloqueador | zonas por FC viram zonas por pace/RPE no plano | FC não reflete esforço — hoje só vai pro prompt, formalizar |

---

## Perguntas abertas pro Eduardo (marcar na revisão)

1. **Esporádico + 21K**: v1 bloqueia seco. v2 propõe manter bloqueado mas o
   redirect explica o caminho (10K → 4 semanas observadas → libera 21K).
   Ok, ou prefere liberar SAFE-ONLY direto?
2. **Teto do longão** (SAÍDA 6): apertar o enforcer de 50% pra 35-40%?
   Mexe em planos novos apenas.
3. **Tetos de pico por nível** (SAÍDA 5): hoje não existem (só mínimos) — o
   LLM já é clampado por sessão, mas não por semana. Adicionar?
4. **Buckets de volume** (entrada): 0 / <10 / 10-20 / 20-35 / 35+ está bom
   ou prefere granularidade diferente?
