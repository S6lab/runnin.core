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
