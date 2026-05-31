import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { logger } from '@shared/logger/logger';

export const UpsertLocationSchema = z.object({
  lat: z.number().gte(-90).lte(90),
  lng: z.number().gte(-180).lte(180),
});

export type UpsertLocationInput = z.infer<typeof UpsertLocationSchema>;

export interface UpsertLocationResult {
  city: string | null;
  lat: number;
  lng: number;
}

/**
 * Recebe lat/lng do device (home requisita logo após permissão de
 * localização concedida), faz reverse geocoding no Open-Meteo e persiste
 * cidade + coords no profile. Se a API falhar, salva só as coords — clima
 * ainda funciona, header apenas não mostra cidade.
 */
export class UpsertLocationUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: UpsertLocationInput): Promise<UpsertLocationResult> {
    const existing = await this.userRepo.findById(userId);
    if (!existing) {
      throw new Error('USER_NOT_FOUND');
    }

    const city = await reverseGeocode(input.lat, input.lng);
    const now = new Date().toISOString();

    await this.userRepo.upsert({
      ...existing,
      city: city ?? existing.city,
      lastKnownLat: input.lat,
      lastKnownLng: input.lng,
      lastLocationAt: now,
      updatedAt: now,
    });

    return { city: city ?? existing.city ?? null, lat: input.lat, lng: input.lng };
  }
}

async function reverseGeocode(lat: number, lng: number): Promise<string | null> {
  // Open-Meteo geocoding não tem reverse direto; usamos search por
  // proximidade. Alternativa testada: BigDataCloud free reverse-geocoding
  // (sem key, dado bom). Escolhi BigDataCloud por dar city+region direto.
  const url = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lng}&localityLanguage=pt`;
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(4000) });
    if (!res.ok) {
      logger.warn('location.reverse_geocode.http_error', { status: res.status, lat, lng });
      return null;
    }
    const data = (await res.json()) as {
      city?: string;
      locality?: string;
      principalSubdivisionCode?: string;
      principalSubdivision?: string;
      countryName?: string;
    };
    const cityName = data.city || data.locality;
    const region = (data.principalSubdivisionCode || '').split('-')[1] || data.principalSubdivision;
    if (cityName && region) return `${cityName}, ${region}`;
    if (cityName) return cityName;
    if (data.countryName) return data.countryName;
    return null;
  } catch (err) {
    logger.warn('location.reverse_geocode.failed', { err: String(err), lat, lng });
    return null;
  }
}
