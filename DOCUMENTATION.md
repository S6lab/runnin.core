# runnin.core — Documentação do Projeto

> Documentação técnica e jornadas do usuário

---

## Sumário

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Stack Tecnológica](#stack-tecnológica)
4. [Estrutura de Pastas](#estrutura-de-pastas)
5. [Configuração e Instalação](#configuração-e-instalação)
6. [Módulos Principais](#módulos-principais)
7. [Jornadas do Usuário](#jornadas-do-usuário)
8. [API & Contratos de Dados](#api--contratos-de-dados)
9. [Convenções e Boas Práticas](#convenções-e-boas-práticas)
10. [Contribuição](#contribuição)
11. [Roadmap](#roadmap)

---

## Visão Geral

**runnin.core** é o núcleo da plataforma *Runnin* — uma aplicação voltada ao acompanhamento, gamificação e comunidade de corredores. Este repositório contém a lógica de negócio central, modelos de domínio, serviços e contratos de dados que alimentam os clientes (mobile, web) e a infraestrutura de back-end.

### Objetivos do projeto

| Objetivo | Descrição |
|---|---|
| **Rastreamento** | Registrar e analisar corridas com métricas de desempenho (pace, distância, elevação, frequência cardíaca) |
| **Progresso** | Exibir evolução do atleta ao longo do tempo com histórico, metas e tendências |
| **Gamificação** | Recompensar conquistas, sequências e desafios entre usuários |
| **Comunidade** | Conectar corredores através de rotas compartilhadas, grupos e eventos |
| **Saúde** | Integrar dados biométricos e fornecer recomendações de treino personalizadas |

---

## Arquitetura

O projeto segue uma arquitetura modular orientada ao domínio (*Domain-Driven Design* — DDD), separando claramente as camadas de domínio, aplicação, infraestrutura e interface.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Clientes (UI)                            │
│              Mobile (iOS/Android)  │  Web App                   │
└────────────────────┬───────────────┴────────────────────────────┘
                     │ REST / GraphQL / WebSocket
┌────────────────────▼───────────────────────────────────────────┐
│                     runnin.core (este repo)                     │
│                                                                  │
│  ┌───────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Application  │  │   Domain     │  │   Infrastructure     │  │
│  │  (Use Cases)  │  │  (Entities,  │  │  (DB, Queue, Cache,  │  │
│  │               │  │   Services,  │  │   External APIs,     │  │
│  │               │  │   Events)    │  │   Integrations)      │  │
│  └───────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                     │
┌────────────────────▼───────────────────────────────────────────┐
│              Serviços Externos & Dados                          │
│   GPS / Wearables  │  Maps API  │  Banco de Dados  │  Storage   │
└─────────────────────────────────────────────────────────────────┘
```

### Princípios de Design

- **Separação de responsabilidades**: cada módulo tem uma única responsabilidade bem definida
- **Imutabilidade**: entidades de domínio são tratadas como valores imutáveis onde possível
- **Testabilidade**: toda a lógica de negócio é independente de frameworks e facilmente testável
- **Extensibilidade**: novos módulos podem ser adicionados sem alteração dos existentes

---

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Linguagem | TypeScript |
| Runtime | Node.js (≥ 18 LTS) |
| Framework API | (a definir: NestJS / Fastify / Express) |
| Banco de Dados Principal | PostgreSQL |
| Cache | Redis |
| Message Queue | (a definir: BullMQ / RabbitMQ) |
| ORM | Prisma / TypeORM |
| Testes | Jest + Supertest |
| CI/CD | GitHub Actions |
| Monitoramento | (a definir: Datadog / Sentry) |
| Containerização | Docker + Docker Compose |

---

## Estrutura de Pastas

```
runnin.core/
├── src/
│   ├── domain/                  # Entidades, Value Objects, eventos de domínio
│   │   ├── user/
│   │   ├── run/
│   │   ├── challenge/
│   │   ├── achievement/
│   │   └── social/
│   ├── application/             # Casos de uso, comandos e queries
│   │   ├── user/
│   │   ├── run/
│   │   ├── challenge/
│   │   └── analytics/
│   ├── infrastructure/          # Repositórios, adaptadores, integrações
│   │   ├── database/
│   │   ├── cache/
│   │   ├── queue/
│   │   └── external/
│   ├── interfaces/              # Controllers, resolvers, DTOs
│   │   ├── http/
│   │   └── events/
│   └── shared/                  # Utilitários, helpers, tipos compartilhados
│       ├── errors/
│       ├── events/
│       └── utils/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── prisma/ (ou migrations/)
├── docs/
├── docker-compose.yml
├── package.json
├── tsconfig.json
└── DOCUMENTATION.md
```

---

## Configuração e Instalação

### Pré-requisitos

- Node.js ≥ 18 LTS
- npm ≥ 9 ou yarn ≥ 1.22
- Docker e Docker Compose
- PostgreSQL 15+ (via Docker ou local)
- Redis 7+ (via Docker ou local)

### Instalação rápida

```bash
# 1. Clone o repositório
git clone https://github.com/S6lab/runnin.core.git
cd runnin.core

# 2. Instale as dependências
npm install

# 3. Configure as variáveis de ambiente
cp .env.example .env
# edite o .env com suas configurações locais

# 4. Suba a infraestrutura local com Docker
docker-compose up -d

# 5. Execute as migrations
npm run db:migrate

# 6. (Opcional) Popule o banco com dados de seed
npm run db:seed

# 7. Inicie o servidor em modo desenvolvimento
npm run dev
```

### Variáveis de Ambiente

```dotenv
# Aplicação
NODE_ENV=development
PORT=3000
APP_SECRET=seu_secret_aqui

# Banco de dados
DATABASE_URL=postgresql://runnin:runnin@localhost:5432/runnin_core

# Cache
REDIS_URL=redis://localhost:6379

# Autenticação
JWT_SECRET=seu_jwt_secret
JWT_EXPIRES_IN=7d

# Integrações externas (opcionais)
GOOGLE_MAPS_API_KEY=
STRAVA_CLIENT_ID=
STRAVA_CLIENT_SECRET=
APPLE_HEALTH_KEY=
```

### Scripts disponíveis

```bash
npm run dev          # Servidor de desenvolvimento com hot-reload
npm run build        # Build de produção
npm run start        # Inicia o build de produção
npm run test         # Executa todos os testes
npm run test:unit    # Apenas testes unitários
npm run test:e2e     # Testes end-to-end
npm run lint         # Verificação de lint
npm run format       # Formata o código com Prettier
npm run db:migrate   # Aplica migrations pendentes
npm run db:seed      # Popula o banco com dados de teste
```

---

## Módulos Principais

### 📍 Módulo de Corrida (`run`)

Responsável por registrar, processar e analisar sessões de corrida.

**Entidades:**
- `Run` — sessão de corrida com GPS, pace, distância, duração e elevação
- `RunSegment` — trecho de uma corrida (intervalos, splits)
- `Route` — rota reutilizável com metadados geográficos

**Casos de uso:**
- Iniciar corrida
- Pausar / retomar corrida
- Finalizar e salvar corrida
- Compartilhar corrida
- Excluir corrida

---

### 👤 Módulo de Usuário (`user`)

Gerencia identidade, perfil, autenticação e preferências do atleta.

**Entidades:**
- `User` — dados de identidade e perfil
- `AthleteProfile` — métricas biométricas, metas e nível de condicionamento
- `Preferences` — configurações de notificação, privacidade e exibição

**Casos de uso:**
- Cadastrar usuário
- Autenticar (login/logout)
- Atualizar perfil
- Definir metas
- Conectar wearables

---

### 🏆 Módulo de Conquistas (`achievement`)

Sistema de gamificação que recompensa marcos e comportamentos.

**Entidades:**
- `Achievement` — definição de uma conquista (critério, ícone, XP)
- `UserAchievement` — instância desbloqueada por um usuário
- `Badge` — representação visual de conquista

**Casos de uso:**
- Verificar e desbloquear conquistas após cada corrida
- Listar conquistas do usuário
- Compartilhar conquista

---

### 🎯 Módulo de Desafios (`challenge`)

Desafios individuais e coletivos com prazo e metas mensuráveis.

**Entidades:**
- `Challenge` — definição com meta, prazo e tipo (distância, calorias, frequência)
- `ChallengeParticipant` — usuário inscrito com progresso atual
- `Leaderboard` — ranking de participantes

**Casos de uso:**
- Criar desafio
- Ingressar em desafio
- Atualizar progresso
- Encerrar e distribuir recompensas

---

### 👥 Módulo Social (`social`)

Conexões entre corredores, grupos e feed de atividades.

**Entidades:**
- `Follow` — relação de seguidor/seguido
- `Group` — grupo de corrida (clube, empresa, amigos)
- `Activity` — item do feed (corrida, conquista, desafio)
- `Reaction` — curtida ou comentário em uma atividade

**Casos de uso:**
- Seguir/deixar de seguir usuário
- Criar e entrar em grupos
- Visualizar feed personalizado
- Reagir a atividades

---

## Jornadas do Usuário

As jornadas a seguir descrevem os fluxos principais da plataforma da perspectiva do usuário final.

---

### Jornada 1 — Onboarding (Primeiro Acesso)

**Objetivo:** Novo usuário cria conta e configura seu perfil de atleta.

```
[Usuário] → Abre o app pela primeira vez
     │
     ▼
[Tela de Boas-vindas] — apresentação do produto
     │
     ▼
[Cadastro]
  ├─ via e-mail + senha
  ├─ via Google
  └─ via Apple ID
     │
     ▼
[Verificação de e-mail] (quando aplicável)
     │
     ▼
[Configuração do Perfil]
  ├─ Nome e foto
  ├─ Data de nascimento e gênero
  └─ Nível de condicionamento (iniciante / intermediário / avançado)
     │
     ▼
[Definição de Metas]
  ├─ Distância semanal alvo
  ├─ Meta de pace
  └─ Objetivo (emagrecer / performance / saúde / social)
     │
     ▼
[Permissões]
  ├─ GPS / Localização
  ├─ Notificações Push
  └─ Saúde / HealthKit / Google Fit (opcional)
     │
     ▼
[Sugestão de seguir amigos / importar contatos] (opcional)
     │
     ▼
[Dashboard principal] ✅
```

**Pontos de atenção:**
- Onboarding deve ser concluído em menos de 3 minutos
- Todos os passos de configuração (exceto cadastro) são puláveis
- Dados de onboarding alimentam o algoritmo de recomendação de treinos

---

### Jornada 2 — Registrar uma Corrida

**Objetivo:** Atleta registra uma sessão de corrida ao ar livre ou em esteira.

```
[Usuário] → Toca em "Iniciar Corrida"
     │
     ▼
[Seleção de modo]
  ├─ Corrida livre (GPS)
  ├─ Corrida em esteira (manual)
  └─ Treino guiado (plano de treino)
     │
     ▼
[Aguardando sinal GPS] (modo livre)
     │
     ▼
[Corrida em andamento]
  ├─ Métricas em tempo real (pace, distância, tempo, frequência cardíaca)
  ├─ Alerts de pace por km
  ├─ Áudio feedback (pace, distância, conquistas)
  └─ Pausar / Retomar
     │
     ▼
[Finalizar corrida] — confirmação
     │
     ▼
[Resumo da Corrida]
  ├─ Distância total, pace médio, tempo, calorias
  ├─ Mapa do trajeto
  ├─ Splits por km
  ├─ Conquistas desbloqueadas 🏅
  └─ Progresso em desafios ativos
     │
     ▼
[Salvar corrida]
  ├─ Adicionar título / nota / foto
  └─ Compartilhar no feed ou redes sociais (opcional)
     │
     ▼
[Feed atualizado com nova atividade] ✅
```

**Pontos de atenção:**
- GPS deve ser adquirido em menos de 10 segundos em condições normais
- Corrida deve continuar em background com tela bloqueada
- Dados são sincronizados automaticamente ao conectar à internet (modo offline)

---

### Jornada 3 — Acompanhar Progresso

**Objetivo:** Atleta analisa sua evolução ao longo do tempo.

```
[Usuário] → Acessa aba "Estatísticas" / "Progresso"
     │
     ▼
[Visão Geral]
  ├─ Distância acumulada (semana / mês / ano)
  ├─ Pace médio recente
  ├─ Frequência de corridas
  └─ Sequência atual (streak) 🔥
     │
     ▼
[Histórico de Corridas]
  ├─ Lista paginada com filtros (período, distância, tipo)
  └─ Toque em corrida → detalhes completos
     │
     ▼
[Gráficos e Tendências]
  ├─ Evolução de pace ao longo do tempo
  ├─ Volume semanal (barras)
  └─ Comparação período anterior
     │
     ▼
[Metas]
  ├─ Progresso visual em relação às metas definidas
  ├─ Previsão de atingimento
  └─ Ajustar meta
     │
     ▼
[Recordes Pessoais (PRs)]
  └─ 1 km, 5 km, 10 km, 21 km, 42 km ✅
```

---

### Jornada 4 — Participar de um Desafio

**Objetivo:** Atleta ingressa e completa um desafio coletivo.

```
[Usuário] → Acessa aba "Desafios"
     │
     ▼
[Lista de Desafios]
  ├─ Desafios públicos em destaque
  ├─ Desafios dos grupos que participa
  └─ Desafios criados por amigos
     │
     ▼
[Detalhe do Desafio]
  ├─ Objetivo (ex: correr 100 km em maio)
  ├─ Prazo e participantes
  ├─ Ranking atual
  └─ Recompensa ao completar
     │
     ▼
[Ingressar no Desafio] → confirmação
     │
     ▼
[Durante o desafio — cada corrida contribui automaticamente]
  └─ Notificação de progresso ao atingir marcos (25%, 50%, 75%, 100%)
     │
     ▼
[Conclusão]
  ├─ Notificação de meta atingida 🎉
  ├─ Badge desbloqueado
  └─ Posição final no ranking ✅
```

---

### Jornada 5 — Interação Social

**Objetivo:** Atleta interage com a comunidade de corredores.

```
[Usuário] → Acessa aba "Feed" / "Comunidade"
     │
     ▼
[Feed Personalizado]
  ├─ Atividades de quem segue
  ├─ Conquistas de amigos
  └─ Destaques de desafios
     │
  ┌──┴───────────────────────────────┐
  ▼                                  ▼
[Reagir a atividade]          [Buscar corredores]
  ├─ Curtir 👍                  ├─ Por nome
  └─ Comentar 💬                └─ Por localização / grupo
                                       │
                                       ▼
                               [Ver perfil público]
                                 ├─ Seguir usuário
                                 └─ Ver rotas públicas
     │
     ▼
[Grupos]
  ├─ Descobrir grupos por interesse
  ├─ Criar grupo (clube, empresa, amigos)
  └─ Participar de corrida em grupo (evento) ✅
```

---

### Jornada 6 — Conectar Wearable / App de Saúde

**Objetivo:** Atleta integra dados de dispositivo externo (smartwatch, sensor de frequência cardíaca).

```
[Usuário] → Configurações → Integrações
     │
     ▼
[Lista de integrações disponíveis]
  ├─ Apple Health / HealthKit
  ├─ Google Fit
  ├─ Garmin Connect
  ├─ Strava
  └─ Polar / Suunto
     │
     ▼
[Autorizar integração] → OAuth / permissões do SO
     │
     ▼
[Sincronização inicial]
  └─ Importar histórico (últimos 90 dias)
     │
     ▼
[Sincronização automática ativada]
  └─ Novos dados importados ao abrir o app ✅
```

---

## API & Contratos de Dados

### Autenticação

Todas as rotas protegidas exigem o header:

```
Authorization: Bearer <JWT_TOKEN>
```

### Endpoints principais

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/auth/register` | Criar conta |
| `POST` | `/auth/login` | Autenticar |
| `POST` | `/auth/refresh` | Renovar token |
| `GET` | `/users/me` | Perfil autenticado |
| `PUT` | `/users/me` | Atualizar perfil |
| `POST` | `/runs` | Criar corrida |
| `GET` | `/runs` | Listar corridas do usuário |
| `GET` | `/runs/:id` | Detalhe de corrida |
| `DELETE` | `/runs/:id` | Excluir corrida |
| `GET` | `/achievements` | Listar conquistas disponíveis |
| `GET` | `/users/me/achievements` | Conquistas desbloqueadas |
| `GET` | `/challenges` | Listar desafios |
| `POST` | `/challenges/:id/join` | Ingressar em desafio |
| `GET` | `/feed` | Feed de atividades |
| `POST` | `/users/:id/follow` | Seguir usuário |

### Exemplo — Payload de criação de corrida

```json
{
  "startedAt": "2025-05-19T06:30:00Z",
  "finishedAt": "2025-05-19T07:15:00Z",
  "distanceMeters": 8200,
  "durationSeconds": 2700,
  "pacePerKmSeconds": 329,
  "caloriesBurned": 520,
  "elevationGainMeters": 45,
  "averageHeartRate": 158,
  "mode": "outdoor",
  "gpsTrack": [
    { "lat": -23.5505, "lng": -46.6333, "altitude": 760, "timestamp": "2025-05-19T06:30:00Z" }
  ],
  "title": "Corrida matinal no parque",
  "notes": "Ótima sessão, bom ritmo nos últimos 3km"
}
```

---

## Convenções e Boas Práticas

### Commits

Seguimos o padrão **Conventional Commits**:

```
feat: adiciona módulo de desafios
fix: corrige cálculo de pace em corridas de esteira
docs: atualiza documentação da API
refactor: reorganiza estrutura de pastas do domínio
test: adiciona testes unitários para AchievementService
chore: atualiza dependências
```

### Branches

```
main          → produção (protegida)
develop       → integração
feat/xxx      → novas funcionalidades
fix/xxx       → correções de bugs
docs/xxx      → documentação
refactor/xxx  → refatorações
```

### Revisão de Código

- Todo PR deve ter pelo menos 1 aprovação antes de mergear
- PRs devem ser pequenos e focados (< 400 linhas de diferença quando possível)
- Testes são obrigatórios para novos casos de uso
- Cobertura mínima: **80%** em `domain/` e `application/`

### Nomenclatura

- **Classes/Tipos:** `PascalCase` (ex: `RunService`, `UserRepository`)
- **Funções/Variáveis:** `camelCase` (ex: `startRun`, `totalDistance`)
- **Constantes:** `UPPER_SNAKE_CASE` (ex: `MAX_PACE_PER_KM`)
- **Arquivos:** `kebab-case` (ex: `run-service.ts`, `user-repository.ts`)
- **Banco de dados:** `snake_case` (ex: `user_id`, `started_at`)

---

## Contribuição

1. Faça um fork do repositório
2. Crie uma branch a partir de `develop`: `git checkout -b feat/minha-feature`
3. Escreva código e testes
4. Certifique-se que todos os testes passam: `npm test`
5. Abra um Pull Request descrevendo as alterações
6. Aguarde revisão e aprovação

Para dúvidas, abra uma [issue](https://github.com/S6lab/runnin.core/issues) ou entre em contato com a equipe da S6lab.

---

## Roadmap

| Fase | Funcionalidades | Status |
|---|---|---|
| **MVP** | Autenticação, registro de corrida, histórico, perfil básico | 🚧 Em andamento |
| **v1.0** | Conquistas, metas, estatísticas avançadas, feed social | 📋 Planejado |
| **v1.5** | Desafios, grupos, ranking, integração wearables | 📋 Planejado |
| **v2.0** | Planos de treino personalizados, coach IA, eventos ao vivo | 🔭 Futuro |

---

*Documentação mantida pela equipe S6lab. Última atualização: maio de 2026.*
