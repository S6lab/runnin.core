import { GeminiAdapter } from './gemini.adapter';
import { GroqAdapter } from './groq.adapter';
import { TogetherAdapter } from './together.adapter';
import { LLMProvider, LLMProviderName } from './llm.interface';

function getProviderName(envKey: 'LLM_REALTIME_PROVIDER' | 'LLM_ASYNC_PROVIDER'): LLMProviderName {
  const value = (process.env[envKey] ?? 'gemini').toLowerCase();

  if (value === 'gemini' || value === 'groq' || value === 'together') {
    return value;
  }

  throw new Error(`Invalid ${envKey}: ${value}`);
}

function instantiateProvider(provider: LLMProviderName): LLMProvider {
  switch (provider) {
    case 'gemini':
      return new GeminiAdapter();
    case 'groq':
      return new GroqAdapter();
    case 'together':
      return new TogetherAdapter();
  }
}

export function getRealtimeLLM(): LLMProvider {
  return instantiateProvider(getProviderName('LLM_REALTIME_PROVIDER'));
}

export function getAsyncLLM(): LLMProvider {
  return instantiateProvider(getProviderName('LLM_ASYNC_PROVIDER'));
}

/**
 * LLM da GERAÇÃO DE PLANO. Permite um modelo dedicado (mais capaz/caro) via
 * env GEMINI_PLAN_MODEL — ex: gemini-3.1-pro-preview pra raciocínio melhor —
 * sem afetar os demais usos (coach/relatórios seguem GEMINI_MODEL). Só aplica
 * quando o provider async é gemini; caso contrário cai no provider padrão.
 */
export function getPlanLLM(): LLMProvider {
  const provider = getProviderName('LLM_ASYNC_PROVIDER');
  if (provider === 'gemini') {
    const planModel = process.env['GEMINI_PLAN_MODEL']?.trim();
    return planModel ? new GeminiAdapter(planModel) : new GeminiAdapter();
  }
  return instantiateProvider(provider);
}
