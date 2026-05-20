import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile, isPremium } from '../user.entity';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { GeneratePlanUseCase } from '@modules/plans/use-cases/generate-plan.use-case';
import { CooldownError, PremiumRequiredError } from '@shared/errors/app-error';
import { container } from '@shared/container';
import { logger } from '@shared/logger/logger';

// Ranges sensatos pra rejeitar dados nonsense (ex: peso 10kg, idade 200).
// Server é a source of truth — mesmo se app pular validation, server barra.
// Mensagens em PT-BR pra app exibir direto pro user.
const weightRegex = /^\d{1,3}([.,]\d{1,2})?$/;
const heightRegex = /^\d{2,3}$/;
const birthDateRegex = /^\d{2}\/\d{2}\/\d{4}$/;

function ageFromBirthDate(br: string): number | null {
  const m = birthDateRegex.exec(br);
  if (!m) return null;
  const [dd, mm, yyyy] = br.split('/').map(Number);
  if (!dd || !mm || !yyyy) return null;
  const birth = new Date(yyyy, mm - 1, dd);
  if (birth.getDate() !== dd || birth.getMonth() !== mm - 1 || birth.getFullYear() !== yyyy) return null;
  const now = new Date();
  let age = now.getFullYear() - yyyy;
  if (now.getMonth() < mm - 1 || (now.getMonth() === mm - 1 && now.getDate() < dd)) age--;
  return age;
}

export const CompleteOnboardingSchema = z.object({
  name: z.string()
    .min(2, 'Nome precisa ter pelo menos 2 caracteres')
    .max(60, 'Nome muito longo (máx 60 caracteres)'),
  level: z.enum(['iniciante', 'intermediario', 'avancado']),
  goal: z.string()
    .min(3, 'Objetivo é obrigatório')
    .max(120, 'Objetivo muito longo (máx 120 caracteres)'),
  frequency: z.number().int()
    .min(1, 'Frequência mínima é 1x por semana')
    .max(7, 'Frequência máxima é 7x por semana'),
  // Data de nascimento: formato dd/mm/yyyy + idade 12-100 anos.
  // O app coleta no formato BR; rejeita datas impossíveis tipo 31/02.
  birthDate: z.string()
    .regex(birthDateRegex, 'Data de nascimento deve estar no formato dd/mm/aaaa')
    .refine((v) => {
      const age = ageFromBirthDate(v);
      return age !== null && age >= 12 && age <= 100;
    }, 'Idade deve estar entre 12 e 100 anos'),
  // Peso: 25-300 kg (range cobre desde crianças até atletas robustos).
  // Aceita string com vírgula ou ponto decimal ("70" ou "70,5" ou "70.5").
  weight: z.string()
    .regex(weightRegex, 'Peso deve ser um número (ex: 70 ou 70.5)')
    .refine((v) => {
      const n = parseFloat(v.replace(',', '.'));
      return n >= 25 && n <= 300;
    }, 'Peso deve estar entre 25 e 300 kg'),
  // Altura: 80-250 cm (criança baixa até gigante).
  height: z.string()
    .regex(heightRegex, 'Altura deve ser um número inteiro em cm (ex: 175)')
    .refine((v) => {
      const n = parseInt(v, 10);
      return n >= 80 && n <= 250;
    }, 'Altura deve estar entre 80 e 250 cm'),
  hasWearable: z.boolean().default(false),
  // medicalConditions pode ser array vazio (user clica "nenhuma"), mas
  // o array em si DEVE estar presente (forçar passagem pelo step médico).
  medicalConditions: z.array(z.string().max(200)).max(20, 'Máximo de 20 condições'),
  // Tudo abaixo é obrigatório — força user a passar por cada step do
  // onboarding. Sem isso, app permitia pular (mandando null) e plano
  // gerado ficava com dados faltando = personalização ruim.
  gender: z.enum(['male', 'female', 'other', 'na']),
  runPeriod: z.enum(['manha', 'tarde', 'noite']),
  wakeTime: z.string().regex(/^\d{2}:\d{2}$/, 'Hora de acordar inválida (use HH:MM)'),
  sleepTime: z.string().regex(/^\d{2}:\d{2}$/, 'Hora de dormir inválida (use HH:MM)'),
  // targetPace é frase descritiva (ex: "Entre 6:00 e 7:00/km", "Deixa
  // o Coach decidir"). Forçar opção selecionada (inclusive "Deixa o
  // Coach decidir" pra user que não sabe).
  targetPace: z.string().min(1, 'Selecione uma opção de pace').max(60),
});

export type CompleteOnboardingInput = z.infer<typeof CompleteOnboardingSchema>;

function getCooldownDays(): number {
  const raw = Number(process.env.ONBOARDING_COOLDOWN_DAYS);
  return Number.isFinite(raw) && raw >= 0 ? raw : 7;
}

function isProOnly(): boolean {
  return (process.env.ONBOARDING_PRO_ONLY ?? 'false').toLowerCase() === 'true';
}

export class CompleteOnboardingUseCase {
  private planRepo = new FirestorePlanRepository();
  private generatePlan = new GeneratePlanUseCase(this.planRepo);

  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: CompleteOnboardingInput): Promise<{ user: UserProfile; planId: string | null }> {
    const now = new Date().toISOString();
    const existing = await this.userRepo.findById(userId);
    const isRedo = !!existing?.onboarded;

    if (isRedo) {
      const premium = isPremium(existing);
      if (isProOnly() && !premium) {
        throw new PremiumRequiredError('Refazer onboarding está disponível apenas no plano Pro.');
      }
      const cooldownDays = getCooldownDays();
      if (cooldownDays > 0 && existing?.lastOnboardingAt) {
        const last = new Date(existing.lastOnboardingAt).getTime();
        const availableAtMs = last + cooldownDays * 24 * 60 * 60 * 1000;
        if (Date.now() < availableAtMs) {
          throw new CooldownError(
            new Date(availableAtMs).toISOString(),
            `Você poderá refazer o onboarding em breve.`,
          );
        }
      }
      // Snapshot da versão atual antes de sobrescrever
      if (existing) await this.userRepo.archiveOnboarding(userId, existing);
    }

    const profile: UserProfile = {
      id: userId,
      name: input.name,
      level: input.level,
      goal: input.goal,
      frequency: input.frequency,
      birthDate: input.birthDate,
      weight: input.weight,
      height: input.height,
      hasWearable: input.hasWearable,
      medicalConditions: input.medicalConditions,
      coachVoiceId: existing?.coachVoiceId,
      // New fields from Phase 4 foundation
      gender: input.gender ?? existing?.gender,
      runPeriod: input.runPeriod ?? existing?.runPeriod,
      wakeTime: input.wakeTime ?? existing?.wakeTime,
      sleepTime: input.sleepTime ?? existing?.sleepTime,
      // Quota initialized on first onboarding
      planRevisions: existing?.planRevisions ?? { usedThisWeek: 0, max: 1, resetAt: now },
      premium: existing?.premium ?? false,
      premiumUntil: existing?.premiumUntil,
      lastOnboardingAt: now,
      operatorId: existing?.operatorId,
      onboarded: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };

    await this.userRepo.upsert(profile);

    // Geração de plano é feature do billing plan (Pro). Free conclui o
    // onboarding SEM plano e SEM coach — o app oferece o upgrade. A permissão
    // é centralizada no billing plan (getUserFeatures), não em flags soltas.
    const canGeneratePlan = await container.useCases.getUserFeatures.hasFeature(
      userId,
      'generatePlan',
    );
    if (!canGeneratePlan) {
      logger.info('onboarding.plan.skipped_free_tier', { userId });
      return { user: profile, planId: null };
    }

    const plan = await this.generatePlan.execute(userId, {
      goal: input.goal,
      level: input.level,
      frequency: input.frequency,
    });

    return { user: profile, planId: plan.id };
  }
}
