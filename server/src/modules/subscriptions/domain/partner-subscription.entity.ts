/**
 * Assinatura de benefício enviada por um parceiro (ex: Claro). Vive na
 * collection top-level `subscriptions` (potencialmente milhões de docs),
 * indexada por `identifier` (telefone/CPF/email — inicialmente telefone).
 */
export type BenefitIdentifierType = 'phone' | 'cpf' | 'email';

export type PartnerSubscriptionStatus =
  | 'active'
  | 'cancelled'
  | 'reactivated'
  | 'pending';

export interface PartnerSubscription {
  /** ID da assinatura enviado pelo parceiro (doc id na collection). */
  id: string;
  /** Identificador normalizado do assinante (digits p/ phone/cpf, lower p/ email). */
  identifier: string;
  identifierType: BenefitIdentifierType;
  /** Parceiro/provider (ex: 'claro'). */
  provider: string;
  /**
   * ID do serviço junto ao parceiro (ex: 'claro_runnin_basic'). O plano do app
   * é resolvido na ATIVAÇÃO casando este `serviceId` com `SubscriptionPlan.serviceId`.
   */
  serviceId: string;
  status: PartnerSubscriptionStatus;
  createdAt: string;
  cancelledAt?: string;
  reactivatedAt?: string;
  /** Quando o usuário ATIVOU o benefício no app. */
  activatedAt?: string;
  /** UID que reivindicou o benefício (setado na ativação). */
  userId?: string;
}

/** Status que ainda valem como benefício disponível pra ativar. */
export function isClaimable(s: PartnerSubscriptionStatus): boolean {
  return s === 'active' || s === 'reactivated';
}

/**
 * Detecta o tipo do identificador e normaliza. Inicialmente o app só envia
 * telefone, mas a detecção já cobre CPF e email pra ingestão futura.
 *  - email: contém '@' → lowercase
 *  - cpf: 11 dígitos com dígitos verificadores válidos
 *  - phone: demais → só dígitos (E.164 sem '+')
 */
export function detectIdentifier(raw: string): {
  type: BenefitIdentifierType;
  normalized: string;
} {
  const v = (raw ?? '').trim();
  if (v.includes('@')) {
    return { type: 'email', normalized: v.toLowerCase() };
  }
  const digits = v.replace(/\D/g, '');
  if (digits.length === 11 && isValidCpf(digits)) {
    return { type: 'cpf', normalized: digits };
  }
  return { type: 'phone', normalized: digits };
}

/** Normaliza um telefone E.164 (+55...) ou cru pra só dígitos. */
export function normalizePhone(raw: string): string {
  return (raw ?? '').replace(/\D/g, '');
}

/** Validação de CPF (dígitos verificadores). `digits` deve ter 11 chars. */
export function isValidCpf(digits: string): boolean {
  if (digits.length !== 11) return false;
  if (/^(\d)\1{10}$/.test(digits)) return false; // todos iguais
  const calc = (len: number): number => {
    let sum = 0;
    for (let i = 0; i < len; i++) {
      sum += Number(digits[i]) * (len + 1 - i);
    }
    const rest = (sum * 10) % 11;
    return rest === 10 ? 0 : rest;
  };
  return calc(9) === Number(digits[9]) && calc(10) === Number(digits[10]);
}
