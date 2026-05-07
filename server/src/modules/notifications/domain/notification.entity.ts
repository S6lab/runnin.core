export type NotificationType =
  | 'melhor_horario'
  | 'preparo_nutricional'
  | 'hidratacao'
  | 'checklist_pre_easy_run'
  | 'sono_performance'
  | 'bpm_real'
  | 'fechamento_mensal'
  | 'plan_ready'
  | 'coach_message';

export interface Notification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  icon: string;
  timeLabel?: string;
  ctaLabel?: string;
  ctaRoute?: string;
  data?: Record<string, unknown>;
  createdAt: string;
  readAt?: string;
  dismissedAt?: string;
}
