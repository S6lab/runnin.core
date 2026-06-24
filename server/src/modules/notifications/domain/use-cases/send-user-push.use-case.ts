import { UserRepository } from '@modules/users/domain/user.repository';
import { FirestoreDeviceRepository } from '../../infra/firestore-device.repository';
import { getMessaging } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

export interface UserPushInput {
  title: string;
  body: string;
  /** Payload de dados (ex.: { kind, route, ...ids }). Tudo string. */
  data?: Record<string, string>;
}

/**
 * Envia um push (FCM) pra todos os devices de um usuário. Respeita o toggle
 * `notificationsEnabled.push` (default true) — mesmo do SendDailyPush. Best-
 * effort: falha por token não derruba os demais.
 */
export class SendUserPushUseCase {
  private readonly devices = new FirestoreDeviceRepository();

  constructor(private readonly userRepo: UserRepository) {}

  async execute(
    userId: string,
    input: UserPushInput,
  ): Promise<{ sent: number; skipped: string | null }> {
    const profile = await this.userRepo.findById(userId);
    if (!profile?.onboarded) return { sent: 0, skipped: 'not_onboarded' };
    if ((profile.notificationsEnabled?.push ?? true) === false) {
      return { sent: 0, skipped: 'disabled_by_user' };
    }
    const tokens = await this.devices.listByUser(userId);
    if (tokens.length === 0) return { sent: 0, skipped: 'no_devices' };

    const messaging = getMessaging();
    let sent = 0;
    await Promise.all(
      tokens.map(async (d) => {
        try {
          await messaging.send({
            token: d.token,
            notification: { title: input.title, body: input.body },
            data: input.data ?? {},
            // iOS: garante som/badge/banner (FCM monta auto, mas tem casos
            // de devices ficarem silenciosos sem `apns` explícito).
            apns: {
              headers: { 'apns-priority': '10' },
              payload: {
                aps: {
                  alert: { title: input.title, body: input.body },
                  sound: 'default',
                  badge: 1,
                },
              },
            },
            // Android: high priority + channel pro Doze mode não atrasar.
            android: {
              priority: 'high',
              notification: { sound: 'default', channelId: 'runnin_default' },
            },
          });
          sent++;
        } catch (err) {
          logger.warn('push.user.send_failed', {
            uid: userId,
            tokenId: d.id,
            platform: d.platform,
            err: String(err),
          });
        }
      }),
    );
    return { sent, skipped: null };
  }
}
