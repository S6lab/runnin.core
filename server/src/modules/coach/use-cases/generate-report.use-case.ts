import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Run } from '@modules/runs/domain/run.entity';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente.
Gere análises técnicas detalhadas de corrida em português brasileiro, falando diretamente com o corredor.
Seja específico com dados reais fornecidos e transforme a análise em orientação prática.
Inclua: (1) avaliação do desempenho geral, (2) análise de zonas cardíacas se disponível,
(3) comparação com o plano esperado, (4) pontos de melhoria, (5) recomendações para recuperação e próxima sessão.
Tom humano, firme e motivador, como feedback pós-treino. Máximo 4-5 parágrafos. Sem emojis.`;

export interface EnhancedCoachAnalysis {
  coachAnalysis: CoachAnalysisSection;
}

export interface CoachAnalysisSection {
  sessionSummary: string;
  performanceMetrics: PerformanceMetricsSection[];
  heartRateAnalysis?: HeartRateAnalysis;
  paceAnalysis?: PaceAnalysis;
  improvementAreas: string[];
  recoveryRecommendations: RecoveryRecommendations;
  nextSessionStrategy: string;
}

export interface PerformanceMetricsSection {
  metric: string;
  value: string;
  context?: string;
  rating?: 'excellent' | 'good' | 'needs-improvement';
}

export interface HeartRateAnalysis {
  avgBpm: number;
  maxBpm: number;
  zoneDistribution: string;
  efficiencyScore: number;
  hrVariance Insights?: HRVarianceInsights[];
}

export interface HRVarianceInsights {
  zone: string;
  durationMinutes: number;
  description: string;
}

export interface PaceAnalysis {
  avgPace: string;
  targetPace?: string;
  paceConsistency: number;
  splitAnalysis: SplitAnalysis[];
}

export interface SplitAnalysis {
  splitNumber: number;
  distanceKm: number;
  achievedPace: string;
  targetPace?: string;
  variance: string;
}

export interface RecoveryRecommendations {
  immediateActions: string[];
  todaySuggestions: string[];
  tomorrowFocus: string[];
}

export class GenerateReportUseCase {
  private llm = getAsyncLLM();

  async execute(run: Run, userId: string): Promise<string> {
    const dist = (run.distanceM / 1000).toFixed(2);
    const minutes = Math.floor(run.durationS / 60);
    const hours = Math.floor(minutes / 60);
    const restMinutes = minutes % 60;
    const knowledgeContext = await formatRunningKnowledgeContext(
      `${run.type} corrida ${dist}km pace ${run.avgPace ?? ''} bpm ${run.avgBpm ?? ''}`,
      3,
    );

    const prompt = `Analise esta corrida em detalhes:

**Dados da sessão:**
- Tipo: ${run.type}
- Distância: ${dist}km
- Duração: ${hours > 0 ? hours + 'h ' : ''}${restMinutes}min
- Pace médio: ${run.avgPace ?? 'N/A'}/km
- BPM médio: ${run.avgBpm ?? 'N/A'}
- BPM máximo: ${run.maxBpm ?? 'N/A'}
${run.targetPace ? `- Pace alvo: ${run.targetPace}/km` : ''}
${run.xpEarned ? `- XP conquistado: ${run.xpEarned}` : ''}

**Análise esperada:**
1. **Desempenho geral**: Como o corredor executou a sessão? Atingiu os objetivos?
2. **Análise de zonas cardíacas**: ${run.avgBpm ? `Com BPM médio de ${run.avgBpm} e máximo de ${run.maxBpm}, como foi a distribuição de esforço? Estava adequado para o tipo ${run.type}?` : 'Dados de frequência cardíaca não disponíveis.'}
3. **Comparação com o plano**: ${run.targetPace ? `O pace alvo era ${run.targetPace}/km e o realizado foi ${run.avgPace ?? 'N/A'}/km. Analise a diferença.` : 'Sem pace alvo definido.'}
4. **Pontos de melhoria**: O que pode ser ajustado na próxima sessão?
5. **Recomendações**: Sugestões para recuperação (hoje/amanhã) e estratégia para a próxima sessão.
6. **Coach Analysis**: Forneça uma análise específica com insights sobre:
   - Resumo da sessão com métricas principais
   - Análise de consistência do ritmo
   - Eficiência cardíaca e zonas
   - Pontos críticos identificados
   - Recomendações específicas e acionáveis

Base de conhecimento:
${knowledgeContext}`;

    try {
      const summary = await this.llm.generate(prompt, { systemPrompt: SYSTEM_PROMPT, maxTokens: 800 });

      // Parse coach analysis section if structured output is provided
      const enhancedAnalysis = this.parseCoachAnalysis(summary);

      // Salva o relatório no Firestore com análise completa
      const reportId = run.id;
      await getFirestore()
        .collection(`users/${userId}/runs/${run.id}/reports`)
        .doc(reportId)
        .set({ 
          summary, 
          coachAnalysis: enhancedAnalysis,
          generatedAt: new Date().toISOString(), 
          status: 'ready' 
        });

      // Atualiza a run com o reportId
      await getFirestore()
        .collection(`users/${userId}/runs`)
        .doc(run.id)
        .update({ coachReportId: reportId });

      return reportId;
    } catch (err) {
      logger.error('coach.report.failed', { runId: run.id, err });
      throw err;
    }
  }

  private parseCoachAnalysis(text: string): EnhancedCoachAnalysis | null {
    try {
      const lines = text.split('\n');
      let inAnalysisSection = false;
      let analysisLines: string[] = [];
      
      for (const line of lines) {
        if (line.includes('Coach Analysis') || line.includes('Análise específica')) {
          inAnalysisSection = true;
          continue;
        }
        
        if (inAnalysisSection) {
          // Stop at new major sections or end of document
          if (line.match(/^#/)) {
            break;
          }
          analysisLines.push(line);
        }
      }

      if (analysisLines.length > 0) {
        return {
          coachAnalysis: {
            sessionSummary: this.extractSection(analysisLines, 'Resumo da sessão'),
            performanceMetrics: [],
            heartRateAnalysis: undefined,
            paceAnalysis: undefined,
            improvementAreas: this.extractBulletPoints(analysisLines, 'Pontos de melhoria'),
            recoveryRecommendations: {
              immediateActions: this.extractBulletPoints(analysisLines, 'Recomendações imediatas'),
              todaySuggestions: this.extractBulletPoints(analysisLines, 'Sugestões para hoje'),
              tomorrowFocus: this.extractBulletPoints(analysisLines, 'Foco para amanhã')
            },
            nextSessionStrategy: this.extractSection(analysisLines, 'Estratégia para a próxima sessão')
          }
        };
      }

      return null;
    } catch (err) {
      logger.warn('coach.report.parse_analysis_failed', { err });
      return null;
    }
  }

  private extractSection(lines: string[], sectionTitle: string): string {
    const joined = lines.join('\n');
    const patterns = [
      new RegExp(`${sectionTitle}[^\\n]*\\n?([\\s\\S]*)`, 'i'),
      new RegExp(`:([^\\n]+)`, 'i')
    ];

    for (const pattern of patterns) {
      const match = joined.match(pattern);
      if (match && match[1]) {
        return match[1].trim();
      }
    }

    return '';
  }

  private extractBulletPoints(lines: string[], sectionTitle: string): string[] {
    const joined = lines.join('\n');
    const sections = joined.split('\n');
    
    let inSection = false;
    const bulletPoints: string[] = [];

    for (const line of sections) {
      if (line.toLowerCase().includes(sectionTitle.toLowerCase())) {
        inSection = true;
        continue;
      }

      if (inSection) {
        // Check for new major section
        if (line.match(/^#/)) {
          break;
        }

        // Extract bullet points
        const bulletMatch = line.match(/[-•*]\s+(.+)/);
        if (bulletMatch) {
          bulletPoints.push(bulletMatch[1].trim());
        } else if (line.trim().length > 20 && !line.match(/^\s/)) {
          // Non-bullet line that's substantial content
          bulletPoints.push(line.trim());
        }
      }
    }

    return bulletPoints.slice(0, 8); // Limit to top 8 points
  }
}
