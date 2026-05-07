import { Notification } from '../notification.entity';
import { NotificationRepository } from '../notification.repository';

export class ListNotificationsUseCase {
  constructor(private readonly repo: NotificationRepository) {}

  async execute(userId: string): Promise<Notification[]> {
    return this.repo.listActive(userId);
  }
}
