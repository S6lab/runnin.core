import { UserProfile } from './user.entity';

export interface UserRepository {
  findById(id: string): Promise<UserProfile | null>;
  upsert(profile: UserProfile): Promise<void>;
  /** Merge patch parcial no doc do usuário (não falha se o doc não existe). */
  updatePartial(id: string, patch: Partial<UserProfile>): Promise<void>;
  archiveOnboarding(userId: string, snapshot: UserProfile): Promise<void>;
  /**
   * Lista usuários ordenados por id. `startAfterId` permite paginação real
   * por cursor (passe o id do último doc do lote anterior) — sem ele, o lote
   * sempre começa do início. Necessário pra crons percorrerem >limit usuários.
   */
  list(limit?: number, startAfterId?: string): Promise<UserProfile[]>;
}
