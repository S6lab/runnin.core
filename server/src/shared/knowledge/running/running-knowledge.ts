import corpus from './running-knowledge-corpus.json';
import { getStorageBucket } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

export interface RunningKnowledgeChunk {
  id: string;
  title: string;
  summary: string;
  guidance: string[];
  tags: string[];
  sourceType: 'guideline' | 'systematic_review' | 'meta_analysis' | 'cohort' | 'article';
  sourceTitle: string;
  sourceUrl: string;
}

const RAG_STORAGE_ROOT = 'rag/uploads';
const STORAGE_CACHE_TTL_MS = 5 * 60 * 1000;
const chunks = corpus as RunningKnowledgeChunk[];
let storageChunksCache: { loadedAt: number; chunks: RunningKnowledgeChunk[] } | undefined;
let storageSeedAttempted = false;

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
  let selected = retrieveFromChunks(query, [...storageChunks, ...chunks], limit);
  const includesStorage = selected.some(chunk => storageChunks.includes(chunk));
  if (storageChunks.length > 0 && !includesStorage && limit > 0) {
    const storageCandidate = retrieveFromChunks(query, storageChunks, 1)[0] ?? storageChunks[0];
    selected = [storageCandidate, ...selected].slice(0, limit);
  }
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

    const storageChunks = await readStorageChunks(files);
    storageChunksCache = { loadedAt: now, chunks: storageChunks };
    return storageChunks;
  } catch (err) {
    logger.warn('knowledge.storage.unavailable', {
      err: err instanceof Error ? err.message : String(err),
    });
    storageChunksCache = { loadedAt: now, chunks: [] };
    return [];
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
      const content = buffer.toString('utf8').trim();
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
  const custom = (value as { metadata?: unknown }).metadata;
  if (!custom || typeof custom !== 'object') return {};

  return Object.fromEntries(
    Object.entries(custom as Record<string, unknown>)
      .filter((entry): entry is [string, string] => typeof entry[1] === 'string'),
  );
}

function parseStorageDocument(
  path: string,
  content: string,
  metadata: Record<string, string>,
): RunningKnowledgeChunk[] {
  const jsonChunks = parseStorageJson(content);
  if (jsonChunks.length > 0) return jsonChunks;

  const title = metadata['title'] || metadata['sourceTitle'] || path.split('/').pop() || path;
  const sourceTitle = metadata['sourceTitle'] || title;
  const sourceUrl = metadata['sourceUrl'] || `gs://${path}`;
  const summary = summarizeText(content);
  const guidance = extractGuidance(content);

  return [
    {
      id: `storage-${path}`,
      title,
      summary,
      guidance,
      tags: (metadata['tags'] ?? 'storage,admin-rag')
        .split(',')
        .map(tag => tag.trim())
        .filter(Boolean),
      sourceType: normalizeSourceType(metadata['sourceType']),
      sourceTitle,
      sourceUrl,
    },
  ];
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
  };
}

function summarizeText(content: string): string {
  return content
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 900);
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
