import { UserRepository } from '@modules/users/domain/user.repository';
import { PlanRepository } from '@modules/plans/domain/plan.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { CreateNotificationInput, CreateNotificationUseCase } from './create-notification.use-case';
import { PlanSession } from '@modules/plans/domain/plan.entity';

const DAY_NAMES = ['', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'];

function todayKey(): string {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function pickCurrentWeekSessions(plan: { weeks: { sessions: PlanSession[] }[]; createdAt: string } | null): PlanSession[] {
  if (!plan || plan.weeks.length === 0) return [];
  const created = new Date(plan.createdAt);
  const days = Math.floor((Date.now() - created.getTime()) / 86_400_000);
  const idx = Math.max(0, Math.min(plan.weeks.length - 1, Math.floor(days / 7)));
  return plan.weeks[idx]?.sessions ?? [];
}

function nextSessionFromToday(sessions: PlanSession[]): PlanSession | null {
  if (sessions.length === 0) return null;
  const today = new Date().getDay() || 7; // 0=Sun → 7
  const ordered = [...sessions].sort((a, b) => a.dayOfWeek - b.dayOfWeek);
  return (
    ordered.find(s => s.dayOfWeek >= today) ?? ordered[0] ?? null
  );
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
    const sessions = pickCurrentWeekSessions(plan);
    const todayWeekday = new Date().getDay() || 7;
    const todaySession = sessions.find(s => s.dayOfWeek === todayWeekday) ?? null;
    const nextSession = todaySession ?? nextSessionFromToday(sessions);

    const hasBpmData = completedRuns.some(r => (r.avgBpm ?? 0) > 0 || (r.maxBpm ?? 0) > 0);
    const hasSleepData = false; // sem integração de sono ainda
    const weight = profile.weight ? Number(profile.weight.replace(/[^0-9.]/g, '')) : null;
    const hydrationGoalLiters = weight && weight > 0 ? +(weight * 0.035).toFixed(1) : null;

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
        timeLabel: todaySession ? 'ANTES' : 'PENDENTE',
        body: todaySession
          ? `Para ${todaySession.type}, faça uma refeição leve 45-60 minutos antes e evite exagerar em fibra ou gordura.`
          : 'Sem sessão marcada hoje. Para corrida livre, mantenha refeição leve e evite testar alimentos novos.',
      },
      {
        userId,
        type: 'hidratacao',
        dedupeKey,
        title: 'HIDRATACAO',
        icon: 'water_drop_outlined',
        timeLabel: hydrationGoalLiters == null ? 'SEM META' : 'HOJE',
        body: hydrationGoalLiters == null
          ? 'Informe seu peso para o app calcular uma meta diária de hidratação.'
          : `Meta estimada: ${hydrationGoalLiters.toFixed(1)}L hoje. Registre consumo para o coach acompanhar.`,
        ctaLabel: hydrationGoalLiters == null ? 'INFORMAR PESO' : undefined,
        ctaRoute: hydrationGoalLiters == null ? '/profile/edit' : undefined,
        data: hydrationGoalLiters == null ? undefined : { hydrationGoalLiters },
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

    await Promise.all(inputs.map(input => this.create.execute(input)));
  }
}
