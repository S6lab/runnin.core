import { Notification } from './notification.entity';

export interface NotificationRepository {
  findById(userId: string, id: string): Promise<Notification | null>;
  listActive(userId: string): Promise<Notification[]>;
  createIfAbsent(notification: Notification): Promise<Notification>;
  /**
   * Sobrescreve `title/body/icon/timeLabel/cta*` e `data` mas preserva
   * `dismissedAt`/`readAt`. Usado quando o conteúdo da notificação muda
   * mid-day por correção de bug (ex: hidratação acima do cap por deploy
   * antigo). Não respawn-a notificações dispensadas — só atualiza
   * conteúdo, o estado de leitura/dispensa fica.
   */
  upsertPreserveUserState(notification: Notification): Promise<Notification>;
  dismiss(userId: string, id: string, at: string): Promise<void>;
  dismissAll(userId: string, at: string): Promise<number>;
  markRead(userId: string, id: string, at: string): Promise<void>;
}
