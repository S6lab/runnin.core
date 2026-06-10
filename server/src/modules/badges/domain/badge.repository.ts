import { Badge } from './badge.entity';

export interface BadgeRepository {
  /** Lista todos os badges DESBLOQUEADOS de um user, ordenados por unlockedAt. */
  listByUser(uid: string): Promise<Badge[]>;

  /** Pega 1 badge específico do user. Retorna null se ainda não desbloqueou. */
  findByUser(uid: string, badgeId: string): Promise<Badge | null>;

  /** Persiste o badge desbloqueado. Idempotente — se já existe, faz upsert. */
  save(uid: string, badge: Badge): Promise<void>;

  /** Marca como visto. */
  markSeen(uid: string, badgeId: string): Promise<void>;

  /** Incrementa shareCount. */
  incrementShare(uid: string, badgeId: string): Promise<void>;
}
