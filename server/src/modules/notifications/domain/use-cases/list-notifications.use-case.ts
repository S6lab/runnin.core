import {
  ListActiveOptions,
  ListActiveResult,
  NotificationRepository,
} from '../notification.repository';

export class ListNotificationsUseCase {
  constructor(private readonly repo: NotificationRepository) {}

  async execute(
    userId: string,
    opts: ListActiveOptions = {},
  ): Promise<ListActiveResult> {
    return this.repo.listActive(userId, opts);
  }
}
