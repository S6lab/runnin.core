import { createSign } from 'crypto';
import path from 'path';
import { existsSync } from 'fs';
import { readFileSync } from 'fs';
import { logger } from '@shared/logger/logger';

interface GoogleTtsOptions {
  voiceName: string;
  languageCode: string;
  speakingRate: number;
}

export interface SynthesizedSpeech {
  audioBase64: string;
  mimeType: string;
}

interface ServiceAccountCredentials {
  clientEmail: string;
  privateKey: string;
}

interface CachedToken {
  value: string;
  expiresAt: number;
}

const TTS_SCOPE = 'https://www.googleapis.com/auth/cloud-platform';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const TTS_URL = 'https://texttospeech.googleapis.com/v1/text:synthesize';
const MAX_TTS_CHARS = 180;

export class GoogleTtsService {
  private token?: CachedToken;

  async synthesize(text: string, options: GoogleTtsOptions): Promise<SynthesizedSpeech | null> {
    if (process.env.GOOGLE_TTS_ENABLED === 'false') return null;

    const inputText = trimForShortCue(text);
    if (!inputText) return null;

    try {
      const accessToken = await this.getAccessToken();
      // AbortController + 6s timeout pra evitar fetch travado (causa
      // de Cloud Run 504 quando rede do TTS está degradada).
      const ctrl = new AbortController();
      const to = setTimeout(() => ctrl.abort(), 6000);
      const res = await fetch(TTS_URL, {
        method: 'POST',
        signal: ctrl.signal,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          input: { text: inputText },
          voice: {
            languageCode: options.languageCode,
            name: options.voiceName,
          },
          audioConfig: {
            audioEncoding: 'MP3',
            speakingRate: options.speakingRate,
          },
        }),
      }).finally(() => clearTimeout(to));

      if (!res.ok) {
        const body = await res.text().catch(() => '');
        throw new Error(`Google TTS failed: ${res.status} ${body.slice(0, 300)}`);
      }

      const data = await res.json() as { audioContent?: string };
      if (!data.audioContent) return null;
      return { audioBase64: data.audioContent, mimeType: 'audio/mpeg' };
    } catch (err) {
      logger.warn('tts.google.failed', {
        err: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }

  private async getAccessToken(): Promise<string> {
    if (this.token && this.token.expiresAt - 60_000 > Date.now()) {
      return this.token.value;
    }

    const credentials = loadServiceAccountCredentials();
    if (credentials) {
      const token = await this.getJwtAccessToken(credentials);
      this.token = token;
      return token.value;
    }

    const token = await this.getMetadataAccessToken();
    this.token = token;
    return token.value;
  }

  private async getJwtAccessToken(credentials: ServiceAccountCredentials): Promise<CachedToken> {
    const now = Math.floor(Date.now() / 1000);
    const assertion = [
      base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
      base64UrlEncode(JSON.stringify({
        iss: credentials.clientEmail,
        scope: TTS_SCOPE,
        aud: TOKEN_URL,
        exp: now + 3600,
        iat: now,
      })),
    ].join('.');

    const signer = createSign('RSA-SHA256');
    signer.update(assertion);
    const signature = base64UrlEncode(signer.sign(credentials.privateKey));
    const signedJwt = `${assertion}.${signature}`;

    const res = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: signedJwt,
      }),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`Google OAuth failed: ${res.status} ${body.slice(0, 300)}`);
    }

    const data = await res.json() as { access_token: string; expires_in?: number };
    return {
      value: data.access_token,
      expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
    };
  }

  private async getMetadataAccessToken(): Promise<CachedToken> {
    const res = await fetch(
      'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token',
      { headers: { 'Metadata-Flavor': 'Google' } },
    );

    if (!res.ok) {
      throw new Error(`Google metadata token failed: ${res.status}`);
    }

    const data = await res.json() as { access_token: string; expires_in?: number };
    return {
      value: data.access_token,
      expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
    };
  }
}

function trimForShortCue(text: string): string {
  const normalized = text.replace(/\s+/g, ' ').trim();
  if (normalized.length <= MAX_TTS_CHARS) return normalized;

  const sentenceEnd = normalized.slice(0, MAX_TTS_CHARS).search(/[.!?](?!.*[.!?])/);
  if (sentenceEnd > 80) return normalized.slice(0, sentenceEnd + 1).trim();

  const hardCut = normalized.slice(0, MAX_TTS_CHARS);
  const lastSpace = hardCut.lastIndexOf(' ');
  return `${hardCut.slice(0, lastSpace > 80 ? lastSpace : MAX_TTS_CHARS).trim()}.`;
}

function loadServiceAccountCredentials(): ServiceAccountCredentials | null {
  const envEmail = process.env.GOOGLE_TTS_CLIENT_EMAIL ?? process.env.FIREBASE_CLIENT_EMAIL;
  const envKey = process.env.GOOGLE_TTS_PRIVATE_KEY ?? process.env.FIREBASE_PRIVATE_KEY;
  if (envEmail && envKey?.includes('BEGIN')) {
    return {
      clientEmail: envEmail,
      privateKey: envKey.replace(/\\n/g, '\n'),
    };
  }

  const credentialsPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ?? localServiceAccountPath();
  if (!credentialsPath) return null;

  try {
    const parsed = JSON.parse(readFileSync(credentialsPath, 'utf8')) as {
      client_email?: string;
      private_key?: string;
    };
    if (parsed.client_email && parsed.private_key) {
      return {
        clientEmail: parsed.client_email,
        privateKey: parsed.private_key,
      };
    }
  } catch (err) {
    logger.warn('tts.google.credentials_file_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
  }

  return null;
}

function localServiceAccountPath(): string | undefined {
  const candidate = path.resolve(process.cwd(), 'backend-service-account.json');
  return existsSync(candidate) ? candidate : undefined;
}

function base64UrlEncode(value: string | Buffer): string {
  const buffer = typeof value === 'string' ? Buffer.from(value) : value;
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}
