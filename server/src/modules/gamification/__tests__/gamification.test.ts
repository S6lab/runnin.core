import { FirestoreGamificationRepository } from '../infra/firestore-gamification.repository';
import { AwardXpUseCase } from '../domain/use-cases/award-xp.use-case';
import { CheckBadgeUnlockUseCase } from '../domain/use-cases/check-badge-unlock.use-case';
import { calcLevel } from '../domain/gamification.entity';
import { Run } from '@modules/runs/domain/run.entity';

// Mock Firestore
jest.mock('@shared/infra/firebase/firebase.client', () => ({
  getFirestore: jest.fn(() => ({
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn(),
        set: jest.fn(),
      })),
    })),
  })),
}));

describe('Gamification Module', () => {
  describe('calcLevel', () => {
    it('should calculate level from XP correctly', () => {
      expect(calcLevel(0)).toBe(1);
      expect(calcLevel(100)).toBe(2);
      expect(calcLevel(400)).toBe(3);
      expect(calcLevel(900)).toBe(4);
      expect(calcLevel(10000)).toBe(11);
    });
  });

  describe('CheckBadgeUnlockUseCase', () => {
    let repo: FirestoreGamificationRepository;
    let useCase: CheckBadgeUnlockUseCase;

    beforeEach(() => {
      repo = new FirestoreGamificationRepository();
      useCase = new CheckBadgeUnlockUseCase(repo);
    });

    it('should unlock first_run badge on first run', async () => {
      const mockRun = {
        id: 'run1',
        userId: 'user1',
        distanceM: 5000,
        durationS: 1800,
        avgPace: '6:00',
      } as Run;

      repo.findByUserId = jest.fn().mockResolvedValue(null);
      repo.unlockBadge = jest.fn().mockResolvedValue(undefined);

      const unlocked = await useCase.execute('user1', mockRun, 1);

      expect(unlocked).toContain('first_run');
      expect(repo.unlockBadge).toHaveBeenCalledWith('user1', 'first_run');
    });

    it('should unlock marathon_ready when distance >= 42.195km', async () => {
      const mockRun = {
        id: 'run1',
        userId: 'user1',
        distanceM: 42195,
        durationS: 10800,
        avgPace: '6:00',
      } as Run;

      repo.findByUserId = jest.fn().mockResolvedValue({
        userId: 'user1',
        totalXp: 1000,
        level: 5,
        currentStreak: 3,
        longestStreak: 5,
        lastActivityDate: '2026-05-13',
        unlockedBadges: ['first_run'],
        updatedAt: '2026-05-13T10:00:00.000Z',
      });
      repo.unlockBadge = jest.fn().mockResolvedValue(undefined);

      const unlocked = await useCase.execute('user1', mockRun, 10);

      expect(unlocked).toContain('marathon_ready');
      expect(repo.unlockBadge).toHaveBeenCalledWith('user1', 'marathon_ready');
    });

    it('should unlock speed_demon when pace < 4:00/km', async () => {
      const mockRun = {
        id: 'run1',
        userId: 'user1',
        distanceM: 5000,
        durationS: 1100,
        avgPace: '3:40',
      } as Run;

      repo.findByUserId = jest.fn().mockResolvedValue({
        userId: 'user1',
        totalXp: 500,
        level: 3,
        currentStreak: 2,
        longestStreak: 3,
        lastActivityDate: '2026-05-13',
        unlockedBadges: ['first_run'],
        updatedAt: '2026-05-13T10:00:00.000Z',
      });
      repo.unlockBadge = jest.fn().mockResolvedValue(undefined);

      const unlocked = await useCase.execute('user1', mockRun, 5);

      expect(unlocked).toContain('speed_demon');
      expect(repo.unlockBadge).toHaveBeenCalledWith('user1', 'speed_demon');
    });

    it('should unlock week_warrior on 7-day streak', async () => {
      const mockRun = {
        id: 'run1',
        userId: 'user1',
        distanceM: 5000,
        durationS: 1800,
        avgPace: '6:00',
      } as Run;

      repo.findByUserId = jest.fn().mockResolvedValue({
        userId: 'user1',
        totalXp: 700,
        level: 4,
        currentStreak: 7,
        longestStreak: 7,
        lastActivityDate: '2026-05-13',
        unlockedBadges: ['first_run'],
        updatedAt: '2026-05-13T10:00:00.000Z',
      });
      repo.unlockBadge = jest.fn().mockResolvedValue(undefined);

      const unlocked = await useCase.execute('user1', mockRun, 10);

      expect(unlocked).toContain('week_warrior');
      expect(repo.unlockBadge).toHaveBeenCalledWith('user1', 'week_warrior');
    });

    it('should not unlock already unlocked badges', async () => {
      const mockRun = {
        id: 'run1',
        userId: 'user1',
        distanceM: 5000,
        durationS: 1800,
        avgPace: '6:00',
      } as Run;

      repo.findByUserId = jest.fn().mockResolvedValue({
        userId: 'user1',
        totalXp: 500,
        level: 3,
        currentStreak: 2,
        longestStreak: 5,
        lastActivityDate: '2026-05-13',
        unlockedBadges: ['first_run', 'week_warrior'],
        updatedAt: '2026-05-13T10:00:00.000Z',
      });
      repo.unlockBadge = jest.fn().mockResolvedValue(undefined);

      const unlocked = await useCase.execute('user1', mockRun, 10);

      expect(unlocked).not.toContain('first_run');
      expect(unlocked).not.toContain('week_warrior');
    });
  });
});
