import { NotFoundError } from '@shared/errors/app-error';
import { NotificationRepository } from '../notification.repository';

export class MarkReadUseCase {
  constructor(private readonly repo: NotificationRepository) {}

  async execute(userId: string, id: string): Promise<void> {
    const existing = await this.repo.findById(userId, id);
    if (!existing) throw new NotFoundError('Notification');
    if (existing.readAt) return;
    await this.repo.markRead(userId, id, new Date().toISOString());
  }
}
