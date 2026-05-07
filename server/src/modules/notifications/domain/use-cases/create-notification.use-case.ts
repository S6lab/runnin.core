import { Notification, NotificationType } from '../notification.entity';
import { NotificationRepository } from '../notification.repository';

export interface CreateNotificationInput {
  userId: string;
  type: NotificationType;
  /**
   * Identificador estável para idempotência (ex: \`YYYY-MM-DD\`, planId).
   * Combinado com \`type\` forma o id do documento.
   */
  dedupeKey: string;
  title: string;
  body: string;
  icon: string;
  timeLabel?: string;
  ctaLabel?: string;
  ctaRoute?: string;
  data?: Record<string, unknown>;
}

export class CreateNotificationUseCase {
  constructor(private readonly repo: NotificationRepository) {}

  async execute(input: CreateNotificationInput): Promise<Notification> {
    const id = `${input.type}_${input.dedupeKey}`;
    const notification: Notification = {
      id,
      userId: input.userId,
      type: input.type,
      title: input.title,
      body: input.body,
      icon: input.icon,
      timeLabel: input.timeLabel,
      ctaLabel: input.ctaLabel,
      ctaRoute: input.ctaRoute,
      data: input.data,
      createdAt: new Date().toISOString(),
    };
    return this.repo.createIfAbsent(notification);
  }
}
