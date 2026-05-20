# RUNNIN.AI — DOC 0: Arquitetura & Fluxo

> **O que é:** o mapa do sistema. Define os **4 modelos**, os **5 momentos da jornada**, qual modelo atua
> em cada momento, e os **handoffs**. É o documento que amarra os demais.
>
> **Princípio de organização:** os documentos são organizados **por momento da jornada**, não por modelo.
> Modelos mudam (preview vira estável, troca de versão); momentos são estáveis.
>
> **Produto:** runnin.ai, produto próprio da Super Seis Lab. Operadoras (Claro etc.) são canal de revenda.
>
> **Snapshot fiel ao implementado (2026-05-20).** Atualiza a v3 original em dois pontos que mudaram na
> implementação: (1) o embedding migrou de `text-embedding-004` (descontinuado/404 na API) para
> **`gemini-embedding-001`**; (2) o produto opera com **2 personas** (Motivador/Técnico) e **1 voz
> masculina** (Charon).

---

# 1. OS 4 MODELOS

| Modelo | Papel | Natureza |
|---|---|---|
| `gemini-embedding-001` | **Embeddings do RAG** — indexa a base de conhecimento para recuperação por similaridade | Não-generativo |
| `gemini-3.1-pro-preview` | **Raciocínio pesado** — gera o plano e decide os ajustes do checkpoint | Caro, capaz, assíncrono |
| `gemini-3.5-flash` | **Redação e operação** — escreve todo o texto na voz do Coach (relatórios, checkpoint, briefing, copy, revisões) e faz **multimodal** (exame) | Rápido, barato |
| `gemini-2.5-flash-native-audio-preview-12-2025` | **Voz ao vivo** — fala durante a corrida (voz única masculina, Charon) | Tempo real, áudio nativo |

**Total: 4 modelos** = 1 de embedding + 3 de geração, distribuídos em **5 momentos**.

---

# 2. OS 5 MOMENTOS DA JORNADA

| # | Momento | Modelo | Doc |
|---|---|---|---|
| 1 | **Indexação do conhecimento (RAG)** | `gemini-embedding-001` | Doc 1 |
| 2 | **Geração de plano + decisão de ajuste** | `gemini-3.1-pro-preview` | Doc 2 |
| 3 | **Operação de texto** (relatórios, checkpoint, briefing, copy nutricional, revisões, cues) | `gemini-3.5-flash` | Doc 3 |
| 4 | **Multimodal** (leitura de exame médico) | `gemini-3.5-flash` | Doc 4 |
| 5 | **Voz ao vivo** (durante a corrida) | `gemini-2.5-flash-native-audio` | Doc 5 |

O `gemini-3.5-flash` cobre **2 momentos** (operação de texto + multimodal). Os outros cobrem 1 cada.

---

# 3. PRINCÍPIO CENTRAL: "PRO DECIDE, FLASH ESCREVE"

O modelo caro/capaz (`3.1-pro`) é reservado ao **raciocínio**; o rápido/barato (`3.5-flash`) faz toda a
**prosa**.

- **`3.1-pro` produz estrutura/decisão (JSON):** o plano e a decisão de ajuste do checkpoint. É o "o quê".
- **`3.5-flash` produz texto na voz do Coach:** racional, método, briefing, copy, mensagem de checkpoint,
  relatórios, e compila o pacote da sessão. É o "como o atleta lê".

---

# 4. PRINCÍPIO DA VOZ: "SÓ FALA NA CORRIDA"

- A **Voz** (`2.5-native-audio`, Charon) é a única que produz **áudio**, e **só durante a corrida ativa**.
- Todo o resto é **texto na tela**, escrito pelo `3.5-flash`.
- A Voz **não raciocina e não faz RAG** em runtime. Executa o que foi decidido e compilado.

---

# 5. FLUXO DE DADOS (HANDOFFS)

```
Base de Conhecimento (Doc 1)
        │  gemini-embedding-001 (indexa em vetores)
        ▼  RAG (recuperação por similaridade; chunks da seção R são VINCULANTES)
Assessment / histórico / sinais / exame estruturado
        │
        ▼  gemini-3.1-pro-preview  (RACIOCÍNIO: gera plano, decide ajuste — JSON)
        │
        ▼  gemini-3.5-flash  (REDAÇÃO + MULTIMODAL: racional, método, briefing, copy,
        │                     mensagem de checkpoint, relatórios, lê exame, compila PACOTE)
        ▼  pacote da sessão (JSON) + telemetria ao vivo
gemini-2.5-native-audio  (VOZ — só na corrida: narra, alerta, fecha)
```

A Voz **não** acessa o RAG em runtime. Os limites clínicos/legais (seção R do Doc 1) entram no contexto
dos modelos de texto/raciocínio via RAG, marcados como **vinculantes**.

---

# 6. INVARIANTES (TODOS OS MODELOS HERDAM — Doc 1 §R)

- Nunca diagnostica, prescreve dose/alimento/dieta, discute calorias, recomenda marca.
- Nunca usa siglas no que chega ao atleta — sempre por extenso.
- Nunca culpabiliza por sessão perdida.
- Ciclo imutável (ajuste só dentro dele).
- Sempre encaminha a profissional humano em sinal de risco.
- Coach é **um só**: 2 abordagens (**Motivador**/**Técnico**) calibram só o vocabulário; 1 voz masculina.

---

# 7. MAPA DOS DOCUMENTOS

| Doc | Título | Momento | Modelo |
|---|---|---|---|
| **0** | Arquitetura & Fluxo (este) | — | — |
| **1** | Base de Conhecimento + RAG | Indexação | `gemini-embedding-001` |
| **2** | Geração de Plano + Decisão de Ajuste | Raciocínio | `gemini-3.1-pro-preview` |
| **3** | Operação de Texto | Redação | `gemini-3.5-flash` |
| **4** | Multimodal / Exame | Leitura de exame | `gemini-3.5-flash` |
| **5** | Voz ao Vivo | Corrida | `gemini-2.5-flash-native-audio` |

> **Onde isto vive no código:** Doc 1 → `server/src/shared/knowledge/running/running-knowledge-corpus.json`
> (chunkado, embedado em `rag_chunks`). Docs 2–5 → system prompts no config-store
> (`server/src/shared/infra/llm/prompts/`, editáveis em `/admin/prompts`). Console por momento em
> `/admin/coach-ai`.

---

*RUNNIN.AI — Doc 0: Arquitetura & Fluxo. v3.1 — 4 modelos, 5 momentos, "pro decide / flash escreve".
Embedding gemini-embedding-001; 2 personas; 1 voz masculina. Runnin.ai / Super Seis Lab.*
