# RUNNIN.AI — Coach.AI v3 · Índice Mestre

> Base de conhecimento e comportamento do Coach.AI, organizada **por momento da jornada**. 4 modelos,
> 5 momentos. Produto próprio da Super Seis Lab (operadoras = canal de revenda).
>
> **Snapshot fiel ao implementado (2026-05-20):** embedding = `gemini-embedding-001` (o
> `text-embedding-004` original foi descontinuado/404 na API); **2 personas** (Motivador/Técnico) e
> **1 voz masculina** (Charon).

---

## A jornada em 5 momentos

| Momento | O que acontece | Modelo | Doc |
|---|---|---|---|
| (fundo) | Indexa a ciência pra consulta | `gemini-embedding-001` | **Doc 1** |
| 1. Cadastro | Assessment → monta-se o plano | `gemini-3.1-pro-preview` | **Doc 2** |
| 2. Tela | Textos aparecem (plano, relatórios, checkpoint, copy) | `gemini-3.5-flash` | **Doc 3** |
| 3. Exame | O atleta sobe um exame médico | `gemini-3.5-flash` | **Doc 4** |
| 4. Corrida | A voz fala ao vivo (Charon) | `gemini-2.5-flash-native-audio` | **Doc 5** |

Mapa completo da arquitetura e handoffs: **Doc 0**.

---

## Os documentos

| Doc | Título | Função |
|---|---|---|
| **0** | Arquitetura & Fluxo | O mapa: 4 modelos, 5 momentos, handoffs, "pro decide / flash escreve" |
| **1** | Base de Conhecimento | A ciência (fisiologia → limites legais), indexada por embedding pra RAG |
| **2** | Geração de Plano + Ajuste | O **pro** raciocina: gera plano e decide ajuste (JSON) |
| **3** | Operação de Texto | O **flash** escreve tudo na voz do Coach + compila o pacote da sessão |
| **4** | Multimodal / Exame | O **flash** lê exame médico, extrai dado estruturado, não diagnostica |
| **5** | Voz ao Vivo | A **voz** fala só na corrida; executa o pacote; sem RAG |

---

## Os dois princípios que amarram tudo

1. **"Pro decide, flash escreve."** O modelo caro (`3.1-pro`) só raciocina e emite estrutura/decisão
   (JSON). O rápido (`3.5-flash`) transforma em prosa na voz do Coach.
2. **"A voz só fala na corrida."** Tudo que não é a corrida ativa é **texto** (escrito pelo flash). A voz
   (`2.5-native-audio`) não raciocina nem faz RAG — executa o pacote pré-compilado.

---

## Invariantes (todos os modelos herdam — Doc 1 §R)

Coach é **um só** (2 abordagens: Motivador/Técnico calibram só o vocabulário; 1 voz masculina) · nunca
siglas no que chega ao atleta · nunca diagnostica/prescreve dose ou alimento/discute calorias/recomenda
marca · nunca culpabiliza sessão perdida · ciclo imutável (ajuste só dentro) · sempre encaminha em sinal
de risco.

---

## Onde isto vive no código (runnin.core)

- **Doc 1 (RAG):** `server/src/shared/knowledge/running/running-knowledge-corpus.json` — chunkado por
  subseção (A.1…R.5), embedado em Firestore `rag_chunks` por `gemini-embedding-001`. Seção R = vinculante.
- **Docs 2–5 (prompts):** config-store em `server/src/shared/infra/llm/prompts/` (defaults + override via
  Firestore `app_config/prompts`). Editáveis em `/admin/prompts`.
- **Console por momento:** `/admin/coach-ai` (badge do modelo + prompts + base RAG com upload/reindex/purga).

---

*RUNNIN.AI — Coach.AI v3 · Índice Mestre. v3.1. Super Seis Lab.*
