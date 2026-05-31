import { Notification } from './notification.entity';

export interface ListActiveOptions {
  /** Quantos itens trazer. Default 30. */
  limit?: number;
  /** Cursor opaco: ISO timestamp do `createdAt` do último item da página anterior. */
  before?: string;
}

export interface ListActiveResult {
  items: Notification[];
  /** ISO timestamp pra próxima página. Null = última página. */
  nextCursor: string | null;
}

export interface NotificationRepository {
  findById(userId: string, id: string): Promise<Notification | null>;
  listActive(userId: string, opts?: ListActiveOptions): Promise<ListActiveResult>;
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
