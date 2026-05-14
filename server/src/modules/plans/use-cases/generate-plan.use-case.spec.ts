import { GeneratePlanUseCase } from './generate-plan.use-case';
import { PlanRepository } from '../domain/plan.repository';
import { UserRepository } from '@modules/users/domain/user.repository';
import { Plan, PlanWeek } from '../domain/plan.entity';
import { UserProfile } from '@modules/users/domain/user.entity';

// Mock uuid
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mock-uuid'),
}));

// Mock repositories
const mockPlanRepo: jest.Mocked<PlanRepository> = {
  findById: jest.fn(),
  findCurrent: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
};

const mockUserRepo: jest.Mocked<UserRepository> = {
  findById: jest.fn(),
  upsert: jest.fn(),
  archiveOnboarding: jest.fn(),
};

// Mock LLM
jest.mock('@shared/infra/llm/llm.factory', () => ({
  getAsyncLLM: jest.fn(() => ({
    generate: jest.fn().mockResolvedValue(JSON.stringify([
      {
        weekNumber: 1,
        sessions: [
          { dayOfWeek: 1, type: 'Easy Run', distanceKm: 5, notes: 'Base run' },
          { dayOfWeek: 3, type: 'Interval', distanceKm: 6, notes: 'Speed work' },
          { dayOfWeek: 5, type: 'Easy Run', distanceKm: 5, notes: 'Recovery' },
        ],
      },
      {
        weekNumber: 2,
        sessions: [
          { dayOfWeek: 1, type: 'Easy Run', distanceKm: 6, notes: 'Base run' },
          { dayOfWeek: 3, type: 'Tempo', distanceKm: 7, notes: 'Tempo work' },
          { dayOfWeek: 5, type: 'Easy Run', distanceKm: 6, notes: 'Recovery' },
        ],
      },
      {
        weekNumber: 3,
        sessions: [
          { dayOfWeek: 1, type: 'Easy Run', distanceKm: 7, notes: 'Base run' },
          { dayOfWeek: 3, type: 'Interval', distanceKm: 8, notes: 'Speed work' },
          { dayOfWeek: 5, type: 'Long Run', distanceKm: 10, notes: 'Long run' },
        ],
      },
      {
        weekNumber: 4,
        sessions: [
          { dayOfWeek: 1, type: 'Easy Run', distanceKm: 5, notes: 'Recovery week' },
          { dayOfWeek: 3, type: 'Easy Run', distanceKm: 4, notes: 'Easy' },
          { dayOfWeek: 5, type: 'Easy Run', distanceKm: 5, notes: 'Light' },
        ],
      },
    ])),
  })),
}));

jest.mock('@shared/knowledge/running/running-knowledge', () => ({
  formatRunningKnowledgeContext: jest.fn().mockResolvedValue('mock knowledge context'),
}));

jest.mock('@shared/logger/logger', () => ({
  logger: {
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
  },
}));

describe('GeneratePlanUseCase', () => {
  let useCase: GeneratePlanUseCase;
  let mockUserProfile: UserProfile;

  beforeEach(() => {
    jest.clearAllMocks();
    useCase = new GeneratePlanUseCase(mockPlanRepo, mockUserRepo);

    mockUserProfile = {
      id: 'user-123',
      name: 'Test Runner',
      level: 'intermediario',
      goal: 'Correr 10k',
      frequency: 3,
      birthDate: '1990-01-01',
      hasWearable: false,
      medicalConditions: [],
      premium: false,
      onboarded: true,
      hasCompletedFirstRun: false,
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z',
    };

    mockUserRepo.findById.mockResolvedValue(mockUserProfile);
    mockPlanRepo.create.mockImplementation((plan: Plan) => Promise.resolve(plan));
    mockPlanRepo.update.mockResolvedValue();
  });

  describe('HR Zone Calculation', () => {
    it('should calculate correct HR zones with user-provided maxHR', () => {
      const maxHR = 180;
      const enrichedInput = {
        goal: 'Correr 10k',
        level: 'intermediario' as const,
        frequency: 3,
        weeksCount: 4,
        maxHeartRate: maxHR,
      };

      // Access private method via type assertion for testing
      const zones = (useCase as any)._calculateHeartRateZones(enrichedInput);

      expect(zones).toBeDefined();
      expect(zones.maxHeartRate).toBe(180);

      // Zone 1 (Easy): 60-70% max HR
      expect(zones.zone1.min).toBe(Math.round(180 * 0.6)); // 108
      expect(zones.zone1.max).toBe(Math.round(180 * 0.7)); // 126

      // Zone 2 (Aerobic): 70-80%
      expect(zones.zone2.min).toBe(Math.round(180 * 0.7)); // 126
      expect(zones.zone2.max).toBe(Math.round(180 * 0.8)); // 144

      // Zone 3 (Tempo): 80-87%
      expect(zones.zone3.min).toBe(Math.round(180 * 0.8)); // 144
      expect(zones.zone3.max).toBe(Math.round(180 * 0.87)); // 157

      // Zone 4 (Threshold): 87-93%
      expect(zones.zone4.min).toBe(Math.round(180 * 0.87)); // 157
      expect(zones.zone4.max).toBe(Math.round(180 * 0.93)); // 167

      // Zone 5 (VO2 Max): 93-100%
      expect(zones.zone5.min).toBe(Math.round(180 * 0.93)); // 167
      expect(zones.zone5.max).toBe(Math.round(180 * 1.0)); // 180
    });

    it('should calculate HR zones from birthDate when maxHR not provided', () => {
      const enrichedInput = {
        goal: 'Correr 10k',
        level: 'intermediario' as const,
        frequency: 3,
        weeksCount: 4,
        birthDate: '1990-01-01',
      };

      const zones = (useCase as any)._calculateHeartRateZones(enrichedInput);

      const age = new Date().getFullYear() - 1990;
      const expectedMaxHR = 220 - age;

      expect(zones).toBeDefined();
      expect(zones.maxHeartRate).toBe(expectedMaxHR);
      expect(zones.zone1.min).toBe(Math.round(expectedMaxHR * 0.6));
      expect(zones.zone1.max).toBe(Math.round(expectedMaxHR * 0.7));
    });

    it('should return undefined when no HR data available', () => {
      const enrichedInput = {
        goal: 'Correr 10k',
        level: 'intermediario' as const,
        frequency: 3,
        weeksCount: 4,
      };

      const zones = (useCase as any)._calculateHeartRateZones(enrichedInput);

      expect(zones).toBeUndefined();
    });
  });

  describe('3:1 Periodization Pattern', () => {
    it('should apply recovery pattern to week 4 (every 4th week)', () => {
      const weeks: PlanWeek[] = [
        {
          weekNumber: 1,
          sessions: [
            { id: 's1', dayOfWeek: 1, type: 'Easy Run', distanceKm: 5, notes: 'Base' },
            { id: 's2', dayOfWeek: 3, type: 'Interval', distanceKm: 6, notes: 'Speed' },
          ],
        },
        {
          weekNumber: 2,
          sessions: [
            { id: 's3', dayOfWeek: 1, type: 'Easy Run', distanceKm: 6, notes: 'Base' },
            { id: 's4', dayOfWeek: 3, type: 'Tempo', distanceKm: 7, notes: 'Tempo' },
          ],
        },
        {
          weekNumber: 3,
          sessions: [
            { id: 's5', dayOfWeek: 1, type: 'Easy Run', distanceKm: 7, notes: 'Base' },
            { id: 's6', dayOfWeek: 3, type: 'Interval', distanceKm: 8, notes: 'Speed' },
          ],
        },
        {
          weekNumber: 4,
          sessions: [
            { id: 's7', dayOfWeek: 1, type: 'Easy Run', distanceKm: 5, notes: 'Recovery' },
            { id: 's8', dayOfWeek: 3, type: 'Interval', distanceKm: 6, notes: 'Speed' },
          ],
        },
      ];

      const result = (useCase as any)._applyMesocyclePattern(weeks);

      // Weeks 1-3 should remain unchanged
      expect(result[0].sessions[0].distanceKm).toBe(5);
      expect(result[1].sessions[0].distanceKm).toBe(6);
      expect(result[2].sessions[0].distanceKm).toBe(7);

      // Week 4 should have reduced volume (65% of original)
      expect(result[3].sessions[0].distanceKm).toBe(3.3); // 5 * 0.65 = 3.25 → 3.3
      expect(result[3].sessions[1].distanceKm).toBe(3.9); // 6 * 0.65 = 3.9

      // Week 4 intensity sessions should be converted to Easy Run
      expect(result[3].sessions[1].type).toBe('Easy Run');
      expect(result[3].sessions[1].notes).toContain('[Semana de recuperação]');
    });

    it('should apply recovery pattern to weeks 4, 8, 12, etc.', () => {
      const weeks: PlanWeek[] = Array.from({ length: 8 }, (_, i) => ({
        weekNumber: i + 1,
        sessions: [
          { id: `s${i}`, dayOfWeek: 1, type: 'Interval', distanceKm: 10, notes: 'Test' },
        ],
      }));

      const result = (useCase as any)._applyMesocyclePattern(weeks);

      // Week 4 should be recovery
      expect(result[3].sessions[0].distanceKm).toBe(6.5); // 10 * 0.65
      expect(result[3].sessions[0].type).toBe('Easy Run');

      // Week 8 should be recovery
      expect(result[7].sessions[0].distanceKm).toBe(6.5);
      expect(result[7].sessions[0].type).toBe('Easy Run');

      // Other weeks should be unchanged
      expect(result[0].sessions[0].distanceKm).toBe(10);
      expect(result[0].sessions[0].type).toBe('Interval');
      expect(result[4].sessions[0].distanceKm).toBe(10);
      expect(result[4].sessions[0].type).toBe('Interval');
    });

    it('should not modify non-intensity sessions in recovery weeks', () => {
      const weeks: PlanWeek[] = [
        {
          weekNumber: 4,
          sessions: [
            { id: 's1', dayOfWeek: 1, type: 'Easy Run', distanceKm: 5, notes: 'Easy' },
            { id: 's2', dayOfWeek: 3, type: 'Long Run', distanceKm: 12, notes: 'Long' },
          ],
        },
      ];

      const result = (useCase as any)._applyMesocyclePattern(weeks);

      // Easy Run should stay as Easy Run (not converted)
      expect(result[0].sessions[0].type).toBe('Easy Run');
      expect(result[0].sessions[0].distanceKm).toBe(3.3); // Still reduced volume

      // Long Run should stay as Long Run (not high intensity)
      expect(result[0].sessions[1].type).toBe('Long Run');
      expect(result[0].sessions[1].distanceKm).toBe(7.8); // 12 * 0.65
    });
  });

  describe('User Profile Integration', () => {
    it('should fetch user profile and use it to generate plan', async () => {
      const input = {};

      const plan = await useCase.execute('user-123', input);

      expect(mockUserRepo.findById).toHaveBeenCalledWith('user-123');
      expect(mockPlanRepo.create).toHaveBeenCalled();

      const createdPlan = mockPlanRepo.create.mock.calls[0][0];
      expect(createdPlan.goal).toBe('Correr 10k');
      expect(createdPlan.level).toBe('intermediario');
      expect(createdPlan.status).toBe('generating');
    });

    it('should allow input to override user profile values', async () => {
      const input = {
        goal: 'Correr meia maratona',
        level: 'avancado' as const,
      };

      await useCase.execute('user-123', input);

      const createdPlan = mockPlanRepo.create.mock.calls[0][0];
      expect(createdPlan.goal).toBe('Correr meia maratona');
      expect(createdPlan.level).toBe('avancado');
    });

    it('should throw error when user profile not found', async () => {
      mockUserRepo.findById.mockResolvedValue(null);

      await expect(useCase.execute('user-123', {})).rejects.toThrow(
        'User profile not found. Please complete onboarding first.'
      );
    });
  });

  describe('Plan Generation Flow', () => {
    it('should create plan with generating status immediately', async () => {
      const plan = await useCase.execute('user-123', {});

      expect(plan.status).toBe('generating');
      expect(plan.weeks).toEqual([]);
      expect(mockPlanRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'generating',
          userId: 'user-123',
        })
      );
    });

    it('should determine correct weeks count based on goal and level', async () => {
      mockUserProfile.goal = 'Correr maratona';
      mockUserProfile.level = 'avancado';
      mockUserRepo.findById.mockResolvedValue(mockUserProfile);

      const plan = await useCase.execute('user-123', {});

      // Advanced runner training for marathon should be 14 weeks
      expect(plan.weeksCount).toBe(14);
    });
  });
});
