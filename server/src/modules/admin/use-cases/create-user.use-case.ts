import { z } from 'zod';
import { getAuth, getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import type { UserProfile } from '@modules/users/domain/user.entity';

export const CreateUserSchema = z
  .object({
    email: z.string().trim().email().optional(),
    phone: z
      .string()
      .trim()
      .regex(/^\+\d{8,15}$/, 'phone must be E.164 (+5511…)')
      .optional(),
    name: z.string().trim().min(1).max(120).optional(),
    plan: z.string().trim().min(2).max(40).default('freemium'),
    password: z
      .string()
      .min(6)
      .max(128)
      .optional()
      .describe(
        'opcional: se omitido, user precisa usar reset de senha pra acessar (email link)',
      ),
  })
  .refine((v) => Boolean(v.email || v.phone), {
    message: 'email ou phone obrigatório',
    path: ['email'],
  });

export type CreateUserInput = z.infer<typeof CreateUserSchema>;

export interface CreateUserResult {
  uid: string;
  email: string | null;
  phone: string | null;
  name: string | null;
  plan: string;
  createdAuthUser: boolean;
  createdProfile: boolean;
}

/**
 * Cria um usuário admin-side:
 *  1. Cria registro no Firebase Auth (createUser) — falha se email/phone já existe
 *  2. Cria documento `users/{uid}` no Firestore com o plano escolhido
 *  3. Retorna metadados
 *
 * Diferente do `provision-user` (chamado pelo cliente após signup do user),
 * essa rota nunca depende de o user já existir em Auth — cria do zero.
 * Idempotência: NÃO é idempotente. Use `tester/seed` se quiser idempotente
 * + biometrics + claims admin.
 */
export class CreateUserUseCase {
  async execute(input: CreateUserInput): Promise<CreateUserResult> {
    const auth = getAuth();
    const db = getFirestore();

    const createPayload: {
      email?: string;
      phoneNumber?: string;
      displayName?: string;
      password?: string;
      emailVerified?: boolean;
    } = {};
    if (input.email) createPayload.email = input.email;
    if (input.phone) createPayload.phoneNumber = input.phone;
    if (input.name) createPayload.displayName = input.name;
    if (input.password) createPayload.password = input.password;
    if (input.email && !input.password) createPayload.emailVerified = false;

    const authUser = await auth.createUser(createPayload);
    logger.info('admin.users.create.auth_created', {
      uid: authUser.uid,
      email: authUser.email ?? null,
      phone: authUser.phoneNumber ?? null,
    });

    const now = new Date().toISOString();
    const profile: UserProfile = {
      id: authUser.uid,
      authId: authUser.uid,
      email: authUser.email ?? undefined,
      phone: authUser.phoneNumber ?? undefined,
      name: input.name?.trim() ?? '',
      level: 'iniciante',
      goal: '',
      frequency: 3,
      birthDate: undefined,
      weight: undefined,
      height: undefined,
      hasWearable: false,
      medicalConditions: [],
      coachVoiceId: undefined,
      subscriptionPlanId: input.plan,
      subscriptionStatus: 'active',
      subscriptionStartedAt: now,
      premium: input.plan !== 'freemium',
      operatorId: undefined,
      onboarded: false,
      createdAt: now,
      updatedAt: now,
    };

    await db
      .collection('users')
      .doc(authUser.uid)
      .set(profile, { merge: true });

    logger.info('admin.users.create.profile_created', {
      uid: authUser.uid,
      plan: input.plan,
    });

    return {
      uid: authUser.uid,
      email: authUser.email ?? null,
      phone: authUser.phoneNumber ?? null,
      name: authUser.displayName ?? null,
      plan: input.plan,
      createdAuthUser: true,
      createdProfile: true,
    };
  }
}
