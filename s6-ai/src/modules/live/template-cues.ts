import { CueEvent, TelemetrySnapshot } from './cue-events';
import { LiveSessionContext } from './live-session.types';

/**
 * Templates determinísticos pro fallback HTTP (WS caído): bpm_alert,
 * pace_alert e no_movement não pagam LLM — são alertas mecânicos onde
 * latência e previsibilidade importam mais que variedade.
 * 2 variações por evento, rotação pseudo-aleatória.
 */
export interface TemplateCue {
  text: string;
  variation: number;
}

export function tryBuildTemplate(
  event: CueEvent,
  data: TelemetrySnapshot,
  ctx: LiveSessionContext,
): TemplateCue | null {
  const name = ctx.athleteName?.trim() || null;
  const v = Math.random() < 0.5 ? 1 : 2;

  switch (event) {
    case 'bpm_alert': {
      const bpm = data.bpm != null ? `${Math.round(data.bpm)} bpm` : 'alta';
      const text = v === 1
        ? `${vocative(name)}sua frequência cardíaca está em ${bpm}, perto do seu limite. Diminui o ritmo agora e alonga a respiração.`
        : `Atenção${name ? `, ${name}` : ''}: coração em ${bpm}. Reduz o passo e respira fundo até baixar — a corrida continua, mas em segurança.`;
      return { text, variation: v };
    }
    case 'pace_alert': {
      const cur = data.currentPace ?? 'fora do alvo';
      const target = data.targetPace;
      const text = v === 1
        ? `${vocative(name)}seu pace está em ${cur}${target ? ` e o alvo é ${target}` : ''}. Ajusta o ritmo com passadas mais ${deviationDirection(data)}.`
        : `Ritmo ${deviationLabel(data)}${target ? ` do alvo de ${target}` : ''} — agora está em ${cur}. Corrige aos poucos, sem mudança brusca.`;
      return { text, variation: v };
    }
    case 'no_movement': {
      const text = v === 1
        ? `${vocative(name)}percebi que você parou. Tudo bem aí? Quando estiver pronto, retoma num trote leve.`
        : `${name ?? 'Atleta'}, o GPS mostra você parado. Se foi pausa pra água, ótimo — senão, bora retomar com calma.`;
      return { text, variation: v };
    }
    default:
      return null;
  }
}

function vocative(name: string | null): string {
  return name ? `${name}, ` : '';
}

// Convenção: deviationPct > 0 = pace atual mais LENTO que o alvo
// (min/km maior). Mesma convenção que o app envia no pace_alert.
function deviationDirection(data: TelemetrySnapshot): string {
  const pct = data.deviationPct ?? 0;
  return pct > 0 ? 'firmes pra acelerar' : 'leves pra segurar o ritmo';
}

function deviationLabel(data: TelemetrySnapshot): string {
  const pct = data.deviationPct ?? 0;
  return pct > 0 ? 'mais lento' : 'mais rápido';
}
