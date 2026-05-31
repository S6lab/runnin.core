import { CloudTasksClient } from '@google-cloud/tasks';

/**
 * Dispatcher de tarefas do fan-out da revisão semanal. O cron de domingo
 * enfileira 1 task por usuário (rápido) e cada task chama o endpoint-worker
 * que processa UM usuário (1 chamada de LLM) — bem dentro do timeout do
 * Cloud Run. Evita o 504 do processamento síncrono de todos os usuários.
 *
 * Config por env (setadas no Cloud Run via .env):
 *   TASKS_LOCATION   ex: southamerica-east1
 *   TASKS_QUEUE      ex: weekly-proposals
 *   TASKS_WORKER_URL url completa do endpoint-worker
 *   X_CRON_TOKEN     token enviado no header da task (autentica o worker)
 *   FIREBASE_PROJECT_ID (fallback runnin-494520)
 *
 * Se não estiver configurado, `enabled=false` e o cron cai no modo inline
 * (fallback pra dev local).
 */
export interface ProposalTaskPayload {
  userId: string;
}

export interface ProposalTaskDispatcher {
  readonly enabled: boolean;
  enqueue(payload: ProposalTaskPayload): Promise<void>;
}

export class CloudTasksProposalDispatcher implements ProposalTaskDispatcher {
  private client?: CloudTasksClient;
  private readonly project: string;
  private readonly location: string;
  private readonly queue: string;
  private readonly workerUrl: string;
  private readonly token: string;

  constructor() {
    this.project = process.env.FIREBASE_PROJECT_ID ?? 'runnin-494520';
    this.location = process.env.TASKS_LOCATION ?? '';
    this.queue = process.env.TASKS_QUEUE ?? '';
    this.workerUrl = process.env.TASKS_WORKER_URL ?? '';
    this.token = process.env.X_CRON_TOKEN ?? '';
  }

  get enabled(): boolean {
    return Boolean(this.location && this.queue && this.workerUrl && this.token);
  }

  async enqueue(payload: ProposalTaskPayload): Promise<void> {
    if (!this.enabled) throw new Error('cloud_tasks_not_configured');
    this.client ??= new CloudTasksClient();
    const parent = this.client.queuePath(this.project, this.location, this.queue);
    await this.client.createTask({
      parent,
      task: {
        httpRequest: {
          httpMethod: 'POST',
          url: this.workerUrl,
          headers: {
            'Content-Type': 'application/json',
            'X-Cron-Token': this.token,
          },
          body: Buffer.from(JSON.stringify(payload)),
        },
      },
    });
  }
}
