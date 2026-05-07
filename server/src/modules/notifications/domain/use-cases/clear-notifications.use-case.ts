import { NotificationRepository } from '../notification.repository';

export class ClearNotificationsUseCase {
  constructor(private readonly repo: NotificationRepository) {}

  async execute(userId: string): Promise<{ dismissed: number }> {
    const dismissed = await this.repo.dismissAll(userId, new Date().toISOString());
    return { dismissed };
  }
}
