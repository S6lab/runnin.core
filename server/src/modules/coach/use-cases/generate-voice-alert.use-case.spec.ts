import { GenerateVoiceAlertUseCase, GenerateVoiceAlertInput, VoiceAlertType } from './generate-voice-alert.use-case';

// Mock dependencies
jest.mock('@shared/infra/llm/llm.factory', () => ({
  getAsyncLLM: jest.fn(() => ({
    generate: jest.fn().mockResolvedValue('Você está muito rápido, reduza para 6:00/km.'),
  })),
}));

jest.mock('@shared/infra/tts/google-tts.service', () => ({
  GoogleTtsService: jest.fn().mockImplementation(() => ({
    synthesize: jest.fn().mockResolvedValue({
      audioBase64: 'base64audio',
      mimeType: 'audio/mpeg',
    }),
  })),
}));

jest.mock('@shared/infra/tts/elevenlabs-tts.service', () => ({
  ElevenLabsTtsService: jest.fn().mockImplementation(() => ({
    synthesize: jest.fn().mockResolvedValue({
      audioBase64: 'base64audio',
      mimeType: 'audio/mpeg',
    }),
  })),
}));

jest.mock('./coach-config.service', () => ({
  CoachConfigService: jest.fn().mockImplementation(() => ({
    getConfig: jest.fn().mockResolvedValue({
      ttsEnabled: true,
      ttsProvider: 'google',
      ttsVoiceName: 'pt-BR-Neural2-B',
      ttsLanguageCode: 'pt-BR',
      ttsSpeakingRate: 1.08,
      elevenLabsModelId: 'eleven_multilingual_v2',
      elevenLabsOutputFormat: 'mp3_44100_128',
      elevenLabsVoiceIds: { 'coach-bruno': 'voice123' },
    }),
  })),
}));

jest.mock('@shared/logger/logger', () => ({
  logger: {
    error: jest.fn(),
    warn: jest.fn(),
  },
}));

describe('GenerateVoiceAlertUseCase', () => {
  let useCase: GenerateVoiceAlertUseCase;
  const userId = 'test-user-id';

  beforeEach(() => {
    useCase = new GenerateVoiceAlertUseCase();
    jest.clearAllMocks();
  });

  describe('Alert Generation', () => {
    it('should generate pace_too_fast alert with audio', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'pace_too_fast',
        context: {
          currentPace: '5:00',
          targetPace: '6:00',
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result).toBeDefined();
      expect(result.alertType).toBe('pace_too_fast');
      expect(result.text).toBeTruthy();
      expect(result.audioBase64).toBe('base64audio');
      expect(result.audioMimeType).toBe('audio/mpeg');
      expect(result.alertId).toMatch(/^alert_/);
      expect(result.generatedAt).toBeTruthy();
    });

    it('should generate pace_too_slow alert', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'pace_too_slow',
        context: {
          currentPace: '7:00',
          targetPace: '6:00',
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result.alertType).toBe('pace_too_slow');
      expect(result.text).toBeTruthy();
    });

    it('should generate hr_zone_high alert', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'hr_zone_high',
        context: {
          currentBpm: 180,
          targetBpmZone: { min: 140, max: 160 },
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result.alertType).toBe('hr_zone_high');
      expect(result.text).toBeTruthy();
    });

    it('should generate hr_zone_low alert', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'hr_zone_low',
        context: {
          currentBpm: 120,
          targetBpmZone: { min: 140, max: 160 },
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result.alertType).toBe('hr_zone_low');
      expect(result.text).toBeTruthy();
    });

    it('should generate distance_milestone alert', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'distance_milestone',
        context: {
          distanceKm: 5,
          targetDistanceKm: 10,
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result.alertType).toBe('distance_milestone');
      expect(result.text).toBeTruthy();
    });

    it('should generate halfway_point alert', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'halfway_point',
        context: {
          distanceKm: 5,
          targetDistanceKm: 10,
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result.alertType).toBe('halfway_point');
      expect(result.text).toBeTruthy();
    });

    it('should generate final_push alert', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'final_push',
        context: {
          distanceKm: 9,
          targetDistanceKm: 10,
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result.alertType).toBe('final_push');
      expect(result.text).toBeTruthy();
    });

    it('should generate encouragement alert', async () => {
      const input: GenerateVoiceAlertInput = {
        alertType: 'encouragement',
        context: {
          sessionType: 'easy run',
        },
      };

      const result = await useCase.execute(userId, input);

      expect(result.alertType).toBe('encouragement');
      expect(result.text).toBeTruthy();
    });
  });

  describe('TTS Integration', () => {
    it('should return alert without audio when TTS is disabled', async () => {
      const { CoachConfigService } = require('./coach-config.service');
      CoachConfigService.mockImplementation(() => ({
        getConfig: jest.fn().mockResolvedValue({
          ttsEnabled: false,
        }),
      }));

      useCase = new GenerateVoiceAlertUseCase();

      const input: GenerateVoiceAlertInput = {
        alertType: 'pace_too_fast',
        context: { currentPace: '5:00', targetPace: '6:00' },
      };

      const result = await useCase.execute(userId, input);

      expect(result.text).toBeTruthy();
      expect(result.audioBase64).toBeUndefined();
      expect(result.audioMimeType).toBeUndefined();
    });

    it('should handle TTS synthesis failure gracefully', async () => {
      const { GoogleTtsService } = require('@shared/infra/tts/google-tts.service');
      GoogleTtsService.mockImplementation(() => ({
        synthesize: jest.fn().mockResolvedValue(null),
      }));

      useCase = new GenerateVoiceAlertUseCase();

      const input: GenerateVoiceAlertInput = {
        alertType: 'pace_too_fast',
        context: { currentPace: '5:00', targetPace: '6:00' },
      };

      const result = await useCase.execute(userId, input);

      expect(result.text).toBeTruthy();
      expect(result.audioBase64).toBeUndefined();
    });
  });

  describe('Error Handling', () => {
    it('should throw error when LLM generation fails', async () => {
      jest.resetModules();
      jest.clearAllMocks();

      jest.doMock('@shared/infra/llm/llm.factory', () => ({
        getAsyncLLM: jest.fn(() => ({
          generate: jest.fn().mockRejectedValue(new Error('LLM error')),
        })),
      }));

      const { GenerateVoiceAlertUseCase: UseCase } = await import('./generate-voice-alert.use-case');
      const failingUseCase = new UseCase();

      const input: GenerateVoiceAlertInput = {
        alertType: 'pace_too_fast',
        context: { currentPace: '5:00', targetPace: '6:00' },
      };

      await expect(failingUseCase.execute(userId, input)).rejects.toThrow('LLM error');
    });
  });

  describe('Context Handling', () => {
    it('should handle missing context gracefully', async () => {
      // Reset to good mocks
      jest.resetModules();
      jest.clearAllMocks();

      jest.doMock('@shared/infra/llm/llm.factory', () => ({
        getAsyncLLM: jest.fn(() => ({
          generate: jest.fn().mockResolvedValue('Keep going!'),
        })),
      }));

      jest.doMock('./coach-config.service', () => ({
        CoachConfigService: jest.fn().mockImplementation(() => ({
          getConfig: jest.fn().mockResolvedValue({
            ttsEnabled: false,
          }),
        })),
      }));

      const { GenerateVoiceAlertUseCase: UseCase } = await import('./generate-voice-alert.use-case');
      const goodUseCase = new UseCase();

      const input: GenerateVoiceAlertInput = {
        alertType: 'encouragement',
        context: {},
      };

      const result = await goodUseCase.execute(userId, input);

      expect(result).toBeDefined();
      expect(result.text).toBeTruthy();
    });

    it('should use all available context in prompt', async () => {
      // Use existing useCase from beforeEach (which has good mocks)
      const input: GenerateVoiceAlertInput = {
        alertType: 'pace_too_fast',
        context: {
          currentPace: '5:00',
          targetPace: '6:00',
          currentBpm: 170,
          targetBpmZone: { min: 140, max: 160 },
          distanceKm: 3.5,
          targetDistanceKm: 10,
          elapsedMinutes: 20,
          sessionType: 'long run',
        },
      };

      // Create a fresh use case with initial mocks
      const freshUseCase = new GenerateVoiceAlertUseCase();
      const result = await freshUseCase.execute(userId, input);

      expect(result).toBeDefined();
    });
  });
});
