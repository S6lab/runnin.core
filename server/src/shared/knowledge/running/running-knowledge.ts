import corpus from './running-knowledge-corpus.json';

export interface RunningKnowledgeChunk {
  id: string;
  title: string;
  summary: string;
  guidance: string[];
  tags: string[];
  sourceType: 'guideline' | 'systematic_review' | 'meta_analysis' | 'cohort';
  sourceTitle: string;
  sourceUrl: string;
}

const chunks = corpus as RunningKnowledgeChunk[];

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

export function retrieveRunningKnowledge(query: string, limit = 4): RunningKnowledgeChunk[] {
  const queryTokens = tokenize(query);
  return [...chunks]
    .map(chunk => ({ chunk, score: scoreChunk(queryTokens, chunk) }))
    .filter(item => item.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(item => item.chunk);
}

export function formatRunningKnowledgeContext(query: string, limit = 4): string {
  const selected = retrieveRunningKnowledge(query, limit);
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
