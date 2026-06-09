import { logger } from '@shared/logger/logger';

export interface CurrentWeather {
  temperatureC: number;
  humidityPercent: number;
  windKmh: number;
  uvIndex: number;
  fetchedAt: string;
}

interface CacheEntry {
  value: CurrentWeather;
  expiresAt: number;
}

// Cache em memória por grid ~1km (lat/lng arredondado em 2 casas decimais).
// TTL de 20min é suficiente pra clima atual e segura free tier da Open-Meteo.
// Quando virar bottleneck, migrar pra Redis com mesmo schema de chave.
const CACHE_TTL_MS = 20 * 60 * 1000;
const cache = new Map<string, CacheEntry>();

function cacheKey(lat: number, lng: number): string {
  return `${lat.toFixed(2)}:${lng.toFixed(2)}`;
}

export async function getCurrentWeather(lat: number, lng: number): Promise<CurrentWeather | null> {
  const key = cacheKey(lat, lng);
  const cached = cache.get(key);
  const now = Date.now();
  if (cached && cached.expiresAt > now) {
    return cached.value;
  }

  const url =
    `https://api.open-meteo.com/v1/forecast` +
    `?latitude=${lat}&longitude=${lng}` +
    `&current=temperature_2m,relative_humidity_2m,wind_speed_10m,uv_index` +
    `&wind_speed_unit=kmh&timezone=auto`;

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(4000) });
    if (!res.ok) {
      logger.warn('weather.http_error', { status: res.status, lat, lng });
      return null;
    }
    const data = (await res.json()) as {
      current?: {
        temperature_2m?: number;
        relative_humidity_2m?: number;
        wind_speed_10m?: number;
        uv_index?: number;
      };
    };
    const c = data.current;
    if (!c || typeof c.temperature_2m !== 'number') {
      logger.warn('weather.malformed_response', { lat, lng });
      return null;
    }
    const value: CurrentWeather = {
      temperatureC: Math.round(c.temperature_2m * 10) / 10,
      humidityPercent: Math.round(c.relative_humidity_2m ?? 0),
      windKmh: Math.round((c.wind_speed_10m ?? 0) * 10) / 10,
      uvIndex: Math.round((c.uv_index ?? 0) * 10) / 10,
      fetchedAt: new Date(now).toISOString(),
    };
    cache.set(key, { value, expiresAt: now + CACHE_TTL_MS });
    return value;
  } catch (err) {
    logger.warn('weather.fetch_failed', { err: String(err), lat, lng });
    return null;
  }
}
