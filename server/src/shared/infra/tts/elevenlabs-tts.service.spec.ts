import { ElevenLabsTtsService } from './elevenlabs-tts.service';

// Mock global fetch
global.fetch = jest.fn();

jest.mock('@shared/logger/logger', () => ({
  logger: {
    warn: jest.fn(),
  },
}));

describe('ElevenLabsTtsService Integration', () => {
  let service: ElevenLabsTtsService;

  beforeEach(() => {
    service = new ElevenLabsTtsService();
    jest.clearAllMocks();
  });

  afterEach(() => {
    delete process.env.ELEVENLABS_API_KEY;
  });

  describe('synthesize', () => {
    it('should return null when API key is missing', async () => {
      delete process.env.ELEVENLABS_API_KEY;

      const result = await service.synthesize('Test text', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
      });

      expect(result).toBeNull();
      const { logger } = require('@shared/logger/logger');
      expect(logger.warn).toHaveBeenCalledWith('tts.elevenlabs.missing_api_key');
    });

    it('should return null when voiceId is missing', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      const result = await service.synthesize('Test text', {
        voiceId: '',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
      });

      expect(result).toBeNull();
      const { logger } = require('@shared/logger/logger');
      expect(logger.warn).toHaveBeenCalledWith('tts.elevenlabs.missing_voice_id');
    });

    it('should synthesize text and return base64 audio', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      const mockAudioBuffer = Buffer.from('mock audio data');
      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => mockAudioBuffer.buffer,
      });

      const result = await service.synthesize('Olá, corredor!', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
        languageCode: 'pt',
      });

      expect(result).not.toBeNull();
      expect(result?.audioBase64).toBe(mockAudioBuffer.toString('base64'));
      expect(result?.mimeType).toBe('audio/mpeg');
    });

    it('should include correct headers and body in request', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => Buffer.from('audio').buffer,
      });

      await service.synthesize('Test text', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
        languageCode: 'pt',
      });

      expect(global.fetch).toHaveBeenCalledWith(
        expect.any(URL),
        expect.objectContaining({
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'xi-api-key': 'test-api-key',
          },
          body: expect.stringContaining('Test text'),
        })
      );

      const callArgs = (global.fetch as jest.Mock).mock.calls[0];
      const requestBody = JSON.parse(callArgs[1].body);

      expect(requestBody.text).toBe('Test text');
      expect(requestBody.model_id).toBe('eleven_multilingual_v2');
      expect(requestBody.language_code).toBe('pt');
      expect(requestBody.voice_settings).toMatchObject({
        stability: 0.58,
        similarity_boost: 0.78,
        style: 0.18,
        use_speaker_boost: true,
      });
    });

    it('should use correct output format in URL', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => Buffer.from('audio').buffer,
      });

      await service.synthesize('Test', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
      });

      const callArgs = (global.fetch as jest.Mock).mock.calls[0];
      const url = callArgs[0];

      expect(url.toString()).toContain('voice123');
      expect(url.searchParams.get('output_format')).toBe('mp3_44100_128');
    });

    it('should trim long text to MAX_TTS_CHARS', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      const longText = 'A'.repeat(300);
      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => Buffer.from('audio').buffer,
      });

      const result = await service.synthesize(longText, {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
      });

      expect(result).not.toBeNull();

      const callArgs = (global.fetch as jest.Mock).mock.calls[0];
      const requestBody = JSON.parse(callArgs[1].body);
      expect(requestBody.text.length).toBeLessThanOrEqual(180);
    });

    it('should handle API failure gracefully', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 500,
        text: async () => 'Internal Server Error',
      });

      const result = await service.synthesize('Test text', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
      });

      expect(result).toBeNull();
      const { logger } = require('@shared/logger/logger');
      expect(logger.warn).toHaveBeenCalledWith(
        'tts.elevenlabs.failed',
        expect.objectContaining({
          err: expect.stringContaining('500'),
        })
      );
    });

    it('should default to pt language code when not provided', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => Buffer.from('audio').buffer,
      });

      await service.synthesize('Test', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
      });

      const callArgs = (global.fetch as jest.Mock).mock.calls[0];
      const requestBody = JSON.parse(callArgs[1].body);

      expect(requestBody.language_code).toBe('pt');
    });
  });

  describe('MIME Type Handling', () => {
    it('should return audio/mpeg for mp3 format', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => Buffer.from('audio').buffer,
      });

      const result = await service.synthesize('Test', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'mp3_44100_128',
      });

      expect(result?.mimeType).toBe('audio/mpeg');
    });

    it('should return audio/wav for wav format', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => Buffer.from('audio').buffer,
      });

      const result = await service.synthesize('Test', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'wav_44100',
      });

      expect(result?.mimeType).toBe('audio/wav');
    });

    it('should return audio/pcm for pcm format', async () => {
      process.env.ELEVENLABS_API_KEY = 'test-api-key';

      (global.fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => Buffer.from('audio').buffer,
      });

      const result = await service.synthesize('Test', {
        voiceId: 'voice123',
        modelId: 'eleven_multilingual_v2',
        outputFormat: 'pcm_44100',
      });

      expect(result?.mimeType).toBe('audio/pcm');
    });
  });
});
