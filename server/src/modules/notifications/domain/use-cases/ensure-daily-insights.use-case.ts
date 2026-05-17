import { UserRepository } from '@modules/users/domain/user.repository';
import { PlanRepository } from '@modules/plans/domain/plan.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { CreateNotificationInput, CreateNotificationUseCase } from './create-notification.use-case';
import { PlanSession } from '@modules/plans/domain/plan.entity';
import { NotificationRepository } from '../notification.repository';

const DAY_NAMES = ['', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'];

function todayKey(): string {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function pickCurrentWeek(plan: { weeks: { sessions: PlanSession[]; restDayTips?: Array<{ dayOfWeek: number; hydrationLiters?: number; nutrition?: string; focus?: string }> }[]; createdAt: string } | null) {
  if (!plan || plan.weeks.length === 0) return null;
  const created = new Date(plan.createdAt);
  const days = Math.floor((Date.now() - created.getTime()) / 86_400_000);
  const idx = Math.max(0, Math.min(plan.weeks.length - 1, Math.floor(days / 7)));
  return plan.weeks[idx] ?? null;
}

function pickCurrentWeekSessions(plan: { weeks: { sessions: PlanSession[] }[]; createdAt: string } | null): PlanSession[] {
  const week = pickCurrentWeek(plan as any);
  return week?.sessions ?? [];
}

function nextSessionFromToday(sessions: PlanSession[]): PlanSession | null {
  if (sessions.length === 0) return null;
  const today = new Date().getDay() || 7; // 0=Sun → 7
  const ordered = [...sessions].sort((a, b) => a.dayOfWeek - b.dayOfWeek);
  return (
    ordered.find(s => s.dayOfWeek >= today) ?? ordered[0] ?? null
  );
}

type SessionKind = 'long' | 'tempo' | 'interval' | 'easy' | 'rest';

function classifySession(session: PlanSession | null): SessionKind {
  if (!session) return 'rest';
  const t = (session.type ?? '').toLowerCase();
  if (t.includes('long')) return 'long';
  if (t.includes('tempo')) return 'tempo';
  if (t.includes('interval')) return 'interval';
  if (t.includes('easy') || t.includes('regenerativ') || t.includes('recovery')) return 'easy';
  return 'easy';
}

function nutritionBodyFor(session: PlanSession | null, kind: SessionKind): string {
  if (!session) {
    return 'Sem sessão marcada hoje — foco em recuperação: refeição leve, vegetais, proteína magra e bastante água ao longo do dia.';
  }
  const km = session.distanceKm ? `${session.distanceKm}km` : 'a sessão';
  switch (kind) {
    case 'long':
      return `Hoje é Long Run (${km}). Faça refeição rica em carbo 2-3h antes (arroz/batata/aveia + fruta), evite gordura e fibra pesada. Leve gel ou banana se passar de 60min.`;
    case 'tempo':
      return `Tempo Run hoje (${km}). Carbo de fácil digestão 90min antes (pão branco + mel, banana com aveia). Evite proteína pesada — você vai trabalhar em ritmo forte.`;
    case 'interval':
      return `Intervalado hoje (${km}). Carbo simples 45-60min antes (banana, tâmaras ou pão com geleia). Hidrate bem antes — você vai precisar de glicogênio disponível.`;
    case 'easy':
    default:
      return `Easy Run hoje (${km}). Refeição leve 45-60min antes, evite gordura e fibra exagerada. Pode ser fruta + iogurte ou pão com queijo branco.`;
  }
}

function hydrationBodyFor(
  session: PlanSession | null,
  kind: SessionKind,
  goalLiters: number | null,
): string {
  if (goalLiters == null) {
    return 'Informe seu peso no perfil para o app calcular sua meta diária de hidratação.';
  }
  const goal = goalLiters.toFixed(1);
  if (!session) {
    return `Meta diária: ${goal}L. Sem treino hoje — distribua o consumo ao longo do dia e registre os copos.`;
  }
  switch (kind) {
    case 'long':
      return `Meta hoje: ${goal}L + 500ml extra antes do Long Run e 150-200ml a cada 20min em corrida. Eletrólito ao final ajuda recuperação.`;
    case 'tempo':
      return `Meta hoje: ${goal}L. Pré-load de 400ml 60-90min antes do Tempo Run, mais 250ml 15min antes. Evite encher o estômago no aquecimento.`;
    case 'interval':
      return `Meta hoje: ${goal}L. Beba 300ml 30min antes do intervalado e mantenha gole pequeno entre tiros. Reidrate forte no pós.`;
    case 'easy':
    default:
      return `Meta diária: ${goal}L. Para o Easy Run, 250ml 30min antes basta. Registre os copos durante o dia.`;
  }
}

/**
 * Garante que as 7 notificações diárias do coach existem para o usuário no dia atual.
 * Idempotente: cada notificação tem id `${type}_${YYYY-MM-DD}` — chamadas repetidas
 * não duplicam, e se o usuário já dispensou, não é recriada (porque o doc continua existindo).
 */
export class EnsureDailyInsightsUseCase {
  constructor(
    private readonly create: CreateNotificationUseCase,
    private readonly userRepo: UserRepository,
    private readonly planRepo: PlanRepository,
    private readonly runRepo: RunRepository,
    /**
     * Repo direto pra `hidratacao`: usa upsert (preserva dismiss/read)
     * em vez de createIfAbsent, pra que correção de bug de cap (ex:
     * 6.3L em deploy antigo) se autocorrige no próximo cron sem ter
     * que esperar o próximo dia.
     */
    private readonly notifRepo: NotificationRepository,
  ) {}

  async execute(userId: string): Promise<void> {
    const [profile, plan, runsResult] = await Promise.all([
      this.userRepo.findById(userId),
      this.planRepo.findCurrent(userId),
      this.runRepo.findByUser(userId, 30),
    ]);

    if (!profile?.onboarded) return;

    const dedupeKey = todayKey();
    const completedRuns = runsResult.runs.filter(r => r.status === 'completed');
    const currentWeek = pickCurrentWeek(plan as any);
    const sessions = currentWeek?.sessions ?? [];
    const todayWeekday = new Date().getDay() || 7;
    const todaySession = sessions.find(s => s.dayOfWeek === todayWeekday) ?? null;
    const nextSession = todaySession ?? nextSessionFromToday(sessions);
    const todayRestTip = !todaySession
      ? currentWeek?.restDayTips?.find(t => t.dayOfWeek === todayWeekday) ?? null
      : null;

    const hasBpmData = completedRuns.some(r => (r.avgBpm ?? 0) > 0 || (r.maxBpm ?? 0) > 0);
    const hasSleepData = false; // sem integração de sono ainda
    const weight = profile.weight ? Number(profile.weight.replace(/[^0-9.]/g, '')) : null;
    // Fallback CAP em 3.5L: pra weights muito altos (130kg+) a fórmula peso×0.035
    // dá 4.5L+ que ninguém bebe num dia normal. Cap em 3.5L é meta saudável
    // recomendada (WHO + American Council on Exercise) pra adultos comuns.
    const rawFallback = weight && weight > 0 ? +(weight * 0.035).toFixed(1) : null;
    const fallbackHydration = rawFallback != null
      ? Math.min(rawFallback, 3.5)
      : null;
    // Prioridade: hidratação da sessão do plano (coach calibrou) > rest-day
    // tip do plano > fallback genérico capado. Plan data sempre vence.
    const planHydration = todaySession?.hydrationLiters ?? todayRestTip?.hydrationLiters;
    // Sanity-cap também no plan data — defensivo contra LLM hallucination
    // (já vimos caso de gerar 6.3L). Máx absoluto 4L mesmo se for Long Run.
    const cappedPlanHydration = planHydration != null
      ? Math.min(planHydration, 4.0)
      : null;
    const hydrationGoalLiters = cappedPlanHydration ?? fallbackHydration;

    const periodLabel: Record<string, string> = { manha: '06-09h', tarde: '14-17h', noite: '19-21h' };
    const periodSuggestion = profile.runPeriod
      ? `Você prefere ${profile.runPeriod} (${periodLabel[profile.runPeriod]}). Janela sugerida para ${nextSession?.type ?? 'a próxima sessão'}: aqueça sem pressa antes e mantenha recuperação depois.`
      : nextSession
        ? `Janela sugerida para ${nextSession.type}: escolha um horário em que você consiga aquecer sem pressa e manter recuperação depois.`
        : 'Sem próxima sessão planejada. Quando houver plano, o coach sugere horário e janela de aquecimento.';

    const inputs: CreateNotificationInput[] = [
      {
        userId,
        type: 'melhor_horario',
        dedupeKey,
        title: 'MELHOR HORARIO',
        icon: 'alarm_outlined',
        timeLabel: profile.wakeTime ?? (nextSession ? DAY_NAMES[nextSession.dayOfWeek] : 'AGORA'),
        body: periodSuggestion,
        ctaLabel: nextSession ? undefined : 'ABRIR TREINO',
        ctaRoute: nextSession ? undefined : '/training',
      },
      {
        userId,
        type: 'preparo_nutricional',
        dedupeKey,
        title: 'PREPARO NUTRICIONAL',
        icon: 'restaurant_outlined',
        timeLabel: todaySession ? 'ANTES' : 'RECUP.',
        // Prioridade: nutrição do plano (pré-treino da sessão de hoje OU
        // rest-day tip) > fallback genérico por tipo de sessão.
        body: todaySession?.nutritionPre
          ?? todayRestTip?.nutrition
          ?? nutritionBodyFor(todaySession, classifySession(todaySession)),
        data: todaySession
          ? {
              sessionType: todaySession.type,
              sessionDistanceKm: todaySession.distanceKm,
              ...(todaySession.nutritionPre ? { nutritionPre: todaySession.nutritionPre } : {}),
              ...(todaySession.nutritionPost ? { nutritionPost: todaySession.nutritionPost } : {}),
            }
          : todayRestTip
            ? { restDay: true, focus: todayRestTip.focus }
            : undefined,
      },
      {
        userId,
        type: 'hidratacao',
        dedupeKey,
        title: 'HIDRATACAO',
        icon: 'water_drop_outlined',
        timeLabel: hydrationGoalLiters == null
          ? 'SEM META'
          : todaySession ? 'TREINO' : 'HOJE',
        body: hydrationBodyFor(todaySession, classifySession(todaySession), hydrationGoalLiters),
        ctaLabel: hydrationGoalLiters == null ? 'INFORMAR PESO' : undefined,
        ctaRoute: hydrationGoalLiters == null ? '/profile/edit' : undefined,
        data: hydrationGoalLiters == null
          ? undefined
          : {
              hydrationGoalLiters,
              sessionType: todaySession?.type,
              sessionDistanceKm: todaySession?.distanceKm,
            },
      },
      {
        userId,
        type: 'checklist_pre_easy_run',
        dedupeKey,
        title: 'CHECKLIST PRE-EASY RUN',
        icon: 'checklist_outlined',
        timeLabel: todaySession ? 'HOJE' : 'LIVRE',
        body: todaySession
          ? 'Aquecimento de 5-8 minutos, mobilidade leve e primeiros minutos controlados antes de entrar no ritmo previsto.'
          : 'Para corrida livre: aquecimento de 5 minutos, cadarço firme, GPS pronto e intensidade confortável.',
      },
      {
        userId,
        type: 'sono_performance',
        dedupeKey,
        title: 'SONO → PERFORMANCE',
        icon: 'bedtime_outlined',
        timeLabel: hasSleepData ? 'SINCRONIZADO' : 'SEM DADO',
        body: profile.hasWearable
          ? 'Você informou que tem ou pretende usar wearable, mas ainda não há dados reais de sono sincronizados no app.'
          : 'Sem wearable ou origem de sono conectada. Este bloco fica em estado vazio até a integração existir.',
        ctaLabel: hasSleepData ? undefined : 'REVISAR PERFIL',
        ctaRoute: hasSleepData ? undefined : '/profile/edit',
      },
      {
        userId,
        type: 'bpm_real',
        dedupeKey,
        title: 'BPM REAL',
        icon: 'monitor_heart_outlined',
        timeLabel: hasBpmData ? 'REGISTRADO' : 'SEM DADO',
        body: hasBpmData
          ? 'Há BPM registrado em corrida concluída. O coach pode usar esse dado real nas leituras de carga e zonas.'
          : 'Ainda não existe BPM real em corridas concluídas. Não vamos tratar preferência de wearable como conexão ativa.',
      },
      {
        userId,
        type: 'fechamento_mensal',
        dedupeKey,
        title: 'FECHAMENTO MENSAL',
        icon: 'medical_information_outlined',
        timeLabel: completedRuns.length === 0 ? 'SEM HISTORICO' : 'ATIVO',
        body: completedRuns.length === 0
          ? 'Quando você tiver corridas e exames cadastrados, este card destaca sinais relevantes para calibrar zonas e limites.'
          : `Com ${completedRuns.length} corrida(s) no histórico recente, revise exames ou observações para melhorar as recomendações.`,
        ctaLabel: completedRuns.length === 0 ? 'VER PERFIL' : undefined,
        ctaRoute: completedRuns.length === 0 ? '/profile' : undefined,
      },
    ];

    await Promise.all(
      inputs.map(input => {
        if (input.type === 'hidratacao') {
          // hidratacao usa upsert pra que correção de cap se autocorrige
          // sem aguardar mudança do dedupeKey (próximo dia).
          return this.notifRepo.upsertPreserveUserState({
            id: `${input.type}_${input.dedupeKey}`,
            userId: input.userId,
            type: input.type,
            title: input.title,
            body: input.body,
            icon: input.icon,
            timeLabel: input.timeLabel,
            ctaLabel: input.ctaLabel,
            ctaRoute: input.ctaRoute,
            data: input.data,
            createdAt: new Date().toISOString(),
          });
        }
        return this.create.execute(input);
      }),
    );
  }
}
