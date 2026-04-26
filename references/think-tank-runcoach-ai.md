# RunCoach AI — Think Tank (Enriquecimento Técnico)

> Documento de referência técnica para o time de desenvolvimento.
> Organizado por: jornada do corredor → funcionalidade → soluções técnicas possíveis.
> Última atualização: março 2026 (Etapa 1.8 — Gate de Potencial: GO ✅ 79/90)

---

## Índice

1. [Pipeline do Coach IA — Visão Geral](#1-pipeline-do-coach-ia--visão-geral)
2. [Decisão Técnica: LLM (cérebro do Coach)](#2-decisão-técnica-llm-cérebro-do-coach)
3. [Decisão Técnica: TTS (voz do Coach)](#3-decisão-técnica-tts-voz-do-coach)
4. [Decisão Técnica: Arquitetura por Feature P0](#4-decisão-técnica-arquitetura-por-feature-p0)
5. [Decisão Técnica: Backend/Infra](#5-decisão-técnica-backendinfra)
6. [Stack Consolidada](#6-stack-consolidada)
7. [Modelo Financeiro — Validação de Custos (Etapa 1.8)](#7-modelo-financeiro--validação-de-custos-etapa-18)

---

## 1. Pipeline do Coach IA — Visão Geral

O Coach IA é a killer feature. Tudo gira em torno dele. Entender o pipeline é pré-requisito pra entender as decisões de LLM e TTS.

### Jornada do corredor × tecnologia envolvida

```
┌─────────────────────────────────────────────────────────────────┐
│                    ANTES DA CORRIDA                              │
│                                                                  │
│  Corredor abre app → configura treino → Coach gera plano        │
│                                                                  │
│  Tech: LLM (modelo grande) gera plano personalizado             │
│  Latência: não-crítica (pode levar 3-5s, corredor está parado)  │
│  Dados: histórico, onboarding, Health Connect                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    DURANTE A CORRIDA                             │
│                                                                  │
│  GPS rastreia → eventos (km, pace, timer) → Coach fala          │
│  Corredor pode perguntar por voz → Coach responde               │
│                                                                  │
│  Tech: LLM (modelo rápido) + TTS (streaming) + STT (nativo)    │
│  Latência: CRÍTICA — total < 2s, ideal < 1s                     │
│  Pipeline: evento → LLM gera texto → TTS sintetiza → fala      │
│  Áudio: duck audio (abaixa música, Coach fala, volta música)    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    DEPOIS DA CORRIDA                             │
│                                                                  │
│  Coach gera relatório completo + benchmark + próximo treino     │
│                                                                  │
│  Tech: LLM (modelo grande) analisa dados completos da corrida   │
│  Latência: não-crítica (corredor parou, pode levar 5-10s)       │
│  Output: texto + cards visuais compartilháveis                  │
└─────────────────────────────────────────────────────────────────┘
```

### Implicação arquitetural: dois "modos" de LLM

| Modo | Quando | Requisito | Modelo ideal |
|------|--------|-----------|-------------|
| **Fast** | Durante corrida | Latência < 1s, respostas curtas | Modelo pequeno/rápido (8B-32B) |
| **Deep** | Antes/depois corrida | Qualidade máxima, análise completa | Modelo grande (70B+) |

Esta é a **arquitetura dual** — não é opcional, é consequência da jornada do corredor.

---

## 2. Decisão Técnica: LLM (cérebro do Coach)

### Por que essa decisão importa

O LLM é o cérebro. Se ele é lento, o Coach irrita. Se ele é burro, o Coach dá conselho ruim. Se ele é caro, o negócio não fecha. As três variáveis que importam:

1. **Latência** — durante corrida, < 1-2s total (LLM + TTS)
2. **Qualidade em PT-BR** — o corredor fala português, o Coach tem que responder bem
3. **Custo** — com 1.000 runners a R$ 14,90/mês, a conta de LLM precisa caber na margem

### Cenário atual do mercado (março 2026)

O mercado de LLMs mudou radicalmente. Modelos open source chineses (Qwen, DeepSeek) alcançaram e em alguns benchmarks superaram os modelos proprietários ocidentais, a uma fração do custo. Preços caíram ~80% de 2025 pra 2026.

### Todas as opções avaliadas

#### Modelos comerciais (APIs proprietárias)

| Modelo | Provider | Input/1M tokens | Output/1M tokens | Latência (TTFT) | PT-BR | Notas |
|--------|----------|-----------------|-------------------|------------------|-------|-------|
| **Gemini 2.5 Flash** | Google | $0.30 | $2.50 | ~200ms, 236 tok/s | Bom | Ecossistema Google, mas mais caro que parece |
| **Gemini 2.5 Flash-Lite** | Google | $0.10 | $0.40 | Rápida | Bom | Versão budget — mais barato que Flash |
| **Gemini 3 Flash** | Google | $0.50 | $3.00 | Rápida | Bom | Mais recente (mar 2026) |
| **GPT-5 Mini** | OpenAI | ~$0.40 | ~$1.60 | Média | Muito bom | Boa qualidade, preço médio |
| **Claude Haiku 4.5** | Anthropic | ~$0.80 | ~$4.00 | Rápida | Muito bom | Excelente qualidade, preço mais alto |

#### Modelos open source via API (providers americanos)

| Modelo | Provider(s) | Input/1M tokens | Output/1M tokens | Latência | PT-BR | Licença |
|--------|-------------|-----------------|-------------------|----------|-------|---------|
| **Qwen3-32B** | Groq | ~$0.20 | ~$0.60 | ~0.5s TTFT, ~397 tok/s | Bom | Apache 2.0 |
| **Qwen3-8B** | Groq/Together | ~$0.06 | ~$0.09 | Sub-segundo | Razoável | Apache 2.0 |
| **Qwen 2.5-14B** | Together/Groq | ~$0.12 | ~$0.80 | Rápida | Bom (melhor que 8B) | Apache 2.0 |
| **Qwen 3.5-35B-A3B** | Alibaba Cloud | ~$0.10 | ~estimado | Rápida (3B ativos) | Bom (201 idiomas) | Apache 2.0 |
| **Qwen 3.5-397B-A17B** | Alibaba Cloud | ~$0.18/1M ctx | — | Rápida (17B ativos) | Bom | Apache 2.0 |
| **DeepSeek V3.2** | Together/Fireworks | $0.14 | $0.28 | 1-3s (chat) | Bom | MIT |
| **DeepSeek V4** | DeepSeek API | A definir | A definir | A definir | A definir | Apache 2.0 (esperado) |
| **DeepSeek R1 Distill 32B** | Groq | ~$0.29 | ~$0.99 | Boa | Bom | MIT |
| **Llama 4 Maverick** | Groq | ~$0.20 | ~$0.60 | 0.50s TTFT | Bom | Meta |
| **GLM-4.7** | — | A definir | A definir | — | Incerto | Open source |
| **Kimi K2** | Groq | ~$0.59 | ~$3.00 | — | Incerto | — |

### Análise crítica por critério

#### 1. Latência — o que realmente importa durante a corrida

O corredor está em movimento. O Coach precisa falar em < 2 segundos (LLM gera texto + TTS sintetiza voz). Isso significa que o LLM precisa entregar o primeiro token em < 500ms e gerar a frase completa (~30-50 tokens) em < 1s.

| Modelo | TTFT | Throughput | Frase de ~40 tokens em... | Cabe no budget de latência? |
|--------|------|-----------|---------------------------|----------------------------|
| Qwen3-8B via Groq | ~200ms | ~400+ tok/s | **~300ms** | ✅ Sobra |
| Qwen3-32B via Groq | ~500ms | ~397 tok/s | **~600ms** | ✅ Cabe |
| Llama 4 Maverick via Groq | ~500ms | ~400 tok/s | **~600ms** | ✅ Cabe |
| DeepSeek V3.2 (chat) | ~1-3s | ~40 tok/s | **~2-4s** | ⚠️ No limite / estoura |
| Gemini 2.5 Flash | ~200ms | ~236 tok/s | **~370ms** | ✅ Cabe |
| GPT-5 Mini | ~400ms | ~80 tok/s | **~900ms** | ✅ Cabe mas justo |

**Conclusão:** Para coaching real-time, Groq (LPU) é imbatível em latência. DeepSeek V3.2 direto é lento demais para falar DURANTE a corrida — serve para antes/depois.

#### 2. Qualidade em PT-BR — a verdade sem romantismo

Os benchmarks de LLMs (MMLU, HumanEval, etc.) são quase todos em inglês. A realidade em PT-BR:

- **Tokenizer ineficiente:** "Qual é a capital do Brasil?" = 12 tokens em Qwen (vs 8 em inglês). Custa ~50% mais e pode perder nuance
- **Benchmark Napolab (PT-BR nativo):** Qwen3-235B e Llama 3.1 8B lideram entre open source
- **Benchmark Revalida (medicina BR):** GPT-4o (86.8%) > Claude Opus (83.8%) > Llama 3 70B (77.5%) > Llama 3 8B (53.9%)
- **Na prática para coaching de corrida:** A linguagem é simples ("pace 5:42, tá no ritmo, hidrate-se"). Modelos 8B+ dão conta. Não é tradução literária

**Mitigações:**
- System prompt em PT-BR com vocabulário específico de corrida
- Exemplos few-shot no prompt ("diga 'pace' não 'ritmo por quilômetro'")
- Modelos maiores (14B+) se saem melhor que 7-8B em português
- Fine-tune comunitário existe: DeepSeek-R1-Distill-Qwen-7B-Multilingual

**Objeção honesta:** Se o corredor fizer uma pergunta complexa em português ("explica a diferença entre treino intervalado e fartlek"), um modelo 8B pode dar resposta genérica. Modelo 32B+ dá resposta melhor. A arquitetura dual resolve isso — modelo rápido pra frases curtas, modelo grande pra perguntas complexas.

#### 3. Custo — projeção real

**Premissas:** 1.000 runners, 3 corridas/semana, ~25 interações por corrida (modelo rápido) + 2 interações longas (plano + relatório, modelo grande)

**Modelo rápido (durante corrida):**
- 1.000 × 3 × 25 × ~300 tokens = ~22.5M tokens/semana = ~90M tokens/mês

| Modelo rápido | Custo/mês (90M tokens) | Em R$ |
|---------------|----------------------|-------|
| Qwen3-8B via Groq | ~$8-13 | ~R$ 50-80 |
| Qwen3-32B via Groq | ~$50-70 | ~R$ 300-420 |
| Gemini 2.5 Flash-Lite | ~$37-45 | ~R$ 220-270 |
| Gemini 2.5 Flash | ~$250+ | ~R$ 1.500+ |
| GPT-5 Mini | ~$140+ | ~R$ 840+ |

**Modelo grande (antes/depois corrida):**
- 1.000 × 3 × 2 × ~1.500 tokens = ~9M tokens/semana = ~36M tokens/mês

| Modelo grande | Custo/mês (36M tokens) | Em R$ |
|---------------|----------------------|-------|
| DeepSeek V3.2 | ~$15 | ~R$ 90 |
| Qwen 3.5-397B | ~$20-30 | ~R$ 120-180 |
| Gemini 2.5 Flash | ~$100 | ~R$ 600 |
| GPT-5 Mini | ~$70 | ~R$ 420 |

**Custo total combinado (1.000 runners):**

| Combinação | Custo/mês | Em R$ |
|-----------|-----------|-------|
| **Qwen3-8B + DeepSeek V3.2** | ~$23-28 | **~R$ 140-170** |
| **Qwen3-32B + DeepSeek V3.2** | ~$65-85 | **~R$ 390-510** |
| **Gemini Flash-Lite + Gemini Flash** | ~$137 | **~R$ 820** |
| **GPT-5 Mini (ambos)** | ~$210+ | **~R$ 1.260+** |

**Receita de 1.000 Premium:** R$ 14.900/mês. Custo de LLM com Qwen+DeepSeek: ~1% da receita. Com Gemini: ~5.5%. Com GPT: ~8.5%.

#### 4. Open source vs proprietário — objeções e corroborações

**"Open source é arriscado, pode sumir"**
- Parcialmente verdade. Coqui (XTTS-v2) fechou em 2025. Mas Qwen (Alibaba) e DeepSeek têm bilhões de funding. Qwen 3.5 acabou de sair (fev 2026). Risco de abandono é baixo a médio prazo
- Mitigação: a camada de abstração permite trocar modelo em horas

**"DeepSeek manda dados pra China"**
- Verdade — a API DIRETA do DeepSeek roteia por servidores chineses. Vários governos baniram
- Solução: usar DeepSeek via providers americanos (Groq, Together AI, Fireworks). Mesmos modelos, servidores nos EUA
- Isso resolve o problema de compliance pra dados de saúde/fitness

**"Gemini é mais seguro porque é Google"**
- Verdade operacional: mesmo ecossistema (Flutter, Firebase, billing). Menos fornecedores pra gerenciar
- Mas custa 5-10x mais. Pra um app white-label vendido a operadoras, margem importa
- E vendor lock-in é real — se Google muda preço, você não tem alternativa

**"Self-hosting economiza dinheiro"**
- Falso no volume esperado. GPU A10G na AWS = ~R$ 5.400/mês (24h). Para 1K users, API custa R$ 140-510/mês
- Self-hosting só compensa com 50K+ usuários (15-40M tokens/mês segundo análise de mercado)
- E exige expertise de infra que founder solo não tem

**"Precisa de fine-tuning pra coaching de corrida?"**
- Provavelmente não no MVP. System prompt bem escrito + few-shot examples resolve 90% dos casos
- Fine-tuning faz sentido depois, com dados reais de conversas Coach-corredor
- Modelos open source (Qwen, DeepSeek) permitem fine-tune. Proprietários não (ou cobram caro)

#### 5. DeepSeek V4 — vale esperar?

DeepSeek V4 está prestes a ser lançado (mar 2026). Promessas: 1T parâmetros, 1M contexto, hybrid reasoning/chat, Apache 2.0. Se cumprir, será o modelo open source mais poderoso.

**Recomendação:** Não esperar — construir com o que existe (Qwen 3.5 / DeepSeek V3.2) e migrar se V4 entregar. A camada de abstração existe pra isso.

#### 6. Resumo e recomendação

**Para o PROTÓTIPO (0-100 users):**
- Gemini 2.5 Flash-Lite — free tier generoso, mesmo ecossistema, zero config extra
- OU Qwen3-32B via Groq — pra já validar a stack open source

**Para o APP (1K+ users):**

| Papel | Recomendação primária | Alternativa | Por quê |
|-------|----------------------|-------------|---------|
| **Modelo rápido** (durante corrida) | Qwen3-32B via Groq | Qwen3-8B via Groq (mais barato) | Sub-segundo, $0.20/1M, PT-BR aceitável |
| **Modelo grande** (antes/depois) | DeepSeek V3.2 via Together AI | Qwen 3.5-397B via Alibaba | $0.14/1M, qualidade GPT-4o, dados nos EUA |
| **Fallback** | Gemini 2.5 Flash-Lite | — | Se open source der problema, Google resolve |

**Regras obrigatórias:**
1. **Camada de abstração de LLM** — trocar modelo = mudar config, não código
2. **Providers americanos** (Groq, Together, Fireworks) — nunca API direta da China pra dados de saúde
3. **System prompt em PT-BR** com vocabulário de corrida
4. **Monitorar DeepSeek V4** — migrar se entregar o prometido

---

## 3. Decisão Técnica: TTS (voz do Coach)

### Por que essa decisão importa

O Coach precisa falar. Sem TTS, não tem Coach em tempo real — só texto na tela (que corredor não vai ler correndo). O TTS converte o texto gerado pelo LLM em áudio que toca no fone do corredor.

**Restrição crítica:** O TTS soma latência em cima do LLM. Se o LLM leva 500ms e o TTS leva 500ms, são 1s total. Cada milissegundo conta.

### Pipeline completo de voz

```
COACH FALA (inevitável — custa dinheiro):
Evento (km/pace) → LLM gera texto → TTS converte em áudio (streaming) → duck audio → fala no fone
                                                                                        │
CORREDOR RESPONDE (grátis):                                                             ▼
                                                                              janela de mic (curta)
                                                                                        │
                                            STT nativo do celular (iOS/Android built-in, custo zero)
                                                                                        │
                                                                              texto → manda pro LLM
```

**Otimização crítica:** Usar **streaming TTS** — o LLM gera tokens em stream, e o TTS começa a sintetizar a primeira frase enquanto o resto ainda está sendo gerado. Isso corta a latência percebida pela metade.

### Todas as opções avaliadas

#### APIs comerciais

| Provider | Latência (TTFA) | Custo/1M chars | PT-BR | Qualidade | Streaming | Notas |
|----------|-----------------|----------------|-------|-----------|-----------|-------|
| **Google Cloud TTS Neural2** | 200-400ms | $16 | Sim, ~6 vozes BR | Boa, "limpa" | Sim | Mesmo ecossistema Firebase/Flutter. Free tier: 1M chars/mês grátis (WaveNet) |
| **Google Cloud TTS Chirp 3 HD** | 200-400ms | $30 | Sim | Superior ao Neural2, 30+ estilos | Sim | Vozes emocionais, mais natural |
| **Azure Neural TTS** | 200-400ms | $16 | Sim, 10+ vozes BR | Muito boa entonação | Sim | Free tier: 500K chars/mês. Muitas vozes PT-BR |
| **Azure HD V2** | 200-400ms | $30 | Sim | Emoção context-aware automática | Sim | Ajusta tom sozinho baseado no texto |
| **OpenAI TTS** | ~500ms | $15 (standard) / $30 (HD) | Sim, genérico | Natural, 6 vozes | Sim | Boa mas sem customização de sotaque BR |
| **OpenAI gpt-4o-mini-tts** | ~300-500ms | ~$12/1M tokens audio | Sim, "steerable" | Controle de tom via prompt | Sim | Novo — controla emoção por texto |
| **ElevenLabs** | 300-800ms | ~$30-60 (plano) | Excelente | Top do mercado em naturalidade | Sim | Caro. Faz sentido pra audiobook, não pra "pace 5:42" |
| **Cartesia Sonic 3** | **40-90ms** | ~$50 | Sim (15 idiomas) | Alta, feita pra real-time | Sim | Imbatível em latência. Arquitetura SSM (não transformer) |
| **Groq Orpheus TTS** | ~100ms+ | $50/1M chars | Inglês (PT-BR limitado) | Expressiva, controle de emoção | Sim | Substituiu PlayAI no Groq. Foco em inglês por enquanto |

#### Open source (self-hosted)

| Modelo | Latência | PT-BR | Qualidade | Licença | Precisa GPU? | Status |
|--------|----------|-------|-----------|---------|-------------|--------|
| **Coqui XTTS-v2** | ~1-3s (GPU) | Sim, nativo | Perto de comercial | CPML | Sim (forte) | Empresa fechou (dez/2025). Código open, sem manutenção |
| **Fish Speech 1.5** | <150ms (GPU) | Sim | Alta | Apache 2.0 | Sim | Ativo, bons benchmarks |
| **F5-TTS pt-br** | Moderado | **Fine-tuned BR** (130h+) | Boa | MIT | Sim | Específico pra BR — único modelo fine-tuned |
| **Kokoro-82M** | Rápido | 3 vozes BR (1F, 2M) | Incerta em PT-BR | Apache 2.0 | GPU leve | Pequeno, #1 no TTS Arena em inglês |
| **Parler TTS Mini** | Moderado | PT genérico (não BR) | Boa em EN/EU | Apache 2.0 | Sim | Hugging Face. Sem fine-tune BR |
| **Piper** | 50-100ms | Fraco | Robótico | MIT | Não (CPU) | Muito leve, mas qualidade inaceitável pra premium |
| **MeloTTS** | Rápido | Limitado | Média | MIT | CPU possível | Leve, mas PT-BR fraco |

### Análise crítica

#### 1. Open source é mais barato? — A conta real

**Mito:** "Open source é grátis, logo é mais barato."

**Realidade:** É grátis de licença, caro de infra. Para rodar XTTS-v2 ou Fish Speech com latência aceitável, precisa de GPU dedicada.

| Cenário | Custo mensal |
|---------|-------------|
| 1x GPU A10G AWS (24h) | ~R$ 5.400 |
| 2x GPU (redundância) | ~R$ 10.800 |
| Google Neural2 API (30M chars/mês) | ~R$ 2.880 |
| Azure Neural API (30M chars/mês) | ~R$ 2.880 |

**Self-hosted é 2-4x mais caro** que API comercial para 1.000 usuários. Só compensa com 50K+ users E equipe de infra dedicada.

#### 2. Qualidade PT-BR — ranking honesto

1. **ElevenLabs** — melhor naturalidade, melhor sotaque BR. Mas caro
2. **Azure Neural / HD V2** — 10+ vozes BR, entonação muito boa, context-aware
3. **Google Chirp 3 HD** — melhorou muito, 30 estilos, emoção natural
4. **Google Neural2** — sólido, funcional, "limpo demais" (parece locutora de aeroporto)
5. **OpenAI TTS** — natural mas genérico, sem customização de sotaque BR
6. **Cartesia Sonic 3** — boa mas menos vozes BR que Google/Azure
7. **XTTS-v2 / Fish Speech** — funcional em PT-BR mas sem suporte ativo
8. **F5-TTS pt-br** — único fine-tuned BR, mas modelo pequeno
9. **Kokoro/Parler/Piper** — insuficiente pra produto premium em PT-BR

#### 3. Projeção de custo (1.000 runners)

**Premissas:** 3 corridas/semana, ~25 falas do Coach/corrida, ~100 chars por fala

Cálculo: 1.000 × 3 × 25 × 100 = 7.5M chars/semana = **~30M chars/mês**

| Provider | Custo/mês (30M chars) | Em R$ |
|----------|----------------------|-------|
| Google Neural2 ($16/1M) | $480 | **~R$ 2.880** |
| Azure Neural ($16/1M) | $480 | **~R$ 2.880** |
| OpenAI Standard ($15/1M) | $450 | **~R$ 2.700** |
| Google Chirp 3 HD ($30/1M) | $900 | **~R$ 5.400** |
| Cartesia Sonic 3 (~$50/1M) | $1.500 | **~R$ 9.000** |
| ElevenLabs (Scale) | ~$1.200 | **~R$ 7.200** |
| Self-hosted (GPU) | ~$1.100-2.200 | **~R$ 6.600-13.200** |

**Receita de 1.000 Premium (R$ 14.900/mês).** TTS com Google/Azure = ~19% da receita. Com Cartesia = ~60%. Com self-hosted = ~44-88%.

**Conclusão dura:** TTS é o custo mais pesado do Coach IA. LLM custa ~R$ 170/mês, TTS custa ~R$ 2.700-2.880/mês. A voz do Coach é 15-20x mais cara que o cérebro.

#### 4. A conta fecha?

| Item | Custo/mês (1K users) | % da receita (R$ 14.900) |
|------|---------------------|--------------------------|
| LLM (Qwen + DeepSeek) | ~R$ 170 | 1.1% |
| TTS (Google Neural2) | ~R$ 2.880 | 19.3% |
| **Total IA** | **~R$ 3.050** | **20.5%** |
| Firebase/infra (estimado) | ~R$ 500-1.000 | 3-7% |
| **Total tech** | **~R$ 3.550-4.050** | **24-27%** |
| **Margem bruta** | **~R$ 10.850-11.350** | **73-76%** |

Margem saudável. Mas note: TTS é o vilão da conta. Otimizar TTS = otimizar margem.

**Otimizações possíveis de TTS:**
- Reduzir falas do Coach (menos é mais — corredor não quer ser bombardeado)
- Frases mais curtas (100 chars → 60 chars = 40% menos custo)
- Cache de frases comuns ("primeiro quilômetro", "mantenha o ritmo") — gera 1x, reutiliza
- Início com Google Neural2, migrar pra solução mais barata se surgir

### Resumo e recomendação TTS

**Para o PROTÓTIPO (0-100 users):**
- **Google Cloud TTS Neural2** — free tier (1M chars/mês grátis), zero fricção, mesmo ecossistema
- Ou **Azure Neural** — free tier (500K chars/mês), mais vozes BR

**Para o APP (1K+ users):**

| Cenário | Escolha | Custo | Por quê |
|---------|---------|-------|---------|
| **Default** | Google Neural2 | R$ 2.880/mês | Melhor custo-benefício, ecossistema unificado |
| **Se qualidade de voz não satisfizer** | Google Chirp 3 HD ou Azure HD V2 | R$ 5.400/mês | Vozes mais naturais, emoção automática |
| **Se latência for problema** | Cartesia Sonic 3 | R$ 9.000/mês | 40-90ms imbatível, mas caro |
| **Escala (50K+ users)** | Reavaliar Fish Speech / F5-TTS (self-hosted) | Depende | Só quando tiver equipe de infra |

**Descartes com justificativa:**
- **ElevenLabs:** melhor voz, mas custo não se justifica pra frases curtas de coaching
- **Open source self-hosted:** mais caro que API até 50K users, sem equipe de infra = suicídio operacional
- **Piper/MeloTTS:** qualidade insuficiente pra produto premium
- **Kokoro/Parler em PT-BR:** imaturo, sem benchmarks confiáveis
- **Groq Orpheus:** foco em inglês, PT-BR não suportado adequadamente

**Regras obrigatórias:**
1. **Camada de abstração de TTS** — mesma lógica do LLM. Trocar provider = mudar config
2. **Streaming TTS desde o dia 1** — LLM gera em stream, TTS sintetiza em paralelo
3. **Cache de frases comuns** — reduz custo em 20-30%
4. **Monitorar open source** — Fish Speech e F5-TTS evoluem rápido, PT-BR pode melhorar

---

## 4. Decisão Técnica: Arquitetura por Feature P0

Cada feature P0 tem decisões técnicas próprias. Mapeamento feature por feature: o que faz, como implementa, quanto custa, e onde estão as armadilhas.

### Feature 1: GPS Tracking + Mapa em Tempo Real

**O que faz:** Rastreia a corrida, mostra rota no mapa, calcula pace/distância/tempo.

#### Opções técnicas

| Componente | Solução | Alternativa | Custo |
|-----------|---------|-------------|-------|
| GPS | Plugin `geolocator` (grátis, padrão Flutter) | `flutter_background_geolocation` (pago, mais robusto) | $0 ou ~$300 licença única |
| Mapa | Google Maps SDK (Flutter) | Mapbox (mais customizável, mais caro) | Google: grátis até 28K loads/mês |
| Background tracking | `flutter_background_service` | Nativo (mais confiável, mais trabalho) | $0 |
| Persistência local | Hive (leve, rápido) | SQLite (mais estruturado) | $0 |

#### Armadilhas

- **Bateria:** GPS ligado por 1-2h drena bateria. Precisa de lógica adaptativa — atualizar a cada 1-3s (não a cada 100ms). Filtro de distância (só registrar se moveu >5m)
- **GPS noise:** Em áreas urbanas, GPS "pula". Precisa de GPS Jump Detection (ignorar pontos com erro >15m) e Speed Smoothing (suavizar variações bruscas de pace)
- **iOS é agressivo:** Mata processos em background. Precisa de permissão "Always" + Background Modes habilitados. Se não fizer certo, o tracking para no meio da corrida
- **Custo real:** Praticamente zero. GPS é nativo, Google Maps tem free tier generoso. Feature mais barata de todas

#### Objeção honesta

Todo app de corrida faz isso. Não é diferencial. Mas é infraestrutura obrigatória — sem GPS, não existe app de corrida. O diferencial está nas camadas em cima (Coach, gamificação).

#### Arquitetura recomendada (2026)

Abordagem Clean Architecture + BLoC com lógica adaptativa:
- **GPS Jump Detection** — ignorar pontos com accuracy >15m
- **Speed Smoothing** — suavizar variações bruscas (média móvel de 3 pontos)
- **Adaptive Battery Logic** — ajustar frequência de GPS baseado em velocidade e nível de bateria
- **Local Persistence** — trail completo em Hive pra auditoria e reconstrução de rota

---

### Feature 2: Coach IA (Pipeline Completo)

**O que faz:** Monta plano, fala durante corrida, gera relatório depois.

**Decisões de LLM e TTS já detalhadas nas seções 2 e 3.** Arquitetura consolidada:

```
┌──────────────────────────────────────────────┐
│              COACH IA — PIPELINE              │
│                                               │
│  [Antes]  Onboarding data + histórico         │
│     → LLM Grande gera plano de treino         │
│     → Salva no Firestore                      │
│                                               │
│  [Durante] GPS event (km, pace, timer)        │
│     → Context builder (dados + plano + perfil)│
│     → LLM Rápido gera frase curta             │
│     → TTS streaming → áudio no fone           │
│     → (opcional) mic → STT nativo → LLM       │
│                                               │
│  [Depois]  Dados completos da corrida         │
│     → LLM Grande gera relatório               │
│     → Card visual gerado no Flutter           │
│     → Salva + disponibiliza pra compartilhar  │
└──────────────────────────────────────────────┘
```

#### Componente-chave: Context Builder

O "montador de contexto" — pega dados do GPS, perfil do corredor, plano do treino, e monta o prompt pro LLM. Sem isso, o LLM recebe dados crus e dá respostas genéricas.

| Componente | Implementação |
|-----------|---------------|
| Context Builder | Cloud Function ou lógica local (monta prompt) |
| Fila de mensagens | Stream local (eventos GPS → fila → LLM) |
| Estado da corrida | BLoC/Riverpod (pace atual, km, alertas pendentes) |
| Cache de áudio | Frases comuns pré-geradas (TTS 1x, reusa) |

**Custo:** Já detalhado nas seções 2 e 3 — ~R$ 3.050/mês para 1K users (LLM + TTS).

---

### Feature 3: Onboarding Assessment

**O que faz:** Corredor responde perguntas visuais (nível, idade, frequência, distância, objetivos). Alimenta o Coach desde o dia 1.

#### Implementação

| Componente | Solução | Notas |
|-----------|---------|-------|
| UI | Flutter widgets (sliders, seletores visuais, cards de escolha) | Tipo Duolingo/Headspace — visual, não formulário |
| Storage | Firestore (perfil do usuário) | Documento único por user |
| Lógica | Simples — salva respostas, alimenta system prompt do Coach | Sem LLM aqui |

**Custo:** Praticamente zero. É UI + Firestore write.

#### Armadilha: design, não código

Se o onboarding for longo demais (>5 telas), o corredor desiste antes de começar. Nike Run Club pede 3 coisas e pronto. Recomendação: **máximo 4 telas**, dados mínimos viáveis pro Coach funcionar.

#### Objeção e resolução

"Mas o Coach precisa de mais dados pra personalizar." Verdade, mas coleta depois — durante as primeiras corridas, o Coach pergunta naturalmente ("qual seu objetivo?", "tem alguma lesão?"). **Onboarding progressivo > formulário longo.**

---

### Feature 4: Gamificação Interna (Streaks, Badges, Níveis)

**O que faz:** Mantém o corredor voltando. Streaks por dias consecutivos, badges por conquistas, níveis por XP acumulado.

#### Opções técnicas

| Componente | Solução | Alternativa |
|-----------|---------|-------------|
| Engine | Custom (regras no Cloud Functions) | Package `teqani_rewards` (pronto, Firebase integrado) |
| Storage | Firestore (coleção gamification por user) | Hive local + sync |
| Notificações | Firebase Cloud Messaging (push "não perca seu streak!") | Local notifications |
| UI | Animações Flutter (confetti, progress rings, badge unlock) | Packages: `confetti_widget`, `percent_indicator` |
| Analytics | Firebase Analytics + Remote Config | A/B testa thresholds |

#### Regras de gamificação

```
- Streak: corrida em dias consecutivos. Perde se pular 1 dia
- XP: baseado em distância × consistência × dificuldade
- Níveis: thresholds de XP (Iniciante → Corredor → Atleta → Elite)
- Badges: conquistas únicas ("Primeira 5K", "10 corridas no mês", "Pace sub-5:00")
```

#### Onde rodam as regras

- **Cloud Functions (server-side)** — previne trapaça, garante integridade
- **Triggered por:** corrida finalizada → Cloud Function avalia → atualiza gamification
- **Remote Config:** ajustar thresholds sem publicar nova versão do app

**Custo:** Baixíssimo. Cloud Functions (~$0.40/1M invocações) + Firestore reads/writes. Praticamente free tier.

#### Armadilha: gamificação mal feita

Gamificação mal feita desengaja ao invés de engajar. Se tudo é conquista, nada é especial. Regra: **poucos badges de alto valor > muitos badges sem sentido**. Nike Run Club acerta nisso — challenges semanais, não 50 badges genéricos.

#### Referência: teqani_rewards

Package Flutter com achievement systems, streak tracking, e time-limited challenges. Suporte a SharedPreferences, SQLite, Hive e Firebase. Built-in Firebase Analytics. Alternativa viável ao engine custom se quiser acelerar o MVP.

---

### Feature 5: Configuração de Alertas

**O que faz:** Corredor configura o que quer ouvir (alerta a cada km, splits, pace, BPM). Premium: Coach auto-configura baseado no plano.

#### Implementação

| Componente | Solução |
|-----------|---------|
| UI | Tela de settings com toggles e presets |
| Storage | Firestore (preferências do user) |
| Trigger | Lógica local — GPS event → checa configuração → dispara se necessário |
| Áudio (Free) | Sons/beeps locais (zero custo) |
| Áudio (Premium) | Coach fala via TTS (custo normal do Coach) |

**Custo:** Zero adicional. Free tier usa sons locais. Premium usa o pipeline do Coach que já existe.

#### Insight: gatilho de conversão

Alertas manuais (Free) vs Coach automático (Premium) é um dos **gatilhos de conversão mais fortes**:

```
Free:    "bip" a cada km
Premium: "Primeiro quilômetro, pace 5:42, tá 10 segundos abaixo do plano,
          acelera um pouco nos próximos 500 metros."
```

A diferença é gritante. O corredor sente o valor imediatamente.

---

### Feature 6: Cards Compartilháveis

**O que faz:** Gera imagem bonita com dados da corrida. Corredor compartilha no Instagram/Stories. Branded com logo da operadora.

#### Implementação

| Componente | Solução |
|-----------|---------|
| Geração de imagem | `RepaintBoundary` (Flutter nativo — captura widget como imagem) |
| Design do card | Widget Flutter customizado (mapa + stats + branding) |
| Compartilhamento | `share_plus` (plugin oficial) ou `appinio_social_share` (Instagram direto) |
| LLM (Premium) | Gera texto personalizado pro card ("Semana 3 do plano 10K — pace caiu 15s!") |
| Branding | Template customizável por operadora (cores, logo, CTA) |

#### Free vs Premium

```
Card Free:                          Card Premium:
┌─────────────────┐                 ┌─────────────────┐
│  Mapa da rota   │                 │  Mapa da rota   │
│ 5.2km | 28:15   │                 │ 5.2km | 28:15   │
│ Pace: 5:26/km   │                 │ Pace: 5:26/km   │
│                  │                 │ "Semana 3 do    │
│ [Logo Operadora] │                 │  plano 10K —    │
│                  │                 │  pace caiu 15s!" │
└─────────────────┘                 │ Evolução: +12%  │
                                    │ [Logo Operadora] │
                                    └─────────────────┘
```

**Custo:** Zero (geração local no Flutter). Custo mínimo de LLM para texto personalizado no Premium (~centavos).

#### Armadilha: design é tudo

Card feio ninguém compartilha. Precisa de designer bom. É marketing orgânico — cada share é anúncio gratuito da operadora. **Investir em design de cards vale mais que investir em ads.**

---

### Feature 7: Benchmark Anônimo

**O que faz:** Contextualiza a performance ("top 20% dos intermediários nessa rota"). Dados agregados, não social.

#### Implementação

| Componente | Solução |
|-----------|---------|
| Agregação de dados | Cloud Functions (scheduled) — roda 1x/dia, agrega stats por rota/nível |
| Storage | Firestore (coleção `benchmarks` com médias por segmento) |
| Privacidade | Dados sempre agregados, nunca individuais. Mínimo de N runners numa rota pra gerar benchmark |

#### Fases de evolução

```
Fase 1 (MVP sem dados):
  Coach: "Pace de 5:42 é excelente pra intermediário — referência é 6:00-6:30"
  → Dados hardcoded de literatura/estudos

Fase 2 (com dados pessoais):
  Coach: "Essa corrida foi 8% mais rápida que sua média das últimas 4 semanas"
  → Calcula sobre histórico do próprio corredor

Fase 3 (com massa crítica, ~1K+ runners numa rota):
  Coach: "Nessa rota, seu pace te coloca no top 20% dos intermediários"
  → Benchmark real, anônimo, agregado
```

**Custo:** Marginal — Cloud Functions scheduled + Firestore reads. Pennies.

#### Objeção honesta

Fase 3 exige massa crítica numa mesma rota. Com 1K users espalhados pelo Brasil, pode levar tempo. Não é problema — fases 1 e 2 já entregam valor. Fase 3 é bônus que vem com escala.

---

### Feature 8: Health Connect / HealthKit

**O que faz:** Puxa dados de wearables — BPM, sono, recovery. Alimenta o Coach com mais contexto.

#### Implementação

| Componente | Solução |
|-----------|---------|
| Plugin | `health` (pub.dev) — cobre Health Connect (Android) + HealthKit (iOS) |
| Dados | BPM em tempo real, sono, passos, calorias |
| Permissões | Tela de consentimento explícito (obrigatório por lei) |
| Uso no Coach | Alimenta context builder → LLM recebe "BPM: 155, zona 4" |

**Alerta importante:** Google Fit API está sendo descontinuado em 2026. **Health Connect é o caminho obrigatório** no Android. O plugin `health` já suporta ambos.

**Custo:** Zero. APIs nativas, plugin open source.

#### Armadilhas

- Requer `FlutterFragmentActivity` ao invés de `FlutterActivity` no Android — se não configurar, não funciona
- Permissões são granulares (o user escolhe O QUE compartilhar). Precisa lidar com cenário de permissão parcial
- BPM em tempo real via Health Connect tem delay de ~3-5s (Bluetooth sync). Coach precisa considerar que dado pode estar "atrasado"

---

### Feature 9: Sugestões Locais Pós-Corrida (P1)

**O que faz:** Após a corrida, o Coach sugere pontos de reposição próximos — açaí, água de coco, isotônico, café. Monetização futura por parcerias.

#### Implementação

| Componente | Solução | Notas |
|-----------|---------|-------|
| API de locais | Google Places API (New) | Já no ecossistema Google. Free tier: $200/mês em créditos (~5K buscas Nearby) |
| Plugin Flutter | `google_maps_webservice` ou HTTP direto | Places API é REST — não precisa de SDK pesado |
| Trigger | Corrida finalizada → Coach gera relatório → busca locais num raio de 500m-1km | Chamada única por corrida, não contínua |
| Categorias | Pré-definidas: açaí, sucos, água de coco, cafés, farmácias (hidratação) | Filtro por `type` na Places API |
| UI | Card no relatório pós-corrida com nome, distância, rating, foto | Integrado ao fluxo existente — não é tela separada |
| Coach integration | LLM menciona no relatório: "Hidrate-se! Tem uma açaiteria a 200m — Oakberry, 4.5 estrelas" | Dados da Places API alimentam o contexto do LLM |

#### Custo

| Cenário | Chamadas/mês | Custo |
|---------|-------------|-------|
| 1K users, 3 corridas/semana | ~12K buscas/mês | **~R$ 0** (dentro do free tier de $200/mês) |
| 10K users | ~120K buscas/mês | ~R$ 200-400/mês |

**Praticamente grátis** no volume do MVP. Google dá $200/mês de crédito pra Places API.

#### Evolução (roadmap de monetização)

```
Fase 1 (MVP — P1):
  Coach: "Hidrate-se! Tem uma açaiteria a 200m"
  → Google Places API, orgânico, zero comissão

Fase 2 (com tração):
  Parcerias diretas com redes (Oakberry, Mundo do Açaí, etc.)
  → Cupom exclusivo RunCoach ("10% no açaí pós-corrida")
  → Comissão por redenção de cupom (5-15%)

Fase 3 (com escala):
  Marketplace de parceiros locais
  → Academias, lojas de corrida, nutricionistas
  → Operadora já tem relacionamento com anunciantes — app vira canal de mídia
```

#### Armadilhas

- **Relevância:** Sugerir farmácia quando o cara quer açaí é irritante. Filtrar por categorias relevantes a corredor, não "tudo perto"
- **Horário:** Se o cara correu às 6h da manhã, a açaiteria está fechada. Respeitar `opening_hours` da Places API
- **Localização rural:** Corredor no parque sem nada perto → Coach não sugere nada (melhor que sugerir algo a 5km). Threshold de 1km máximo

---

### Feature 10: Integração Música — BPM Adaptativo (P1)

**O que faz:** Integra com Spotify/YouTube Music/Apple Music. MVP: duck audio (Coach fala por cima). Evolução: BPM adaptativo (música acelera/desacelera com o pace).

#### Implementação — MVP (duck audio)

O duck audio é o mínimo viável: quando o Coach vai falar, o app abaixa o volume da música, Coach fala, volume volta.

| Componente | Solução | Notas |
|-----------|---------|-------|
| Audio focus | `audio_session` (plugin Flutter) | Gerencia AudioFocus no Android e AVAudioSession no iOS |
| Comportamento | `AudioSession.instance.configure(duck: true)` | Sistema abaixa volume do app de música automaticamente |
| Trigger | Antes de tocar TTS → ativa duck → toca áudio Coach → desativa duck | Transição suave (~300ms fade) |
| Música do usuário | App de música externo (Spotify, YT Music, Apple Music) | O corredor já está ouvindo — RunCoach não precisa "controlar" nada |

**Custo:** Zero. Duck audio é feature nativa do OS via `AudioFocus`/`AVAudioSession`. Não precisa de API do Spotify.

**Isso já resolve 90% do caso de uso.** O corredor ouve sua playlist, o Coach fala por cima quando precisa. Simples.

#### Implementação — Evolução (integração direta com Spotify/YT Music)

| Componente | Solução | Notas |
|-----------|---------|-------|
| Spotify | `spotify_sdk` (plugin Flutter) + Spotify Web API | Requer Spotify Premium do usuário. Controle de playback, BPM, playlists |
| YouTube Music | Sem SDK oficial. `youtube_explode_dart` (não oficial) | API limitada — não controla playback. Alternativa: deep link |
| Apple Music | `music_kit` (plugin Flutter) | Só iOS. MusicKit API da Apple |
| BPM detection | `aubio` (C library via FFI) ou API Spotify Audio Features | Spotify retorna BPM de cada track. Sem Spotify, precisa analisar áudio local |
| BPM adaptativo | Lógica: pace do corredor → target BPM → seleciona próxima música com BPM compatível | Ex: pace 5:00 → ~170 BPM → próxima música da fila com ~170 BPM |

#### Lógica do BPM adaptativo

```
Corredor definiu pace alvo: 5:30/km
  → Cadência ideal: ~170 passos/min
  → Target BPM musical: 170 BPM (ou 85 BPM, metade — funciona igual)

Corrida começa:
  → App busca playlist do corredor no Spotify
  → Ordena por BPM (via Spotify Audio Features endpoint)
  → Toca música com BPM mais próximo do target

Pace muda durante corrida:
  → Pace caiu pra 4:50 → target sobe pra ~175 BPM
  → Próxima música: seleciona track com BPM ~175
  → Transição suave (crossfade)
```

#### Custo

| Componente | Custo |
|-----------|-------|
| Duck audio (MVP) | R$ 0 — nativo do OS |
| Spotify SDK | R$ 0 — grátis, requer Spotify Premium do user |
| YouTube Music | R$ 0 — mas sem controle real de playback |
| Apple Music | R$ 0 — MusicKit é grátis |
| BPM detection local (sem Spotify) | R$ 0 — aubio é open source |

**Total: R$ 0.** Toda a integração de música é grátis. O custo é tempo de desenvolvimento, não infra.

#### Armadilhas

- **Spotify Premium obrigatório:** SDK do Spotify só controla playback se o user tem Premium. Free users só podem ver metadata. Precisa lidar com esse cenário (fallback: duck audio)
- **YouTube Music sem SDK:** Google não oferece SDK oficial pra controlar playback do YT Music. Solução limitada a deep links ou notificações. Na prática: duck audio é o máximo
- **BPM nem sempre funciona:** Música com BPM variável (ao vivo, clássica) quebra a lógica. Filtrar por gêneros compatíveis (eletrônica, pop, hip-hop)
- **Latência de crossfade:** Trocar de música no meio da corrida precisa ser suave. Crossfade de 2-3s. Se for abrupto, irrita

#### Priorização

```
P1a (MVP — faz primeiro):
  Duck audio via audio_session
  → Zero integração com Spotify/YT Music
  → Corredor usa app de música separado
  → Coach fala por cima — fim

P1b (pós-MVP — quando tiver tração):
  Integração Spotify SDK
  → Controle de playback
  → BPM adaptativo
  → Requer Spotify Premium

P1c (futuro):
  Apple Music (MusicKit)
  YouTube Music (se Google lançar SDK)
  BPM detection local (pra quem não tem Spotify)
```

---

### Visão consolidada — custo por feature (1K users)

| # | Feature | Tier | Custo/mês | Complexidade dev | Criticidade |
|---|---------|------|-----------|-----------------|-------------|
| 1 | GPS tracking | P0 | ~R$ 0 (free tiers) | Média (background tracking) | Obrigatória |
| 2 | Coach IA | P0 | ~R$ 3.050 (LLM + TTS) | Alta | Killer feature |
| 3 | Onboarding | P0 | ~R$ 0 | Baixa | Obrigatória |
| 4 | Gamificação | P0 | ~R$ 20-50 (Cloud Functions) | Média | Alta (retenção) |
| 5 | Alertas | P0 | ~R$ 0 (incluso no Coach) | Baixa | Média |
| 6 | Cards | P0 | ~R$ 0 (geração local) | Média (design) | Alta (aquisição) |
| 7 | Benchmark | P0 | ~R$ 10-20 (Functions + Firestore) | Média | Média (cresce com escala) |
| 8 | Health Connect | P0 | ~R$ 0 | Média (permissões) | Alta (infraestrutura Coach) |
| 9 | Sugestões Locais | P1 | ~R$ 0 (free tier Places API) | Baixa | Média (monetização futura) |
| 10 | Integração Música | P1 | ~R$ 0 (duck audio nativo) | Baixa (MVP) / Alta (BPM) | Média (UX) |
| | **TOTAL** | | **~R$ 3.080-3.120** | | |

**Conclusão:** 98% do custo operacional é o Coach IA (LLM + TTS). Todo o resto — incluindo as P1 — custa centavos. As features P1 são essencialmente grátis em infra, o custo é apenas tempo de desenvolvimento.

---

## 5. Decisão Técnica: Backend/Infra

### Por que essa decisão importa

Backend é o alicerce invisível. Errar aqui não dói no MVP — dói na escala. Migrar de banco de dados com 50K users é reescrita, não refatoração. A escolha precisa ser boa o suficiente pra aguentar de 0 a 50K users sem trocar tudo.

As variáveis que importam:
1. **Ecossistema** — quanto menos fornecedores, menos complexidade pra founder solo
2. **Custo previsível** — pay-as-you-go traiçoeiro vs pricing fixo
3. **Multi-tenant** — white-label pra operadoras exige isolamento de dados
4. **Vendor lock-in** — quão caro é sair se precisar

### Todas as opções avaliadas

| Critério | Firebase | Supabase | Appwrite |
|---------|---------|----------|---------|
| **Flutter SDK** | Oficial (FlutterFire) — melhor suporte | Bom (community-maintained) | Bom (SDK Dart oficial) |
| **Real-time** | Firestore listeners (nativo, otimizado) | Postgres logical replication | WebSocket-based |
| **Auth** | Phone, Google, Apple, email | Idem + magic link, SAML | Idem + OAuth2 genérico |
| **Functions** | Cloud Functions (Node.js, Python) | Edge Functions (Deno) | Cloud Functions (Node, Python, Dart) |
| **Banco** | NoSQL (Firestore) — document-based | **PostgreSQL** (SQL completo) | NoSQL (document-based) |
| **Free tier** | Generoso (50K reads/dia, 20K writes/dia) | Generoso (500MB DB, 1GB storage) | 2 projetos grátis |
| **Pricing modelo** | Pay-as-you-go (imprevisível) | $25/mês (previsível) | $25/mês/projeto |
| **Self-host** | Impossível | Sim (open source) | Sim (open source) |
| **Vendor lock-in** | **Alto** — Firestore API é proprietária | Baixo (PostgreSQL padrão) | Baixo |
| **Multi-tenant** | Suportado (Identity Platform) | Nativo (Row Level Security) | Via tenant_id manual |
| **Ecossistema Google** | Total (Maps, Analytics, FCM, Crashlytics) | Nenhum | Nenhum |

### Análise crítica — objeções e corroborações

**"Supabase é melhor porque é SQL e open source"**
- Verdade técnica. PostgreSQL é mais flexível que Firestore pra queries complexas (joins, aggregations). E não tem vendor lock-in
- Mas: ecossistema Flutter + Google é uma vantagem prática enorme. Maps, Analytics, FCM, Crashlytics, Remote Config — tudo integrado num console, um billing, um SDK. Com Supabase, cada um desses precisa de solução separada
- Pra founder solo, a fricção importa mais que a pureza técnica

**"Firebase é caro em escala"**
- Parcialmente verdade. O modelo pay-per-read/write é traiçoeiro — um real-time listener descontrolado pode custar centenas de dólares
- Mas: pra 1K users de um app de corrida, o custo total de Firestore é ~R$ 20/mês. O perigo real é no design de queries, não no pricing model
- Mitigação: usar `get()` em vez de listeners quando não precisa de real-time; Budget Alerts desde o dia 1

**"Vendor lock-in é perigoso"**
- Verdade a longo prazo. Se precisar migrar de Firestore pra outro banco, é reescrita pesada do data layer
- Mitigação: Repository Pattern desde o dia 1. Código não fala com Firestore diretamente — fala com interface abstrata. Trocar implementação = trocar só o repository, não reescrever o app
- Na prática: é um risco aceitável pro MVP. Ninguém migra de Firebase antes de 50K users

**"Appwrite tem SDK Dart melhor"**
- Verdade — SDK oficial e bem mantido. Mas ecossistema menor, menos battle-tested em produção, e sem integração com Maps/Analytics/FCM
- Pra um app que já usa Google Maps, FCM, e Crashlytics, adicionar Appwrite = mais um fornecedor sem ganho claro

### Decisão: Firebase (com proteções arquiteturais)

Para o RunCoach AI, Firebase é a escolha certa. Razões:

1. **Ecossistema unificado** — Maps, Auth, FCM, Analytics, Crashlytics, Remote Config, Hosting. Um console, um billing, um SDK
2. **Flutter SDK oficial** — FlutterFire é o mais documentado, mais estável, menos bugs
3. **Free tier generoso** — protótipo e primeiros 1K users custam quase zero em Firestore
4. **Founder solo** — menos fornecedores = menos complexidade operacional = menos pontos de falha
5. **Multi-tenant nativo** — Identity Platform suporta tenants por operadora com custom claims
6. **Ecossistema de knowledge** — 10x mais tutoriais, Stack Overflow, e exemplos Flutter+Firebase vs qualquer alternativa

**Proteções obrigatórias:**
- Repository Pattern desde o dia 1 (abstração do data layer — Firestore nunca aparece fora do repository)
- Firebase Budget Alerts configurados antes de ir pra produção
- Evitar real-time listeners desnecessários (`get()` quando não precisa de real-time)
- Monitorar custos semanalmente no Firebase Console

**Quando reavaliar:** Se ultrapassar 50K users E o custo de Firestore passar de 10% da receita, avaliar migração pra Supabase (PostgreSQL). O Repository Pattern garante que essa migração é viável sem reescrever o app.

---

### Modelagem de dados Firestore

```
firestore/
│
├── users/{userId}
│   ├── profile: { name, email, phone, level, age, goals, operator_id }
│   ├── preferences: { alerts, coach_voice, language }
│   ├── gamification: { xp, level, streak, badges[], last_run_date }
│   └── health_connect: { last_sync, permissions[] }
│
├── users/{userId}/runs/{runId}
│   ├── metadata: { date, duration_s, distance_m, avg_pace, calories, status }
│   ├── plan: { type, target_pace, intervals[] }
│   ├── coach_report: { summary, insights[], next_suggestion }
│   └── gps_points/ (subcollection)
│       └── {pointId}: { lat, lng, timestamp, accuracy, pace, bpm }
│
├── users/{userId}/plans/{planId}
│   ├── goal, duration_weeks, current_week, status
│   └── weeks/{weekId}/sessions/{sessionId}
│
├── operators/{operatorId}
│   ├── config: { name, logo_url, colors{}, cta_text, theme }
│   ├── billing: { model, price, revenue_share }
│   └── stats: { users_count, active_users_count }
│
├── benchmarks/{routeHash}
│   └── stats: { avg_pace_by_level{}, runner_count, last_updated }
│
└── gamification_rules/
    └── {ruleId}: { type, threshold, badge_name, xp_reward, description }
```

**Decisões de modelagem:**

| Decisão | Justificativa |
|---------|---------------|
| GPS points como subcollection | Uma corrida de 1h gera ~3.600 pontos (1/s). Não cabe num documento (limite 1MB do Firestore). Subcollection escala infinitamente |
| Gamification no documento do user | Poucos campos, leitura frequente. Evita subcollection desnecessária e read extra |
| Operators como coleção raiz | Isolamento de dados por operadora. Security Rules garantem que user da Operadora A não acessa dados da B |
| Benchmarks por routeHash | Geohash da rota permite agregar corridas similares sem expor dados individuais. Privacy by design |
| Plans como subcollection do user | Planos são pessoais, nunca compartilhados. Acesso sempre via userId |

---

### Autenticação — phone number é obrigatório

O público são corredores brasileiros vendidos por operadoras via DCB. O fluxo natural:

```
Operadora ativa assinatura (DCB)
  → user recebe SMS com link deeplink
  → abre app → verifica phone number (Firebase Auth)
  → phone number = identidade + link com operadora
  → Cloud Function seta custom claims (operator_id, plan_type)
```

#### Componentes de Auth

| Componente | Solução | Justificativa |
|-----------|---------|---------------|
| Auth primário | Firebase Phone Auth (SMS OTP) | Phone number é o elo natural com DCB da operadora |
| Auth secundário | Google Sign-In (opcional) | Alternativa zero-custo pra quem prefere |
| Multi-tenant | Firebase Identity Platform | Tenant por operadora, isolamento nativo |
| Custom claims | Cloud Function `onUserCreate` | Seta `operator_id` e `plan_type` (free/premium) no JWT token |
| DCB billing | API da operadora (Boku/Fortumo ou direta) | **Separado do Auth** — phone number é o elo de ligação |

#### Custo de Auth (SMS)

Firebase Phone Auth cobra por SMS enviado:
- Free: 10K SMS/mês (Spark plan, regiões selecionadas)
- Blaze: ~$0.06/SMS no Brasil
- 1K users × 1 login/mês = ~$60/mês (~R$ 360)

**Otimizações de SMS:**
- Session tokens de 30 dias (menos re-autenticações)
- Google Sign-In como alternativa zero-custo
- Silent verification no Android (lê SMS automaticamente, sem OTP manual)
- O custo de SMS é o item mais caro do Firebase — mais que Firestore inteiro

---

### Cloud Functions — o motor invisível

| Função | Trigger | O que faz | Latência crítica? |
|--------|---------|-----------|-------------------|
| `onRunComplete` | Firestore write (run status=done) | Avalia gamificação, gera badge, atualiza streak/XP | Não (corredor parou) |
| `generateCoachPlan` | HTTP (user request) | Chama LLM grande, gera plano personalizado, salva | Não (corredor parado, pode levar 5s) |
| `generateCoachReport` | Firestore write (run status=done) | Chama LLM grande, gera relatório pós-corrida | Não (assíncrono) |
| `aggregateBenchmarks` | Scheduled (1x/dia) | Agrega stats de corridas por rota/nível | Não (batch) |
| `syncOperatorBilling` | Scheduled (1x/dia) | Verifica status DCB com API da operadora | Não (batch) |
| `setCustomClaims` | Auth trigger (user created) | Seta operator_id e plan_type no JWT | Não (1x por user) |

**Cold start — problema real e solução:**
- Cloud Functions tem cold start de 1-3s na primeira invocação após inatividade
- Pra `onRunComplete` e scheduled functions: irrelevante (corredor não espera resposta imediata)
- Pra `generateCoachPlan`: importa — corredor quer o plano rápido
- **Solução:** `minInstances: 1` pra funções HTTP críticas (custo extra: ~R$ 30-60/mês)

**Nota:** O coaching DURANTE a corrida (LLM rápido + TTS) **não** passa por Cloud Functions. É chamada direta do app à API do LLM/TTS — Cloud Functions adicionaria latência inaceitável. Functions são pra operações assíncronas (antes/depois da corrida).

**Runtime recomendado:** Node.js 20 (mais packages, melhor suporte Firebase SDK). Memória: 256MB pra funções leves, 512MB pra funções com chamada LLM.

---

### Projeção de custo Firebase (1.000 users)

**Premissas:** 1K users totais, ~300 DAU, 3 corridas/semana por DAU ativo

| Serviço | Uso estimado/mês | Custo/mês (USD) | Custo/mês (R$) |
|---------|-----------------|-----------------|----------------|
| Firestore reads | ~3M (runs, profile, gamification, listeners) | $1.80 | ~R$ 11 |
| Firestore writes | ~500K (GPS points, runs, gamification) | $0.90 | ~R$ 5 |
| Firestore storage | ~2-5GB (GPS trails, profiles, plans) | $0.36-0.90 | ~R$ 2-5 |
| Cloud Functions | ~500K invocações, ~100 compute-hours | $5-15 | ~R$ 30-90 |
| **Firebase Auth (SMS)** | **~1K SMS/mês (login + re-auth)** | **$60** | **~R$ 360** |
| FCM (push notifications) | Ilimitado | $0 | R$ 0 |
| Firebase Analytics | Ilimitado | $0 | R$ 0 |
| Crashlytics | Ilimitado | $0 | R$ 0 |
| Remote Config | Ilimitado | $0 | R$ 0 |
| Hosting (landing pages) | Minimal | $0-5 | R$ 0-30 |
| Google Maps SDK | ~30K loads/mês | $0 (free tier) | R$ 0 |
| | | | |
| **TOTAL Firebase** | | **~$70-85** | **~R$ 420-510** |

**Observação importante:** O custo mais alto do Firebase não é Firestore (~R$ 18/mês) — é **SMS de autenticação** (~R$ 360/mês). Firestore custa centavos pra 1K users. Otimizar SMS (session tokens longos, Google Sign-In como alternativa) tem mais impacto que otimizar queries.

---

### Visão consolidada — custo total de infra (1.000 users)

| Item | Custo/mês (R$) | % da receita (R$ 14.900) |
|------|----------------|--------------------------|
| LLM (Qwen + DeepSeek) | ~R$ 170 | 1.1% |
| TTS (Google Neural2) | ~R$ 2.880 | 19.3% |
| Firebase (Firestore + Functions + Auth + Hosting) | ~R$ 420-510 | 2.8-3.4% |
| **TOTAL tech** | **~R$ 3.470-3.560** | **23.3-23.9%** |
| **Margem bruta** | **~R$ 11.340-11.430** | **~76%** |

Margem de 76% é excelente pra SaaS B2B2C. A conta fecha com folga mesmo no cenário pessimista. O vilão é TTS (19.3%), não backend (3%).

---

## 6. Stack Consolidada

### Visão geral — toda a stack em uma tabela

| Camada | Componente | Solução escolhida | Alternativa (fallback) | Justificativa |
|--------|-----------|-------------------|----------------------|---------------|
| **Frontend** | Framework | Flutter | — | Google ecosystem, cross-platform, SDK Firebase oficial |
| **Frontend** | State management | BLoC ou Riverpod | — | A definir no protótipo (ambos cobrem o caso) |
| **Frontend** | Mapas | Google Maps SDK | Mapbox | Free tier 28K loads/mês, mesmo ecossistema |
| **Frontend** | GPS | `geolocator` + `flutter_background_service` | `flutter_background_geolocation` (pago) | Grátis, cobre o caso. Pago se precisar de mais robustez |
| **Frontend** | Health data | Plugin `health` (pub.dev) | — | Cobre Health Connect (Android) + HealthKit (iOS) |
| **Frontend** | Local storage | Hive | SQLite | Leve, rápido, bom pra GPS trails antes de sync |
| | | | | |
| **Backend** | BaaS | Firebase (Firestore + Auth + Functions + FCM) | Supabase (se precisar migrar >50K users) | Ecossistema unificado, menor complexidade operacional |
| **Backend** | Auth | Firebase Phone Auth + Identity Platform | Google Sign-In (secundário) | Phone = elo natural com DCB da operadora |
| **Backend** | Functions | Cloud Functions (Node.js 20) | — | Trigger por Firestore write, HTTP, scheduled |
| **Backend** | Push | Firebase Cloud Messaging (FCM) | — | Grátis, ilimitado |
| **Backend** | Analytics | Firebase Analytics + Crashlytics | — | Grátis, integrado |
| **Backend** | Config | Firebase Remote Config | — | A/B tests, feature flags, sem redeploy |
| | | | | |
| **IA — LLM** | Coaching real-time | Qwen3-32B via Groq | Qwen3-8B via Groq (mais barato) | Sub-segundo, $0.20/1M, PT-BR aceitável |
| **IA — LLM** | Plano + relatório | DeepSeek V3.2 via Together AI | Qwen 3.5-397B via Alibaba Cloud | $0.14/1M, qualidade GPT-4o, servidores EUA |
| **IA — LLM** | Fallback | Gemini 2.5 Flash-Lite | — | Mesmo ecossistema, free tier generoso |
| **IA — TTS** | Voz do Coach | Google Cloud TTS Neural2 | Azure Neural TTS / Google Chirp 3 HD | Melhor custo-benefício ($16/1M chars), ecossistema unificado |
| **IA — STT** | Voz do corredor | STT nativo (iOS/Android built-in) | — | Custo zero, latência zero, funciona offline |
| | | | | |
| **Infra** | Hosting | Firebase Hosting | — | Landing pages, links dinâmicos |
| **Infra** | CDN/Storage | Firebase Storage | — | Imagens de perfil, assets de operadoras |
| **Infra** | Monitoring | Firebase Performance + Crashlytics | — | Grátis |

### Princípios arquiteturais obrigatórios

Regras que atravessam toda a stack — não são opcionais:

| Princípio | O que significa | Por quê |
|-----------|----------------|---------|
| **Repository Pattern** | Código nunca fala direto com Firestore/LLM/TTS. Sempre via interface abstrata | Permite trocar provider sem reescrever o app |
| **Camada de abstração de IA** | LLM e TTS acessados via interface que recebe config (model, provider) | Trocar Qwen→Gemini ou Neural2→Azure = mudar config, não código |
| **Streaming first** | LLM gera tokens em stream → TTS sintetiza em paralelo (não espera tudo) | Corta latência percebida pela metade durante corrida |
| **Providers americanos** | LLMs chineses (Qwen, DeepSeek) sempre via Groq/Together/Fireworks | Dados de saúde/fitness não passam por servidores na China |
| **Dual LLM** | Modelo rápido (durante corrida) + modelo grande (antes/depois) | Consequência natural da jornada do corredor — não é otimização prematura |
| **Dados locais primeiro** | GPS trail salvo em Hive durante corrida, sync com Firestore depois | Se internet cair no meio da corrida, dados não se perdem |
| **Cache de TTS** | Frases comuns do Coach pré-geradas e cacheadas localmente | Reduz custo de TTS em ~20-30% e elimina latência pra frases repetidas |
| **Budget Alerts** | Firebase Budget Alerts configurados antes de produção | Evita surpresas no pay-as-you-go |

### Custo total consolidado (1.000 users Premium)

```
┌──────────────────────────────────────────────────────┐
│         CUSTO OPERACIONAL — 1.000 USERS              │
│                                                       │
│  Receita:           R$ 14.900/mês                    │
│                                                       │
│  LLM (Qwen + DeepSeek):        R$   170  ( 1.1%)    │
│  TTS (Google Neural2):          R$ 2.880  (19.3%)    │
│  Firebase (Auth+DB+Functions):  R$   500  ( 3.4%)    │
│  ─────────────────────────────────────────            │
│  TOTAL TECH:                    R$ 3.550  (23.8%)    │
│                                                       │
│  MARGEM BRUTA:                  R$ 11.350 (76.2%)    │
│                                                       │
│  Maior custo: TTS (81% do custo tech)                │
│  Otimização #1: cache de frases comuns (-20-30%)     │
│  Otimização #2: frases mais curtas (100→60 chars)    │
│  Otimização #3: menos falas/corrida (qualidade > qty)│
└──────────────────────────────────────────────────────┘
```

### Escala — o que muda com 10K e 50K users

| Componente | 1K users | 10K users | 50K users | Ação necessária |
|-----------|---------|----------|----------|-----------------|
| Firestore | ~R$ 20/mês | ~R$ 200/mês | ~R$ 1.000/mês | Nenhuma — escala linear |
| Auth SMS | ~R$ 360/mês | ~R$ 3.600/mês | ~R$ 18.000/mês | Otimizar session tokens, incentivar Google Sign-In |
| Cloud Functions | ~R$ 60/mês | ~R$ 600/mês | ~R$ 3.000/mês | minInstances, otimizar cold starts |
| LLM | ~R$ 170/mês | ~R$ 1.700/mês | ~R$ 8.500/mês | Avaliar self-hosting a partir de 50K |
| TTS | ~R$ 2.880/mês | ~R$ 28.800/mês | ~R$ 144.000/mês | **Ponto crítico** — avaliar self-hosted (Fish Speech/F5-TTS) ou renegociar volume |
| **Total** | **~R$ 3.550** | **~R$ 35.000** | **~R$ 175.000** | |
| **Receita** | **R$ 14.900** | **R$ 149.000** | **R$ 745.000** | |
| **Margem** | **76%** | **77%** | **77%** | Escala linear — margem se mantém |

**Insight:** A margem se mantém estável em ~76-77% porque todos os custos escalam linearmente com users. Não há custo fixo alto. O ponto de atenção em 50K é TTS (R$ 144K/mês) — nesse volume, self-hosting com GPUs dedicadas começa a fazer sentido financeiramente E operacionalmente (equipe de infra justificada).

### Roadmap técnico por fase

```
FASE 1 — PROTÓTIPO (0-100 users)
├── Flutter + Firebase (free tiers)
├── Gemini Flash-Lite OU Qwen3-32B via Groq (validar stack)
├── Google Neural2 TTS (1M chars/mês grátis)
├── GPS tracking básico + Coach IA simplificado
└── Objetivo: protótipo funcional pra pitch à operadora

FASE 2 — MVP (100-1K users)
├── Migrar LLM pra stack dual (Qwen + DeepSeek)
├── Firebase Blaze plan (pay-as-you-go)
├── Implementar todas as features P0
├── Cache de TTS + otimizações de custo
├── Multi-tenant configurado (1ª operadora)
└── Objetivo: app completo rodando com primeira operadora

FASE 3 — ESCALA (1K-50K users)
├── Otimizar queries Firestore (índices, batch reads)
├── Monitorar custos semanalmente
├── Avaliar self-hosting de LLM se >15M tokens/mês
├── Novas operadoras = novos tenants (mesma infra)
└── Objetivo: margem >70%, múltiplas operadoras

FASE 4 — MATURIDADE (50K+ users)
├── Avaliar migração Firestore → Supabase/PostgreSQL
├── Avaliar self-hosting TTS (Fish Speech / F5-TTS com GPUs)
├── Equipe de infra dedicada
├── CDN de áudio pra cache global
└── Objetivo: otimizar margem, expandir pra outros países
```

---

## 7. Modelo Financeiro — Validação de Custos (Etapa 1.8)

> Stress test financeiro com dados reais do mercado DCB brasileiro.
> Dois modelos separados: Bundle (B2B via operadora) e DCB Avulso (B2C via assinatura direta).

### Conceitos-chave

| Conceito | Definição |
|----------|-----------|
| **Contratante** | Pessoa que assinou o serviço (paga, mas pode não usar) |
| **MAU** | Monthly Active User — abriu o app no mês |
| **MRU** | Monthly Running User — efetivamente correu. Gera custo de LLM+TTS |
| **Taxa de uso** | % de contratantes que viram MAU (nem todo mundo que paga, usa) |
| **MRU/MAU** | 80% — quem abre o app geralmente corre |
| **Custo/MRU** | R$3,16 — média ponderada (Light R$0,99 · Medium R$3,62 · Heavy R$9,29) |
| **Repasse líquido (DCB)** | 36% do faturamento bruto — operadora fica com ~64% |
| **Repasse fixo (Bundle)** | R$/user fixo negociado — não é % da tarifa do cliente |

### Perfis de uso e custo unitário

```
Perfil Light (60% dos MRU):  2 corridas/mês × 8 falas × 60 chars × R$0.016
                             + LLM: 2 × R$0.004 = R$0,99/mês

Perfil Medium (30% dos MRU): 3 corridas/mês × 12 falas × 80 chars × R$0.016
                             + LLM: 3 × R$0.004 = R$3,62/mês

Perfil Heavy (10% dos MRU):  5 corridas/mês × 15 falas × 100 chars × R$0.016
                             + LLM: 5 × R$0.004 = R$9,29/mês

Média ponderada: 0,6 × 0,99 + 0,3 × 3,62 + 0,1 × 9,29 = R$3,16/MRU/mês
```

---

### 7.1 Modelo Bundle (B2B — operadora paga por user)

#### Hipóteses

- **Modelo de repasse:** valor fixo por user/mês negociado com a operadora (NÃO é % da tarifa do cliente)
- **Dois cenários:** Plano Dedicado (ex: "Controle Running") e Plano Existente (pacote com app incluso)
- **Engajamento varia:** plano dedicado atrai corredor ativo (70% uso); plano existente atinge público geral (10% uso)
- **Preço é negociação:** mercado vai de R$0,125/user (apps de conteúdo) até R$4,00/user (Deezer)
- **RunCoach AI = hero app** em plano dedicado (poder de negociação maior)

#### Cenário A — Plano Dedicado ("Controle Running")

| Parâmetro | Valor |
|-----------|-------|
| Base piloto | 5.000 users |
| Taxa de uso | 70% (corredor veio pelo app) |
| MRU/MAU | 80% |
| MRU efetivos | 5.000 × 70% × 80% = 2.800 |
| Custo tech total | 2.800 × R$3,16 = R$8.848/mês |
| Custo tech/user | R$8.848 ÷ 5.000 = **R$1,77/user** |

**Análise de sensibilidade — Preço × Margem:**

| Preço/user | Receita | Custo | Margem | Margem % | Viável? |
|-----------|---------|-------|--------|----------|---------|
| R$0,50 | R$2.500 | R$8.848 | -R$6.348 | -254% | ❌ Inviável |
| R$1,00 | R$5.000 | R$8.848 | -R$3.848 | -77% | ❌ Inviável |
| R$1,77 | R$8.850 | R$8.848 | ~R$0 | 0% | ⚠️ Break-even |
| R$2,00 | R$10.000 | R$8.848 | R$1.152 | 12% | ⚠️ Apertado |
| R$3,00 | R$15.000 | R$8.848 | R$6.152 | 41% | ✅ Viável |
| R$4,00 | R$20.000 | R$8.848 | R$11.152 | 56% | ✅ Confortável |

**Conclusão Plano Dedicado:** Preço mínimo = R$1,77/user. Abaixo disso, dá prejuízo. RunCoach AI como hero app do plano justifica pedir R$2-4/user, mas a negociação é difícil. Bundle dedicado é estratégico (visibilidade, dados), não financeiro no curto prazo.

#### Cenário B — Plano Existente (app incluso num pacote)

| Parâmetro | Valor |
|-----------|-------|
| Base | 50.000 users (base grande, público geral) |
| Taxa de uso | 10% (maioria nem sabe que tem o app) |
| MRU/MAU | 80% |
| MRU efetivos | 50.000 × 10% × 80% = 4.000 |
| Custo tech total | 4.000 × R$3,16 = R$12.640/mês |
| Custo tech/user | R$12.640 ÷ 50.000 = **R$0,25/user** |

**Análise de sensibilidade — Preço × Margem:**

| Preço/user | Receita | Custo | Margem | Margem % | Viável? |
|-----------|---------|-------|--------|----------|---------|
| R$0,125 | R$6.250 | R$12.640 | -R$6.390 | -102% | ❌ Inviável |
| R$0,25 | R$12.500 | R$12.640 | -R$140 | -1% | ⚠️ Break-even |
| R$0,375 | R$18.750 | R$12.640 | R$6.110 | 33% | ✅ Viável |
| R$0,50 | R$25.000 | R$12.640 | R$12.360 | 49% | ✅ Bom |
| R$1,00 | R$50.000 | R$12.640 | R$37.360 | 75% | ✅ Ótimo |

**Conclusão Plano Existente:** Engajamento baixo = custo baixo por user. Viável a partir de R$0,25/user. A armadilha: se engajamento subir de 10% pra 30%, custo/user triplica e R$0,25 vira prejuízo. Monitorar engajamento é obrigatório.

#### Paradoxo do Bundle

> No bundle, **mais engajamento = mais custo** sem mais receita (preço fixo por user).
> O cenário ideal é base grande com engajamento moderado — ganha visibilidade e dados com custo controlado.
> Se engajamento explodir, é preciso renegociar preço ou controlar features (limitar corridas/mês no plano bundle).

---

### 7.2 Modelo DCB Avulso (B2C — assinatura direta via operadora)

#### Hipóteses

- **Modelo de repasse:** percentual — operadora cobra o cliente e repassa 36% líquido ao publisher
- **Mesmo repasse para semanal e mensal** (36%)
- **Mix:** 80% semanal (R$5,90) / 20% mensal (R$14,90)
- **Billing efetivo semanal:** 1,5x/mês (falhas de cobrança, crédito insuficiente, churn intra-mês)
- **Billing efetivo mensal:** 1,0x/mês (100% — quem paga mensal tem cobrança mais estável)
- **Taxa de uso:** 50% (metade dos contratantes efetivamente usa o app)
- **MRU/MAU:** 80%
- **Base projetada:** 100K contratantes no mês 6

#### Unit Economics por contratante

```
ARPU bruto:  0,8 × (R$5,90 × 1,5) + 0,2 × R$14,90 = R$10,06/mês
ARPU líquido (36%):                                    R$3,62/mês

Custo/contratante: 50% usa × 80% corre × R$3,16     = R$1,26/mês
────────────────────────────────────────────────────────────────────
MARGEM/CONTRATANTE:                                    R$2,36/mês (65%)
```

#### Proteção natural do DCB avulso

> Quem não usa **continua pagando** (até cancelar). Taxa de uso baixa **ajuda** a margem.
> Paradoxo invertido do bundle: aqui, menos engajamento = mais lucrativo.
> O gargalo real é **billing success rate** (1,5x/mês no semanal). Se cair, receita cai proporcionalmente.

#### Projeção de ramp-up (6 meses)

| Mês | Contratantes | Receita Líq. | Custo Tech | Margem | Margem % |
|-----|-------------|-------------|-----------|--------|----------|
| 1 | 5K | R$18,1K | R$6,3K | R$11,8K | 65% |
| 2 | 15K | R$54,3K | R$18,9K | R$35,3K | 65% |
| 3 | 30K | R$108,6K | R$37,9K | R$70,7K | 65% |
| 4 | 55K | R$199,1K | R$69,5K | R$129,6K | 65% |
| 5 | 80K | R$289,6K | R$100,8K | R$188,8K | 65% |
| 6 | 100K | R$362,0K | R$126,4K | R$235,6K | 65% |

#### Análise de sensibilidade — Taxa de uso

| Taxa uso | MRU/contratante | Custo/contrat. | Margem/contrat. | Margem % |
|---------|----------------|---------------|----------------|----------|
| 30% | 24% | R$0,76 | R$2,86 | 79% |
| **50% ← base** | **40%** | **R$1,26** | **R$2,36** | **65%** |
| 70% | 56% | R$1,77 | R$1,85 | 51% |
| 90% | 72% | R$2,28 | R$1,34 | 37% |

#### Análise de sensibilidade — Billing success rate (semanal)

| Billings/mês | ARPU bruto | ARPU líq. | Margem/contrat. | Margem % |
|-------------|-----------|----------|----------------|----------|
| 1,0x | R$7,70 | R$2,77 | R$1,51 | 55% |
| **1,5x ← base** | **R$10,06** | **R$3,62** | **R$2,36** | **65%** |
| 2,0x | R$12,42 | R$4,47 | R$3,21 | 72% |
| 3,0x | R$17,14 | R$6,17 | R$4,91 | 80% |

#### Cenários extremos

```
PIOR CASO REALISTA:
  Billings 1,0x + Taxa uso 70% + Custo/MRU +30% (R$4,11)
  ARPU líq: R$2,77 | Custo: R$2,30 | Margem: R$0,47 (17%)
  → 100K × R$0,47 = R$47K/mês — apertado mas positivo

MELHOR CASO REALISTA:
  Billings 2,0x + Taxa uso 40% + Custo/MRU -15% (R$2,69)
  ARPU líq: R$4,47 | Custo: R$0,86 | Margem: R$3,61 (81%)
  → 100K × R$3,61 = R$361K/mês
```

---

### 7.3 Modelo Consolidado (Bundle + DCB Avulso)

#### Cenário base — mês 6

| Canal | Base | Receita Líq./mês | Custo Tech/mês | Margem/mês | % da receita total |
|-------|------|-----------------|----------------|-----------|-------------------|
| Bundle Dedicado | 5K users | R$2,5K | R$8,8K | -R$6,3K | 0,7% |
| Bundle Existente | 50K users | R$6,3K | R$12,6K | -R$6,4K | 1,7% |
| DCB Avulso | 100K contrat. | R$362K | R$126,4K | +R$235,6K | 97,6% |
| **TOTAL** | **155K** | **R$370,8K** | **R$147,9K** | **R$222,9K** | **100%** |

#### Leitura estratégica

```
DCB avulso = 97,6% da receita líquida — é o motor financeiro
Bundle     =  2,4% da receita — papel estratégico, não financeiro:
  1. Canal de aquisição (visibilidade dentro da operadora)
  2. Bargaining chip (bundle ativo facilita negociar destaque no DCB)
  3. Base de dados (valida engajamento, mostra métricas à operadora)
  4. Custo de aquisição de cliente, não fonte de receita
```

#### Cenário otimista — Bundle renegociado após provar valor

| Canal | Preço/user | Receita Líq. | Custo Tech | Margem |
|-------|-----------|-------------|-----------|--------|
| Bundle Dedicado (5K) | R$1,50 → renegociado | R$7,5K | R$8,8K | -R$1,3K |
| Bundle Existente (50K) | R$0,375 → renegociado | R$18,8K | R$12,6K | +R$6,1K |
| DCB Avulso (100K) | — | R$362K | R$126,4K | +R$235,6K |
| **TOTAL** | | **R$388,3K** | **R$147,9K** | **R$240,4K (62%)** |

#### Pior cenário consolidado (stress)

```
DCB: Billings 1,0x + uso 70% + custo +30%
Bundle: Preços base (R$0,50 e R$0,125)
────────────────────────────────────────────
DCB Avulso (100K):    R$47,0K
Bundle Dedicado (5K): -R$6,3K
Bundle Existente (50K): -R$6,4K
────────────────────────────────────────────
TOTAL: R$34,3K/mês — positivo mesmo no pior caso
```

#### Break-even por canal

| Canal | Variável crítica | Preço mínimo p/ margem ≥ 0 |
|-------|-----------------|---------------------------|
| Bundle Dedicado | Engajamento 70% | R$1,77/user |
| Bundle Existente | Engajamento 10% | R$0,25/user |
| DCB Avulso | Billing rate 1,5x | Já positivo em qualquer cenário |

---

### 7.4 Conclusão do Stress Test Financeiro (Ponto 1)

| Critério | Avaliação |
|----------|-----------|
| Margem base consolidada | ~60% — saudável |
| Motor financeiro | DCB avulso (97,6%) — concentração alta |
| Risco de concentração | ⚠️ Se DCB avulso falhar, bundle não sustenta sozinho |
| Pior cenário absoluto | R$34K/mês positivo — sobrevive |
| Break-even DCB | Desde o mês 1 com 5K contratantes |
| Bundle viabilidade | Estratégico (aquisição), não financeiro |
| Correção vs Seção 6 | Margem real é ~60-65% (não 76% — a Seção 6 não incluía repasse DCB) |
| **Veredicto** | **GO ✅** com ressalva: bundle = custo de aquisição, DCB avulso = receita |

> **Nota:** A margem de 76% da Seção 6 assumia 100% de retenção de receita. A margem real pós-repasse DCB (36% líquido) é de ~60-65%. A Seção 6 permanece como referência de custo tech puro; esta Seção 7 reflete a realidade do modelo de negócio.

---

### 7.5 Stress Test — TTS (Ponto 2: a voz do Coach)

> TTS = 81% do custo tech. Perguntas centrais: o produto sobrevive sem voz? O custo escala de forma sustentável?

#### Cenários de indisponibilidade do TTS

Os cenários realistas de falha são dois: **sem conexão de dados** (trilha, túnel, sinal fraco) e **latência alta** (rede congestionada, API lenta >3s). Outage do Google Cloud e billing estourado são edge cases que não justificam engenharia dedicada.

#### Plano de fallback — sem dados / latência alta

| Prioridade | Solução | Descrição |
|-----------|---------|-----------|
| **1 — Principal** | Cache pré-corrida | Pacote de áudios genéricos baixado antes da corrida (Wi-Fi/4G). Cobre ~70-80% das falas comuns: marcos de km, alertas de pace, motivação |
| **2 — Opção A** | TTS on-device nativo | Android/iOS têm engines TTS nativas. Qualidade inferior mas latência zero, custo zero |
| **3 — Opção B** | Coaching por texto | Notificação/overlay na tela + vibração no relógio. Sem áudio |
| **4 — Opção C** | TTS leve embarcado | Modelo compacto on-device (Piper/Sherpa-ONNX, ~50MB no app). Qualidade intermediária, offline total |

#### Estratégia de custo TTS por fase — Volume × Solução

O gargalo do self-hosted é **pico de concorrência** (corredores correm nos mesmos horários: 6-7h e 18-19h), não volume mensal total.

**Comparação de custo por MRU:**

| Solução | Custo/MRU/mês | Capacidade/unidade | Custo fixo/unidade |
|---------|--------------|-------------------|-------------------|
| Google Neural2 (API) | R$2,88 | Ilimitado (pay-per-use) | R$0 |
| Fish Speech em A10G (RunPod) | R$2,19 | ~1.200 MRU | R$2.628/mês |
| F5-TTS em A100 (RunPod) | R$2,91 | ~3.000 MRU | R$8.718/mês |
| F5-TTS em T4 (RunPod) | R$3,65 | ~480 MRU | R$1.752/mês |
| Piper em CPU (VPS) | R$0,60 | ~200 MRU | R$120/mês |

**Cenários por faixa de volume:**

| Faixa MRU | Custo API/mês | Custo Self-hosted/mês | Solução indicada |
|-----------|-------------|---------------------|-----------------|
| 0-500 (protótipo) | R$0-1.440 | R$2.628 (1× A10G) | **API** — custo menor, zero ops |
| 500-1.200 | R$1.440-3.456 | R$2.628 (1× A10G) | **Empate** — API mais simples |
| 1.200-3.000 | R$3.456-8.640 | R$2.628-5.256 (1-2× A10G) | **Self-hosted começa a valer** |
| 3K-10K | R$8.640-28.800 | R$5.256-21.024 (2-8× A10G) | **Self-hosted** — economia 25-30% |
| 10K-40K | R$28.800-115.200 | R$21-88K (8-34× A10G) | **Self-hosted** — precisa equipe infra |

**Roadmap TTS por fase do produto:**

```
FASE 1 — Protótipo (0-500 MRU)
  → Google Neural2 API + cache de frases comuns
  → Custo: R$0-1.440/mês | Ops: zero

FASE 2 — MVP (500-3K MRU)
  → Google Neural2 API + cache agressivo (-30% custo)
  → Custo: R$1.000-6.000/mês
  → Gatilho de migração: custo TTS > 20% da receita líquida

FASE 3 — Escala (3K-10K MRU)
  → Migrar pra self-hosted (Fish Speech ou F5-TTS em A10G)
  → 2-8 GPUs no RunPod (~R$5-21K/mês)
  → Requer: 1 pessoa de infra (mín. part-time)

FASE 4 — Maturidade (10K+ MRU)
  → Fleet de GPUs dedicado + CDN de áudio
  → Equipe de infra dedicada
  → Avaliar GPUs próprias vs cloud (breakeven ~R$150K/mês)
```

**Ressalvas:**
- Fish Speech e F5-TTS não listam PT-BR como idioma oficial — necessário testar qualidade antes de comprometer migração
- Repository Pattern (Seção 6) protege: trocar Google Neural2 → self-hosted = mudar implementação do TTS repository, não reescrever o app
- Cache de frases comuns reduz custo em 20-30% em qualquer fase — implementar desde o dia 1

#### Veredicto Ponto 2

| Critério | Avaliação |
|----------|-----------|
| Produto sobrevive sem voz? | Sim — fallback por texto/TTS nativo degrada mas não mata |
| Custo TTS escala? | Sim — API até 3K MRU, self-hosted depois |
| Ponto de migração | ~1.200 MRU (self-hosted fica mais barato que API) |
| Risco PT-BR | ⚠️ Testar Fish Speech/F5-TTS em PT-BR antes da Fase 3 |
| **Veredicto** | **GO ✅** — plano de escala claro, fallbacks mapeados |

---

### 7.6 Dimensionamento de Time — AI-First (Ponto 3)

> Premissa: AI é co-builder e co-operator. Claude Code, Cursor, v0, Copilot, agentes de automação. O time humano foca em decisão, criatividade e relacionamento — não em execução repetitiva.

#### Modelo de papéis

**Produto** = produto, growth, conteúdo, ops de negócio, relacionamento operadora
**Tech** = dev Flutter, backend/infra, dados, ML/TTS ops

#### Faixa 1 — Protótipo/MVP (0-3K MRU)

| Papel | Contratado (CLT/PJ) | Terceirizado (freelance/squad) |
|-------|---------------------|-------------------------------|
| **PRODUTO** | | |
| Founder (você) | Produto + growth + ops negócio + rel. operadora | Idem — esse papel não se terceiriza |
| Designer UI/UX | ❌ Não precisa — AI gera telas (v0/Figma AI) + templates | ✅ Pontual: 1 designer p/ identidade visual + design system base (R$3-5K one-shot) |
| Conteúdo corrida | ❌ Não precisa ainda — founder + AI geram os prompts iniciais | ✅ Pontual: consultoria de corrida p/ validar planos de treino (R$2-3K) |
| **TECH** | | |
| Dev Flutter fullstack | 1 dev PJ (R$12-18K/mês) — AI-augmented produz 2-3× | ✅ Squad sob demanda (R$15-25K/mês por sprint de 2 sem) |
| Infra/DevOps | ❌ Firebase managed — não precisa | ❌ Idem |
| ML/TTS | ❌ APIs gerenciadas — não precisa | ❌ Idem |
| **TOTAL FIXO/MÊS** | **R$12-18K** (1 dev) | **R$0 fixo** (tudo pontual) |
| **TOTAL VARIÁVEL** | — | **R$15-25K por sprint** + R$5-8K one-shots |

```
Contratado:  Founder + 1 dev PJ = 2 pessoas
             Custo: R$12-18K/mês fixo
             Vantagem: velocidade constante, contexto acumulado, iteração rápida

Terceirizado: Founder solo + squads sob demanda
              Custo: R$0 fixo, R$15-25K por sprint ativado
              Vantagem: custo zero entre sprints, flexibilidade
              Risco: perda de contexto entre sprints, dependência de briefing
```

**Recomendação Faixa 1:** Contratado. Um bom dev Flutter PJ com AI tools produz como 3. O contexto acumulado no MVP é crítico — terceirizar gera retrabalho.

---

#### Faixa 2 — Escala Inicial (3K-10K MRU)

| Papel | Contratado (CLT/PJ) | Terceirizado (freelance/squad) |
|-------|---------------------|-------------------------------|
| **PRODUTO** | | |
| Founder | Estratégia + rel. operadora + decisões de produto | Idem |
| Growth/CRM | 1 analista PJ (R$5-8K/mês) — automações, campanhas DCB, churn | ✅ Agência de growth (R$8-12K/mês retainer) |
| Conteúdo corrida | 1 consultor part-time (R$3-5K/mês) — planos de treino, sazonalidade | ✅ Freelancer especializado (R$3-5K/mês) |
| **TECH** | | |
| Dev Flutter senior | 1 dev PJ (R$15-22K/mês) — feature lead, AI-augmented | ✅ Mantém squad (R$20-30K/mês contínuo) |
| Dev Flutter pleno | 1 dev PJ (R$8-12K/mês) — features secundárias, bugs | ✅ Incluso no squad |
| Infra/TTS ops | 1 dev part-time (R$6-10K/mês) — migração self-hosted TTS | ✅ Especialista pontual (R$10-15K por migração) |
| **TOTAL FIXO/MÊS** | **R$37-57K** | **R$31-47K** (retainers) |

```
Contratado:  Founder + 4 PJs = 5 pessoas
             Custo: R$37-57K/mês
             Vantagem: time coeso, velocidade, ownership

Terceirizado: Founder + 1 agência + freelancers
              Custo: R$31-47K/mês
              Vantagem: flexibilidade de escopo
              Risco: coordenação de múltiplos fornecedores, founder vira PM full-time
```

**Recomendação Faixa 2:** Híbrido. Core contratado (1 dev senior + 1 growth) + terceirizado pontual (infra TTS, conteúdo). Custo ~R$35-40K/mês.

**Sanity check vs receita:**
- 3K MRU DCB: receita líquida ~R$130K/mês (Seção 7.3 extrapolada)
- Time R$37-57K = 28-44% da receita líquida → saudável (meta: <50%)

---

#### Faixa 3 — Maturidade (10K-40K MRU)

| Papel | Contratado (CLT/PJ) | Terceirizado (freelance/squad) |
|-------|---------------------|-------------------------------|
| **PRODUTO** | | |
| Founder/CEO | Estratégia, operadoras, fundraising | Idem |
| Head de Produto | 1 PM senior (R$15-22K/mês) — roadmap, métricas, priorização | ✅ Fractional CPO (R$10-15K/mês part-time) |
| Growth | 1-2 analistas (R$10-16K/mês) — CRM, campanhas, ASO, retenção | ✅ Agência de growth (R$15-25K/mês) |
| Conteúdo/Coaching | 1 especialista corrida (R$6-10K/mês) — planos, personalização, parcerias | ✅ Freelancer (R$6-10K/mês) |
| **TECH** | | |
| Tech Lead | 1 senior (R$18-28K/mês) — arquitetura, code review, decisões técnicas | ❌ Não terceirizar — ownership crítico |
| Dev Flutter (2-3) | 2-3 devs (R$24-42K/mês) — features, manutenção | ✅ Squad dedicado (R$30-50K/mês) |
| Backend/Infra | 1 dev (R$12-18K/mês) — self-hosted TTS, escala, monitoramento | ✅ DevOps as a service (R$8-15K/mês) |
| Data/ML | 1 dev part-time (R$8-12K/mês) — personalização, modelos, analytics | ✅ Consultoria pontual (R$10-15K por projeto) |
| **TOTAL FIXO/MÊS** | **R$93-148K** | **R$79-130K** |

```
Contratado:  Founder + 7-9 pessoas = 8-10 pessoas
             Custo: R$93-148K/mês
             Vantagem: time forte, cultura, velocidade de escala

Terceirizado: Founder + Tech Lead + mix terceirizado = 3 fixos + fornecedores
              Custo: R$79-130K/mês
              Vantagem: custo marginalmente menor
              Risco: coordenação complexa, cultura fraca, difícil reter talentos
```

**Recomendação Faixa 3:** Predominantemente contratado. Core interno (Tech Lead + 2 devs + PM + Growth) + terceirizado em especialidades pontuais (infra, data projects). Custo ~R$100-120K/mês.

**Sanity check vs receita:**
- 10K MRU DCB: receita líquida ~R$430K/mês
- Time R$100-120K = 23-28% da receita líquida → muito saudável

---

#### Resumo comparativo — Time × Faixa

| | Faixa 1 (0-3K) | Faixa 2 (3K-10K) | Faixa 3 (10K-40K) |
|---|---|---|---|
| **Pessoas (recomendado)** | 2 (founder + 1 dev) | 4-5 (founder + 3-4) | 8-10 (founder + 7-9) |
| **Modelo recomendado** | Contratado | Híbrido | Contratado + pontual |
| **Custo time/mês** | R$12-18K | R$35-40K | R$100-120K |
| **Receita líq./mês** | R$10-130K | R$130-430K | R$430K-1,7M |
| **Time/Receita** | 14-180%* | 8-31% | 7-28% |
| **Papel AI** | Co-builder (gera 60-70% do código, design, copy) | Co-operator (automações CRM, monitoramento, testes) | Amplificador (cada pessoa produz 2-3×) |

*Faixa 1 começa deficitária (normal em MVP) e atinge sustentabilidade a partir de ~5K contratantes DCB.

#### O que AI substitui vs o que não substitui

```
AI SUBSTITUI (não precisa contratar):
  ✅ Designer UI junior — v0, Figma AI, Claude geram telas
  ✅ QA manual — testes automatizados + AI review
  ✅ Copywriter — AI gera copy de marketing, push, onboarding
  ✅ Analista de dados junior — AI processa dashboards, queries
  ✅ DevOps básico — Firebase managed + CI/CD gerado por AI

AI NÃO SUBSTITUI (precisa de humano):
  ❌ Relacionamento com operadora — negociação, contrato, confiança
  ❌ Decisão de produto — priorização, trade-offs, visão
  ❌ Dev senior Flutter — arquitetura, debugging complexo, performance
  ❌ Expertise em corrida — credibilidade, planos seguros, parcerias
  ❌ Growth strategy — experimentação, canais, unit economics
```

#### Veredicto Ponto 3

| Critério | Avaliação |
|----------|-----------|
| MVP viável com founder + 1 dev? | Sim — AI-augmented, 2 pessoas produzem como 5 |
| Custo de time sustentável? | Sim — time/receita < 30% a partir da Faixa 2 |
| Gargalo do founder solo | Faixa 1: founder faz tudo menos código. Faixa 2: precisa delegar growth |
| Quando contratar 1ª pessoa? | Dev Flutter PJ — desde o dia 1 do MVP |
| Quando contratar 2ª pessoa? | Growth/CRM — quando atingir 2-3K MRU |
| Modelo ideal | Contratado no core (dev + growth) + terceirizado em especialidades |
| **Veredicto** | **GO ✅** — time lean viável, plano de crescimento progressivo |

---

### 7.7 Scorecard de Potencial — Gate de Go/No-Go (Etapa 1.8)

| # | Critério | Peso | Nota | Score | Justificativa |
|---|----------|------|------|-------|---------------|
| 1 | Problema é real e doloroso? | 3× | 4 | 12/15 | Claro queria Strava e não fechou — demanda puxada. Corredor casual não sente "dor" sem coach |
| 2 | Diferencial claro vs concorrentes? | 3× | 5 | 15/15 | White-label + Coach IA + gamificação operadora = categoria inexistente |
| 3 | Killer feature implementável no MVP? | 2× | 4 | 8/10 | Coach IA real-time viável (stack validada), pipeline LLM+TTS <2s é desafio técnico real |
| 4 | Modelo de receita faz sentido? | 2× | 5 | 10/10 | DCB avulso = margem ~60%, break-even desde mês 1 com 5K contratantes |
| 5 | Custo por usuário é viável? | 2× | 4 | 8/10 | R$3,55/user/mês vs R$14,90 receita. TTS = 81% do custo, risco de escala mapeado |
| 6 | Canal de distribuição definido? | 1× | 5 | 5/5 | DCB + bundle operadora. Claro como primeiro target, relacionamento existente |
| 7 | Sinergia com portfólio? | 1× | 4 | 4/5 | Vertical Health (RunCoach → GymCoach → Nutri). Stack compartilhada com Voyager |
| 8 | Potencial de viralização? | 1× | 4 | 4/5 | Cards compartilháveis branded = marketing gratuito. Orgânico, não viral loop forte |
| 9 | Execução solo founder viável? | 2× | 4 | 8/10 | AI-first + 1 dev PJ = viável. Stress test 7.6 validou cenários de escala |
| 10 | Timing do mercado favorável? | 1× | 5 | 5/5 | Corrida explodindo no BR (13-20M, +29% eventos), IA mainstream, zero coach IA no BR |
| | **TOTAL** | **18×** | | **79/90** | **GO ✅ — Alto potencial** |

#### Decisão: **GO ✅**

- Score 79/90 → faixa 70-90 = alto potencial
- Todos os 3 stress tests passaram (financeiro, TTS, time)
- Nenhum critério abaixo de 4 — sem ponto cego grave
- Pontos de atenção: latência LLM+TTS <2s (critério 3) e concentração no DCB avulso (critério 4)

#### Foco para Etapa 1.9 (Tik-Taka de Features)

1. **Coach IA — pipeline real-time:** detalhar fluxo exato (evento → LLM → TTS → áudio), latência por etapa, fallbacks
2. **Onboarding assessment:** como alimenta o Coach desde o dia 1, UX dos seletores
3. **Gamificação interna:** sistema de streaks/badges/níveis, gatilhos de upgrade Free→Premium
4. **GPS tracking:** battery drain, background service, precisão, UX do mapa em tempo real
5. **Cards compartilháveis:** geração por LLM, templates, branded content por operadora
6. **Configuração de alertas:** presets manuais vs Coach automático (Free vs Premium)
7. **Benchmark anônimo:** 3 fases (genérico → pessoal → comparativo), quando cada fase ativa
8. **Health Connect/HealthKit:** dados que o Coach consome, permissões, edge cases

---

## Fontes e Referências

### LLM
- [Groq Pricing](https://groq.com/pricing)
- [Qwen 3.5 Benchmarks & Pricing](https://www.digitalapplied.com/blog/qwen-3-5-agentic-ai-benchmarks-guide)
- [Qwen 3.5 Medium Series](https://www.marktechpost.com/2026/02/24/alibaba-qwen-team-releases-qwen-3-5-medium-model-series/)
- [DeepSeek API Pricing](https://api-docs.deepseek.com/quick_start/pricing)
- [DeepSeek V3 Pricing & Providers](https://pricepertoken.com/pricing-page/model/deepseek-deepseek-chat)
- [LLM API Pricing Compared Feb 2026](https://www.tldl.io/resources/llm-api-pricing-2026)
- [Gemini 2.5 Flash Analysis](https://artificialanalysis.ai/models/gemini-2-5-flash)
- [Best Open Source LLM for Portuguese](https://www.siliconflow.com/articles/en/best-open-source-LLM-for-Portuguese)
- [Napolab - Portuguese Language Benchmark](https://github.com/ruanchaves/napolab)
- [DeepSeek V4 News](https://technode.com/2026/03/02/deepseek-plans-v4-multimodal-model-release-this-week-sources-say/)
- [Choosing an LLM in 2026](https://dev.to/superorange0707/choosing-an-llm-in-2026-the-practical-comparison-table-specs-cost-latency-compatibility-354g)

### Arquitetura por Feature P0
- [Advanced Location Tracking in Flutter 2026](https://medium.com/@ali.mohamed.hgr/advanced-location-tracking-in-flutter-the-complete-2026-guide-cce138f2d558)
- [flutter_background_geolocation](https://pub.dev/packages/flutter_background_geolocation)
- [Background Location Tracking in Flutter](https://vibe-studio.ai/insights/handling-background-location-tracking-responsibly-in-flutter)
- [Best Practices for Location Services in Flutter](https://www.appxiom.com/blogs/optimizing-the-implementation-of-location-services-in-flutter/)
- [teqani_rewards — Gamification Package](https://github.com/teqani-org/teqani_rewards)
- [HabitQuest — Gamified Habit Tracker Reference](https://github.com/nalugala-vc/HabitQuest)
- [Gamification in Flutter](https://www.justacademy.co/index.php/blog-detail/gamification-in-flutter-engaging-your-users)
- [Health Connect / HealthKit plugin](https://pub.dev/packages/health)

### TTS
- [ElevenLabs vs Google Cloud TTS](https://aloa.co/ai/comparisons/ai-voice-comparison/elevenlabs-vs-google-cloud-tts/)
- [Cartesia Sonic 3](https://cartesia.ai/sonic)
- [Cartesia Pricing](https://cartesia.ai/pricing)
- [Best TTS APIs 2026](https://www.speechmatics.com/company/articles-and-news/best-tts-apis-in-2025-top-12-text-to-speech-services-for-developers)
- [Groq Orpheus TTS](https://groq.com/blog/canopy-labs-orpheus-tts-is-live-on-groqcloud)
- [F5-TTS pt-br](https://huggingface.co/firstpixel/F5-TTS-pt-br)
- [Coqui XTTS-v2](https://huggingface.co/coqui/XTTS-v2)
- [Kokoro PT-BR on fal.ai](https://fal.ai/models/fal-ai/kokoro/brazilian-portuguese)

### Backend/Infra
- [Appwrite vs Supabase vs Firebase 2026](https://uibakery.io/blog/appwrite-vs-supabase-vs-firebase)
- [Firebase vs Supabase vs Appwrite for Flutter](https://medium.com/@flutter-app/firebase-vs-supabase-vs-appwrite-choosing-the-right-backend-for-your-flutter-app-66e08c45ed48)
- [Supabase vs Firebase vs Appwrite 2026](https://sqlflash.ai/article/20260121_supabase-vs-firebase-vs-appwrite-2026/)
- [Firebase Pricing](https://firebase.google.com/pricing)
- [Firestore Billing Example](https://firebase.google.com/docs/firestore/billing-example)
- [Firestore Pricing Guide (Airbyte)](https://airbyte.com/data-engineering-resources/google-firestore-pricing)
- [Multi-Tenant Apps with Firebase & Flutter](https://vibe-studio.ai/insights/developing-multi-tenant-apps-with-firebase-and-flutter)
- [Firebase Auth Multi-Tenancy](https://fuegoapp.dev/blog/firebase-auth-multi-tenancy/)
- [Building SaaS with Flutter](https://www.metaltoad.com/blog/building-a-saas-application-with-flutter)

---

*Think Tank gerado na Etapa 1.6 do Framework de Ideação. Seções 1-3 preenchidas na Etapa 1.6. Seção 4 preenchida na Etapa 1.7. Seções 5 e 6 preenchidas na Etapa 1.7 (Enriquecimento Técnico completo). Seção 7 preenchida na Etapa 1.8 (Validação de Custos / Go-No-Go). Documento em construção — stress test em andamento.*
