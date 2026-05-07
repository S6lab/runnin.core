import { Notification } from './notification.entity';

export interface NotificationRepository {
  findById(userId: string, id: string): Promise<Notification | null>;
  listActive(userId: string): Promise<Notification[]>;
  createIfAbsent(notification: Notification): Promise<Notification>;
  dismiss(userId: string, id: string, at: string): Promise<void>;
  dismissAll(userId: string, at: string): Promise<number>;
  markRead(userId: string, id: string, at: string): Promise<void>;
}
