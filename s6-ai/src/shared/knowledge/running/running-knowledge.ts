import corpus from './running-knowledge-corpus.json';
import { createHash } from 'node:crypto';
import { getFirestore, getStorageBucket } from '@shared/infra/firebase/firebase.client';
import { GeminiEmbeddingService } from '@shared/infra/embedding/gemini-embedding.service';
import { logger } from '@shared/logger/logger';
import mammoth from 'mammoth';
import { PDFParse } from 'pdf-parse';

export interface RunningKnowledgeChunk {
  id: string;
  title: string;
  summary: string;
  guidance: string[];
  tags: string[];
  sourceType: 'guideline' | 'systematic_review' | 'meta_analysis' | 'cohort' | 'article' | 'curado';
  sourceTitle: string;
  sourceUrl: string;
  content?: string;
  embedding?: number[];
  embeddingModel?: string;
  contentHash?: string;
  storagePath?: string;
  chunkIndex?: number;
  // Metadados da base v3 (Doc 1). `secao` = ID da subseção (ex "H.3").
  // `vinculante` marca limites clínicos/legais (seção R) que NUNCA são
  // opcionais — a recuperação garante a inclusão deles em tema sensível.
  secao?: string;
  tema?: string;
  categoria?: string[];
  nivel?: string;
  encaminhamento?: string[];
  vinculante?: boolean;
}

const RAG_STORAGE_ROOT = 'rag/uploads';
const RAG_CHUNKS_COLLECTION = 'rag_chunks';
const STORAGE_CACHE_TTL_MS = 5 * 60 * 1000;
const STORAGE_CHUNK_MAX_CHARS = 2200;
const STORAGE_CHUNK_OVERLAP_CHARS = 280;
const chunks = corpus as RunningKnowledgeChunk[];
let storageChunksCache: { loadedAt: number; chunks: RunningKnowledgeChunk[] } | undefined;
let corpusChunksCache: { loadedAt: number; chunks: RunningKnowledgeChunk[] } | undefined;
let embeddingService: GeminiEmbeddingService | undefined;

type StorageRagFile = {
  name: string;
  download(): Promise<[Buffer]>;
  getMetadata(): Promise<unknown[]>;
};

function tokenize(value: string): string[] {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .split(/[^a-z0-9]+/)
    .filter(token => token.length >= 3);
}

function scoreChunk(queryTokens: string[], chunk: RunningKnowledgeChunk): number {
  const haystack = tokenize(
    [
      chunk.title,
      chunk.summary,
      chunk.guidance.join(' '),
      chunk.tags.join(' '),
      (chunk.categoria ?? []).join(' '),
      chunk.tema ?? '',
    ].join(' '),
  );
  const haystackSet = new Set(haystack);

  let score = 0;
  for (const token of queryTokens) {
    if (haystackSet.has(token)) score += 3;
    if (chunk.tags.some(tag => tag.includes(token))) score += 2;
    if ((chunk.categoria ?? []).some(cat => cat.includes(token))) score += 2;
  }

  if (
    chunk.sourceType === 'guideline' ||
    chunk.sourceType === 'systematic_review' ||
    chunk.sourceType === 'curado'
  ) {
    score += 1;
  }

  return score;
}

function retrieveFromChunks(
  query: string,
  sourceChunks: RunningKnowledgeChunk[],
  limit = 4,
): RunningKnowledgeChunk[] {
  const queryTokens = tokenize(query);
  return [...sourceChunks]
    .map(chunk => ({ chunk, score: scoreChunk(queryTokens, chunk) }))
    .filter(item => item.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(item => item.chunk);
}

// Termos que tornam a query "sensível" (clínico/segurança) — quando
// presentes, garantimos a inclusão dos chunks vinculantes (seção R) na
// recuperação, mesmo que a similaridade vetorial não os colocaria no top-K.
const SENSITIVE_QUERY_TOKENS = [
  'dor', 'lesao', 'lesão', 'fratura', 'tendao', 'tendão', 'joelho', 'canela',
  'coracao', 'coração', 'cardiaco', 'cardíaco', 'peito', 'tontura', 'falta de ar',
  'gestante', 'gestacao', 'gestação', 'gravida', 'grávida', 'menstrual',
  'amenorreia', 'amenorréia', 'ferritina', 'anemia', 'diabetes', 'hipertensao',
  'hipertensão', 'asma', 'caloria', 'dieta', 'peso', 'suplemento', 'medicamento',
  'antiinflamatorio', 'anti-inflamatório', 'sangue', 'exame', 'pressao', 'pressão',
];

function isSensitiveQuery(query: string): boolean {
  const q = query.toLowerCase();
  return SENSITIVE_QUERY_TOKENS.some(token => q.includes(token));
}

export async function retrieveRunningKnowledge(query: string, limit = 4): Promise<RunningKnowledgeChunk[]> {
  const [corpusChunks, storageChunks] = await Promise.all([
    getCorpusKnowledge(),
    getStorageRunningKnowledge(),
  ]);
  const all = [...corpusChunks, ...storageChunks];
  if (all.length === 0) return [];

  const ranked = await retrieveByEmbeddingOrKeyword(query, all, limit);
  return ensureBindingChunks(query, ranked, all, limit);
}

/**
 * Garante que, em queries de tema sensível, pelo menos um chunk vinculante
 * (seção R — limites clínicos/legais) esteja no contexto. Esses limites
 * NÃO são opcionais; sem isso a recuperação puramente semântica poderia
 * deixá-los de fora e o modelo perder o guardrail.
 */
function ensureBindingChunks(
  query: string,
  ranked: RunningKnowledgeChunk[],
  all: RunningKnowledgeChunk[],
  limit: number,
): RunningKnowledgeChunk[] {
  if (!isSensitiveQuery(query)) return ranked;
  if (ranked.some(c => c.vinculante)) return ranked;

  const queryTokens = tokenize(query);
  const binding = all
    .filter(c => c.vinculante)
    .map(chunk => ({ chunk, score: scoreChunk(queryTokens, chunk) }))
    .sort((a, b) => b.score - a.score)
    .map(item => item.chunk);
  if (binding.length === 0) return ranked;

  // Injeta o limite mais relevante e mantém o teto de `limit`.
  return [binding[0]!, ...ranked].slice(0, Math.max(limit, 1));
}

export async function formatRunningKnowledgeContext(query: string, limit = 4): Promise<string> {
  const selected = await retrieveRunningKnowledge(query, limit);
  if (selected.length === 0) return '';

  return selected
    .map((chunk, index) => {
      const guidance = chunk.guidance.map(item => `- ${item}`).join('\n');
      return [
        `[KB${index + 1}]${chunk.vinculante ? ' [VINCULANTE]' : ''}${chunk.secao ? ` (${chunk.secao})` : ''} ${chunk.title}`,
        `Resumo: ${chunk.summary}`,
        ...(chunk.content ? [`Trecho: ${compactText(chunk.content).slice(0, 1400)}`] : []),
        'Aplicacao pratica:',
        guidance,
        ...(chunk.encaminhamento && chunk.encaminhamento.length > 0
          ? [`Encaminhar a: ${chunk.encaminhamento.join(', ')}`]
          : []),
        `Fonte: ${chunk.sourceTitle} (${chunk.sourceType})`,
      ].join('\n');
    })
    .join('\n\n');
}

export function getRunningKnowledgeCorpus(): RunningKnowledgeChunk[] {
  return chunks;
}

export async function getRunningKnowledgeCorpusWithStorage(): Promise<RunningKnowledgeChunk[]> {
  const [corpusChunks, storageChunks] = await Promise.all([
    getCorpusKnowledge(),
    getStorageRunningKnowledge(),
  ]);
  return [...corpusChunks, ...storageChunks];
}

/**
 * Limpa os caches de chunks (corpus Doc 1 + Storage) forçando relê +
 * reindex na próxima query. Chamar quando admin troca a base ou sobe
 * arquivo novo (sem ter que esperar o TTL de 5min).
 */
export function invalidateRunningKnowledgeStorageCache(): void {
  storageChunksCache = undefined;
  corpusChunksCache = undefined;
}

/**
 * Carrega o corpus canônico (Doc 1) já embedado em `rag_chunks`. Diferente
 * do Storage (uploads do admin), o corpus vem do JSON versionado e é a base
 * científica oficial. Cache em memória com o mesmo TTL do Storage.
 */
async function getCorpusKnowledge(): Promise<RunningKnowledgeChunk[]> {
  const now = Date.now();
  if (corpusChunksCache && now - corpusChunksCache.loadedAt < STORAGE_CACHE_TTL_MS) {
    return corpusChunksCache.chunks;
  }
  const embedded = await syncEmbeddedChunks(chunks);
  corpusChunksCache = { loadedAt: now, chunks: embedded };
  return embedded;
}

async function getStorageRunningKnowledge(): Promise<RunningKnowledgeChunk[]> {
  const now = Date.now();
  if (storageChunksCache && now - storageChunksCache.loadedAt < STORAGE_CACHE_TTL_MS) {
    return storageChunksCache.chunks;
  }

  try {
    const bucket = getStorageBucket();
    let [files] = await bucket.getFiles({ prefix: `${RAG_STORAGE_ROOT}/` });
    files = files.filter(file => !file.name.endsWith('/'));

    const parsedChunks = await readStorageChunks(files);
    const storageChunks = await syncEmbeddedChunks(parsedChunks);
    storageChunksCache = { loadedAt: now, chunks: storageChunks };
    // Marca cada doc admin como indexed depois de embedding rodar OK.
    void markDocumentsIndexed(storageChunks);
    return storageChunks;
  } catch (err) {
    logger.warn('knowledge.storage.unavailable', {
      err: err instanceof Error ? err.message : String(err),
    });
    storageChunksCache = { loadedAt: now, chunks: [] };
    return [];
  }
}

/**
 * Atualiza ragStatus='indexed' + chunkCount nos docs Firestore
 * rag_documents que correspondem aos chunks recém-indexados. Permite
 * que admin veja no painel quais arquivos já foram processados.
 */
async function markDocumentsIndexed(chunks: RunningKnowledgeChunk[]): Promise<void> {
  try {
    const db = (await import('@shared/infra/firebase/firebase.client')).getFirestore();
    // Agrupa chunks por sourcePath (cada source = 1 file no Storage)
    const byPath = new Map<string, number>();
    for (const c of chunks) {
      if (!c.storagePath) continue;
      byPath.set(c.storagePath, (byPath.get(c.storagePath) ?? 0) + 1);
    }
    if (byPath.size === 0) return;
    const col = db.collection('rag_documents');
    const now = new Date().toISOString();
    await Promise.all(
      Array.from(byPath.entries()).map(async ([path, count]) => {
        // 1) Doc novo escreve storagePath; 2) Doc legado escreveu só `path`.
        // 3) Doc id determinístico = path.replace('/', '__'). Tentamos os
        // três caminhos antes de desistir.
        try {
          // Tentativa 1: query pelo novo campo storagePath
          let snap = await col.where('storagePath', '==', path).limit(1).get();
          // Tentativa 2: query pelo campo legado path
          if (snap.empty) {
            snap = await col.where('path', '==', path).limit(1).get();
          }
          if (!snap.empty) {
            await snap.docs[0].ref.set(
              { ragStatus: 'indexed', chunkCount: count, indexedAt: now, storagePath: path },
              { merge: true },
            );
            return;
          }
          // Tentativa 3: doc id determinístico
          const deterministicId = path.replace(/\//g, '__');
          const docRef = col.doc(deterministicId);
          await docRef.set(
            { ragStatus: 'indexed', chunkCount: count, indexedAt: now, storagePath: path },
            { merge: true },
          );
        } catch (err) {
          logger.warn('knowledge.storage.mark_indexed_one_failed', {
            path,
            err: err instanceof Error ? err.message : String(err),
          });
        }
      }),
    );
  } catch (err) {
    logger.warn('knowledge.storage.mark_indexed_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
  }
}

async function readStorageChunks(files: StorageRagFile[]): Promise<RunningKnowledgeChunk[]> {
  const result: RunningKnowledgeChunk[] = [];

  for (const file of files) {
    try {
      const [downloadResult, metadataResult] = await Promise.all([
        file.download(),
        file.getMetadata(),
      ]);
      const buffer = downloadResult[0];
      const metadata = normalizeFileMetadata(metadataResult[0]);
      const content = (await extractStorageText(file.name, buffer, metadata)).trim();
      if (!content) continue;
      result.push(...parseStorageDocument(file.name, content, metadata));
    } catch (err) {
      logger.warn('knowledge.storage.file_skipped', {
        file: file.name,
        err: err instanceof Error ? err.message : String(err),
      });
    }
  }

  return result;
}

function normalizeFileMetadata(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object') return {};
  const topLevel = value as Record<string, unknown>;
  const custom = (value as { metadata?: unknown }).metadata;
  const customMetadata = custom && typeof custom === 'object'
    ? Object.fromEntries(
        Object.entries(custom as Record<string, unknown>)
          .filter((entry): entry is [string, string] => typeof entry[1] === 'string'),
      )
    : {};

  return {
    ...customMetadata,
    ...(typeof topLevel['contentType'] === 'string'
      ? { contentType: topLevel['contentType'] }
      : {}),
  };
}

async function extractStorageText(
  path: string,
  buffer: Buffer,
  metadata: Record<string, string>,
): Promise<string> {
  const extension = extensionFromPath(path);
  const contentType = metadata['contentType'] ?? '';

  if (extension === 'pdf' || contentType.includes('pdf')) {
    const parser = new PDFParse({ data: buffer });
    try {
      const data = await parser.getText();
      return data.text;
    } finally {
      await parser.destroy().catch(() => undefined);
    }
  }

  if (
    extension === 'docx' ||
    contentType === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ) {
    const data = await mammoth.extractRawText({ buffer });
    return data.value;
  }

  if (extension === 'doc') {
    logger.warn('knowledge.storage.unsupported_doc_format', { file: path });
    return '';
  }

  return buffer.toString('utf8');
}

function extensionFromPath(path: string): string {
  const fileName = path.split('/').pop() ?? path;
  const dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex === fileName.length - 1) return '';
  return fileName.substring(dotIndex + 1).toLowerCase();
}

function parseStorageDocument(
  path: string,
  content: string,
  metadata: Record<string, string>,
): RunningKnowledgeChunk[] {
  const jsonChunks = parseStorageJson(content);
  if (jsonChunks.length > 0) {
    return jsonChunks.map((chunk, index) => enrichStorageChunk(chunk, path, index));
  }

  const title = metadata['title'] || metadata['sourceTitle'] || path.split('/').pop() || path;
  const sourceTitle = metadata['sourceTitle'] || title;
  const sourceUrl = metadata['sourceUrl'] || `gs://${path}`;
  const textChunks = splitTextIntoChunks(content);

  return textChunks.map((chunkContent, index) => {
    const chunkTitle = textChunks.length > 1 ? `${title} - parte ${index + 1}` : title;
    return enrichStorageChunk({
      id: `storage-${path}-${index}`,
      title,
      summary: summarizeText(chunkContent),
      guidance: extractGuidance(chunkContent),
      tags: (metadata['tags'] ?? 'storage,admin-rag')
        .split(',')
        .map(tag => tag.trim())
        .filter(Boolean),
      sourceType: normalizeSourceType(metadata['sourceType']),
      sourceTitle,
      sourceUrl,
      content: chunkContent,
    }, path, index, chunkTitle);
  });
}

function parseStorageJson(content: string): RunningKnowledgeChunk[] {
  try {
    const parsed = JSON.parse(content) as unknown;
    const candidate = Array.isArray(parsed) ? parsed : [parsed];
    return candidate
      .map((item, index) => normalizeStorageJsonChunk(item, index))
      .filter((item): item is RunningKnowledgeChunk => Boolean(item));
  } catch (_) {
    return [];
  }
}

function normalizeStorageJsonChunk(item: unknown, index: number): RunningKnowledgeChunk | undefined {
  if (!item || typeof item !== 'object') return undefined;
  const record = item as Record<string, unknown>;
  const title = stringValue(record['title']);
  const summary = stringValue(record['summary']);
  if (!title || !summary) return undefined;

  return {
    id: stringValue(record['id']) || `storage-json-${index}`,
    title,
    summary,
    guidance: arrayOfStrings(record['guidance']),
    tags: arrayOfStrings(record['tags']),
    sourceType: normalizeSourceType(stringValue(record['sourceType'])),
    sourceTitle: stringValue(record['sourceTitle']) || title,
    sourceUrl: stringValue(record['sourceUrl']) || '',
    content: stringValue(record['content']) || stringValue(record['text']) || stringValue(record['body']),
  };
}

function summarizeText(content: string): string {
  return content
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 900);
}

function compactText(content: string): string {
  return content.replace(/\s+/g, ' ').trim();
}

function splitTextIntoChunks(content: string): string[] {
  const paragraphs = content
    .split(/\n{2,}/)
    .map(paragraph => paragraph.replace(/\s+/g, ' ').trim())
    .filter(Boolean);

  const result: string[] = [];
  let current = '';

  for (const paragraph of paragraphs.length > 0 ? paragraphs : [compactText(content)]) {
    if (!current) {
      current = paragraph;
      continue;
    }

    if (`${current}\n\n${paragraph}`.length <= STORAGE_CHUNK_MAX_CHARS) {
      current = `${current}\n\n${paragraph}`;
      continue;
    }

    result.push(current);
    const overlap = current.slice(Math.max(0, current.length - STORAGE_CHUNK_OVERLAP_CHARS));
    current = `${overlap}\n\n${paragraph}`.trim();
  }

  if (current) result.push(current);
  return result.flatMap(chunk => splitOversizedChunk(chunk));
}

function splitOversizedChunk(content: string): string[] {
  if (content.length <= STORAGE_CHUNK_MAX_CHARS) return [content];

  const chunks: string[] = [];
  let start = 0;
  while (start < content.length) {
    const end = Math.min(content.length, start + STORAGE_CHUNK_MAX_CHARS);
    chunks.push(content.slice(start, end).trim());
    if (end === content.length) break;
    start = Math.max(0, end - STORAGE_CHUNK_OVERLAP_CHARS);
  }
  return chunks.filter(Boolean);
}

function enrichStorageChunk(
  chunk: RunningKnowledgeChunk,
  storagePath: string,
  chunkIndex: number,
  titleOverride?: string,
): RunningKnowledgeChunk {
  const content = chunk.content || [chunk.title, chunk.summary, ...chunk.guidance].join('\n');
  const contentHash = hashText(content);
  return {
    ...chunk,
    id: stableStorageChunkId(storagePath, chunkIndex),
    title: titleOverride ?? chunk.title,
    sourceUrl: chunk.sourceUrl || `gs://${storagePath}`,
    storagePath,
    chunkIndex,
    content,
    contentHash,
  };
}

async function retrieveByEmbeddingOrKeyword(
  query: string,
  sourceChunks: RunningKnowledgeChunk[],
  limit: number,
): Promise<RunningKnowledgeChunk[]> {
  if (limit <= 0 || sourceChunks.length === 0) return [];

  const chunksWithEmbedding = sourceChunks.filter(chunk => Array.isArray(chunk.embedding));
  if (chunksWithEmbedding.length === 0) return retrieveFromChunks(query, sourceChunks, limit);

  try {
    const queryEmbedding = await getEmbeddingService().embedQuery(query);
    if (queryEmbedding.length === 0) return retrieveFromChunks(query, sourceChunks, limit);

    const semanticMatches = chunksWithEmbedding
      .map(chunk => ({
        chunk,
        score: cosineSimilarity(queryEmbedding, chunk.embedding ?? []),
      }))
      .filter(item => item.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map(item => item.chunk);

    if (semanticMatches.length > 0) return semanticMatches;
  } catch (err) {
    logger.warn('knowledge.embedding.query_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
  }

  return retrieveFromChunks(query, sourceChunks, limit);
}

async function syncEmbeddedChunks(
  parsedChunks: RunningKnowledgeChunk[],
): Promise<RunningKnowledgeChunk[]> {
  if (parsedChunks.length === 0) return [];

  try {
    const service = getEmbeddingService();
    const db = getFirestore();

    const indexedChunks: RunningKnowledgeChunk[] = [];
    for (const chunk of parsedChunks) {
      // Chunks do corpus (Doc 1) não trazem contentHash; deriva do conteúdo
      // pra reindex idempotente (só reembeda quando o texto muda de fato).
      const contentHash = chunk.contentHash ?? hashText(
        [chunk.title, chunk.summary, chunk.guidance.join('\n'), chunk.content ?? ''].join('\n'),
      );
      const docRef = db.collection(RAG_CHUNKS_COLLECTION).doc(chunk.id);
      const doc = await docRef.get();
      const existing = doc.exists ? normalizeIndexedChunk(doc.data()) : undefined;

      if (
        existing &&
        existing.contentHash === contentHash &&
        existing.embeddingModel === service.modelName &&
        Array.isArray(existing.embedding) &&
        existing.embedding.length > 0
      ) {
        indexedChunks.push(existing);
        continue;
      }

      const embeddingText = [
        chunk.secao ? `Seção ${chunk.secao}` : '',
        chunk.title,
        chunk.tema ?? '',
        chunk.summary,
        chunk.guidance.join('\n'),
        chunk.content ?? '',
        `Tags: ${[...chunk.tags, ...(chunk.categoria ?? [])].join(', ')}`,
      ].filter(Boolean).join('\n\n');
      const embedding = await service.embedDocument(embeddingText, chunk.title);
      const indexed = {
        ...chunk,
        contentHash,
        embedding,
        embeddingModel: service.modelName,
      };

      await docRef.set({
        ...indexed,
        updatedAt: new Date().toISOString(),
      }, { merge: true });
      indexedChunks.push(indexed);
    }

    return indexedChunks;
  } catch (err) {
    logger.warn('knowledge.embedding.index_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
    return parsedChunks;
  }
}

function normalizeIndexedChunk(value: unknown): RunningKnowledgeChunk | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const record = value as Record<string, unknown>;
  const title = stringValue(record['title']);
  const summary = stringValue(record['summary']);
  if (!title || !summary) return undefined;

  return {
    id: stringValue(record['id']) || '',
    title,
    summary,
    guidance: arrayOfStrings(record['guidance']),
    tags: arrayOfStrings(record['tags']),
    sourceType: normalizeSourceType(stringValue(record['sourceType'])),
    sourceTitle: stringValue(record['sourceTitle']) || title,
    sourceUrl: stringValue(record['sourceUrl']) || '',
    content: stringValue(record['content']),
    embedding: arrayOfNumbers(record['embedding']),
    embeddingModel: stringValue(record['embeddingModel']),
    contentHash: stringValue(record['contentHash']),
    storagePath: stringValue(record['storagePath']),
    chunkIndex: typeof record['chunkIndex'] === 'number' ? record['chunkIndex'] : undefined,
    secao: stringValue(record['secao']),
    tema: stringValue(record['tema']),
    categoria: arrayOfStrings(record['categoria']),
    nivel: stringValue(record['nivel']),
    encaminhamento: arrayOfStrings(record['encaminhamento']),
    vinculante: record['vinculante'] === true,
  };
}

function getEmbeddingService(): GeminiEmbeddingService {
  embeddingService ??= new GeminiEmbeddingService();
  return embeddingService;
}

function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length === 0 || b.length === 0 || a.length !== b.length) return 0;

  let dot = 0;
  let aMagnitude = 0;
  let bMagnitude = 0;
  for (let i = 0; i < a.length; i += 1) {
    dot += a[i]! * b[i]!;
    aMagnitude += a[i]! * a[i]!;
    bMagnitude += b[i]! * b[i]!;
  }

  const denominator = Math.sqrt(aMagnitude) * Math.sqrt(bMagnitude);
  return denominator > 0 ? dot / denominator : 0;
}

function hashText(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function stableStorageChunkId(path: string, chunkIndex: number): string {
  return `storage_${hashText(`${path}:${chunkIndex}`).slice(0, 40)}`;
}

function extractGuidance(content: string): string[] {
  const bullets = content
    .split('\n')
    .map(line => line.trim())
    .filter(line => /^[-*]\s+\S/.test(line))
    .map(line => line.replace(/^[-*]\s+/, ''))
    .slice(0, 4);

  if (bullets.length > 0) return bullets;
  return ['Considerar este documento do Storage como contexto de apoio para personalizar treino e recuperacao.'];
}

function normalizeSourceType(value: string | undefined): RunningKnowledgeChunk['sourceType'] {
  if (
    value === 'guideline' ||
    value === 'systematic_review' ||
    value === 'meta_analysis' ||
    value === 'cohort' ||
    value === 'article' ||
    value === 'curado'
  ) {
    return value;
  }
  return 'article';
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

function arrayOfStrings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === 'string' && item.trim().length > 0);
}

function arrayOfNumbers(value: unknown): number[] | undefined {
  if (!Array.isArray(value)) return undefined;
  const numbers = value.filter((item): item is number => typeof item === 'number' && Number.isFinite(item));
  return numbers.length > 0 ? numbers : undefined;
}

