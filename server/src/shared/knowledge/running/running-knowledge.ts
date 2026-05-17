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
  sourceType: 'guideline' | 'systematic_review' | 'meta_analysis' | 'cohort' | 'article';
  sourceTitle: string;
  sourceUrl: string;
  content?: string;
  embedding?: number[];
  embeddingModel?: string;
  contentHash?: string;
  storagePath?: string;
  chunkIndex?: number;
}

const RAG_STORAGE_ROOT = 'rag/uploads';
const RAG_CHUNKS_COLLECTION = 'rag_chunks';
const STORAGE_CACHE_TTL_MS = 5 * 60 * 1000;
const STORAGE_CHUNK_MAX_CHARS = 2200;
const STORAGE_CHUNK_OVERLAP_CHARS = 280;
const chunks = corpus as RunningKnowledgeChunk[];
let storageChunksCache: { loadedAt: number; chunks: RunningKnowledgeChunk[] } | undefined;
let storageSeedAttempted = false;
let embeddingService: GeminiEmbeddingService | undefined;

type StorageRagFile = {
  name: string;
  download(): Promise<[Buffer]>;
  getMetadata(): Promise<unknown[]>;
};

const webSeedSources: RunningKnowledgeChunk[] = [
  {
    id: 'web-seed-running-load',
    title: 'Carga de treino e risco de lesoes em corredores',
    summary:
      'Revisao sistematica sobre parametros de treino associados a lesoes em corrida, util para dosar progressao de volume, frequencia e intensidade.',
    guidance: [
      'Individualizar progressao de carga por experiencia, sintomas e tolerancia.',
      'Evitar aumento automatico de volume quando houver fadiga ou dor persistente.',
      'Priorizar consistencia sustentavel em vez de saltos bruscos de quilometragem.',
    ],
    tags: ['load-management', 'injury-risk', 'progression', 'novice'],
    sourceType: 'systematic_review',
    sourceTitle: 'The Association Between Running Injuries and Training Parameters: A Systematic Review',
    sourceUrl: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC9528699/',
  },
  {
    id: 'web-seed-intensity-distribution',
    title: 'Distribuicao de intensidade em treino de endurance',
    summary:
      'Revisao com meta-analise comparando modelos de distribuicao de intensidade em atletas de endurance.',
    guidance: [
      'Manter predominio de sessoes leves na semana.',
      'Dosar treinos de qualidade conforme nivel e recuperacao do corredor.',
      'Separar estimulos duros com dias leves ou descanso.',
    ],
    tags: ['intensity-distribution', 'easy-run', 'interval', 'tempo'],
    sourceType: 'systematic_review',
    sourceTitle:
      "Comparison of Polarized Versus Other Types of Endurance Training Intensity Distribution on Athletes' Endurance Performance",
    sourceUrl: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC11329428/',
  },
  {
    id: 'web-seed-hiit-vo2max',
    title: 'HIIT e melhora de VO2max',
    summary:
      'Meta-analise sobre treinabilidade de VO2max com intervalados de alta intensidade em humanos.',
    guidance: [
      'Usar intervalados como ferramenta especifica, nao como base exclusiva do plano.',
      'Introduzir alta intensidade apenas quando a base aerobica e recuperacao permitirem.',
      'Evitar combinar muitas sessoes duras na mesma semana.',
    ],
    tags: ['hiit', 'vo2max', 'interval', 'advanced-load'],
    sourceType: 'meta_analysis',
    sourceTitle: 'VO2max Trainability and High Intensity Interval Training in Humans: A Meta-Analysis',
    sourceUrl: 'https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0073182',
  },
];

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
    [chunk.title, chunk.summary, chunk.guidance.join(' '), chunk.tags.join(' ')].join(' '),
  );
  const haystackSet = new Set(haystack);

  let score = 0;
  for (const token of queryTokens) {
    if (haystackSet.has(token)) score += 3;
    if (chunk.tags.some(tag => tag.includes(token))) score += 2;
  }

  if (chunk.sourceType === 'guideline' || chunk.sourceType === 'systematic_review') {
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

export async function retrieveRunningKnowledge(query: string, limit = 4): Promise<RunningKnowledgeChunk[]> {
  const storageChunks = await getStorageRunningKnowledge();
  const selectedStorage = await retrieveStorageKnowledge(query, storageChunks, Math.max(1, Math.min(3, limit)));
  const selectedBase = retrieveFromChunks(query, chunks, Math.max(0, limit - selectedStorage.length));
  let selected = [...selectedStorage, ...selectedBase].slice(0, limit);
  if (selected.length > 0) return selected;
  return retrieveFromChunks(query, chunks, limit);
}

export async function formatRunningKnowledgeContext(query: string, limit = 4): Promise<string> {
  const selected = await retrieveRunningKnowledge(query, limit);
  if (selected.length === 0) return '';

  return selected
    .map((chunk, index) => {
      const guidance = chunk.guidance.map(item => `- ${item}`).join('\n');
      return [
        `[KB${index + 1}] ${chunk.title}`,
        `Resumo: ${chunk.summary}`,
        ...(chunk.content ? [`Trecho: ${compactText(chunk.content).slice(0, 1400)}`] : []),
        'Aplicacao pratica:',
        guidance,
        `Fonte: ${chunk.sourceTitle} (${chunk.sourceType})`,
        `URL: ${chunk.sourceUrl}`,
      ].join('\n');
    })
    .join('\n\n');
}

export function getRunningKnowledgeCorpus(): RunningKnowledgeChunk[] {
  return chunks;
}

export async function getRunningKnowledgeCorpusWithStorage(): Promise<RunningKnowledgeChunk[]> {
  const storageChunks = await getStorageRunningKnowledge();
  return [...storageChunks, ...chunks];
}

/**
 * Limpa o cache de chunks do Storage forçando relê + reindex na próxima
 * query. Chamar quando admin sobe arquivo novo pra ele aparecer
 * imediatamente nas queries (sem ter que esperar TTL de 5min).
 */
export function invalidateRunningKnowledgeStorageCache(): void {
  storageChunksCache = undefined;
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

    if (files.length === 0 && !storageSeedAttempted) {
      storageSeedAttempted = true;
      await seedStorageFromWebArticles();
      [files] = await bucket.getFiles({ prefix: `${RAG_STORAGE_ROOT}/` });
      files = files.filter(file => !file.name.endsWith('/'));
    }

    const parsedChunks = await readStorageChunks(files);
    const storageChunks = await syncEmbeddedStorageChunks(parsedChunks);
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

async function seedStorageFromWebArticles(): Promise<void> {
  const bucket = getStorageBucket();
  await Promise.all(
    webSeedSources.map(async source => {
      let articleText = '';
      try {
        const res = await fetch(source.sourceUrl, {
          headers: {
            accept: 'text/html,text/plain;q=0.9,*/*;q=0.8',
            'user-agent': 'runnin-rag-seeder/1.0',
          },
        });
        if (res.ok) {
          articleText = htmlToText(await res.text()).slice(0, 12000);
        }
      } catch (err) {
        logger.warn('knowledge.storage.seed_fetch_failed', {
          sourceUrl: source.sourceUrl,
          err: err instanceof Error ? err.message : String(err),
        });
      }

      const content = [
        `Title: ${source.title}`,
        `Source: ${source.sourceTitle}`,
        `URL: ${source.sourceUrl}`,
        '',
        `Summary: ${source.summary}`,
        '',
        'Practical guidance:',
        ...source.guidance.map(item => `- ${item}`),
        '',
        'Article excerpt:',
        articleText || source.summary,
      ].join('\n');

      await bucket.file(`${RAG_STORAGE_ROOT}/web-seed/${source.id}.txt`).save(content, {
        contentType: 'text/plain; charset=utf-8',
        metadata: {
          metadata: {
            ragStatus: 'ready',
            source: 'web-seed',
            sourceUrl: source.sourceUrl,
            sourceTitle: source.sourceTitle,
            sourceType: source.sourceType,
            title: source.title,
            tags: source.tags.join(','),
          },
        },
      });
    }),
  );

  logger.info('knowledge.storage.seeded', { count: webSeedSources.length });
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

async function retrieveStorageKnowledge(
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

async function syncEmbeddedStorageChunks(
  parsedChunks: RunningKnowledgeChunk[],
): Promise<RunningKnowledgeChunk[]> {
  if (parsedChunks.length === 0) return [];

  try {
    const service = getEmbeddingService();
    const db = getFirestore();

    const indexedChunks: RunningKnowledgeChunk[] = [];
    for (const chunk of parsedChunks) {
      const docRef = db.collection(RAG_CHUNKS_COLLECTION).doc(chunk.id);
      const doc = await docRef.get();
      const existing = doc.exists ? normalizeIndexedChunk(doc.data()) : undefined;

      if (
        existing &&
        existing.contentHash === chunk.contentHash &&
        existing.embeddingModel === service.modelName &&
        Array.isArray(existing.embedding) &&
        existing.embedding.length > 0
      ) {
        indexedChunks.push(existing);
        continue;
      }

      const embeddingText = [
        chunk.title,
        chunk.summary,
        chunk.guidance.join('\n'),
        chunk.content ?? '',
        `Tags: ${chunk.tags.join(', ')}`,
      ].filter(Boolean).join('\n\n');
      const embedding = await service.embedDocument(embeddingText, chunk.title);
      const indexed = {
        ...chunk,
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
    value === 'article'
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

function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
}
