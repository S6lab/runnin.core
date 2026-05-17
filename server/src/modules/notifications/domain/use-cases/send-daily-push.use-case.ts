import { UserRepository } from '@modules/users/domain/user.repository';
import { PlanRepository } from '@modules/plans/domain/plan.repository';
import { PlanSession } from '@modules/plans/domain/plan.entity';
import { FirestoreDeviceRepository } from '../../infra/firestore-device.repository';
import { getMessaging } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

function pickCurrentWeekSessions(
  plan: { weeks: { sessions: PlanSession[] }[]; createdAt: string } | null,
): PlanSession[] {
  if (!plan || plan.weeks.length === 0) return [];
  const created = new Date(plan.createdAt);
  const days = Math.floor((Date.now() - created.getTime()) / 86_400_000);
  const idx = Math.max(0, Math.min(plan.weeks.length - 1, Math.floor(days / 7)));
  return plan.weeks[idx]?.sessions ?? [];
}

function todaySessionFor(sessions: PlanSession[]): PlanSession | null {
  const today = new Date().getDay() || 7; // 0=Sun → 7
  return sessions.find(s => s.dayOfWeek === today) ?? null;
}

function buildMessage(session: PlanSession | null, profileName?: string | null): { title: string; body: string } {
  const greet = profileName ? `${profileName.split(' ')[0]}, ` : '';
  if (session) {
    const type = session.type ?? 'Treino';
    const dist = session.distanceKm ? ` ${session.distanceKm}km` : '';
    return {
      title: `Hoje: ${type}${dist}`,
      body: `${greet}prepare-se! Hidrate, aqueça e busque o ritmo do plano. Bora correr.`.trim(),
    };
  }
  return {
    title: 'Hoje é descanso',
    body: `${greet}sem corrida planejada hoje. Aproveite pra hidratar, dormir bem e mobilidade leve.`.trim(),
  };
}

/**
 * Envia 1 push motivacional por dia indicando se há treino planejado.
 * Respeita user.notificationsEnabled.push (default true se ausente) — mesmo
 * campo que o toggle "Push" da tela de Alertas grava em /users/me.
 */
export class SendDailyPushUseCase {
  private readonly devices = new FirestoreDeviceRepository();

  constructor(
    private readonly userRepo: UserRepository,
    private readonly planRepo: PlanRepository,
  ) {}

  async executeForUser(userId: string): Promise<{ sent: number; skipped: string | null }> {
    const profile = await this.userRepo.findById(userId);
    if (!profile?.onboarded) return { sent: 0, skipped: 'not_onboarded' };
    const enabled = profile.notificationsEnabled?.push ?? true;
    if (!enabled) return { sent: 0, skipped: 'disabled_by_user' };

    const tokens = await this.devices.listByUser(userId);
    if (tokens.length === 0) return { sent: 0, skipped: 'no_devices' };

    const plan = await this.planRepo.findCurrent(userId);
    const sessions = pickCurrentWeekSessions(plan);
    const today = todaySessionFor(sessions);
    const msg = buildMessage(today, profile.name);

    let sent = 0;
    const messaging = getMessaging();
    await Promise.all(
      tokens.map(async (d) => {
        try {
          await messaging.send({
            token: d.token,
            notification: { title: msg.title, body: msg.body },
            data: { kind: 'daily_motivational', route: today ? '/training' : '/home' },
          });
          sent++;
        } catch (err) {
          logger.warn('push.daily.send_failed', {
            uid: userId, tokenId: d.id, err: String(err),
          });
        }
      }),
    );
    return { sent, skipped: null };
  }
}
