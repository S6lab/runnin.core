# PERFIL > AJUSTES — Addendum de spec

> Decisão de produto para 3 sub-telas que **não estão no Figma** mas precisam existir
> para zerar o backlog de "em breve" no menu PERFIL. Mantém o design system existente
> (`FigmaColors`, `FigmaBorderRadius.zero`, border `1.735`, JetBrains Mono).

## Padrão comum a todas as 3 sub-telas

- **TopNav**: `FigmaTopNav(breadcrumb: 'Perfil / Ajustes / <Sub>', showBackButton: true)`.
- **Background**: `FigmaColors.bgBase`.
- **Padding**: 20px horizontal, 24px top.
- **Section heading**: `SectionHeading` widget já existente. Label uppercase em cyan.
- **Persistência**: usar `Hive` local para preferências client-side; PATCH `/users/me`
  para preferências que afetam recomendações do coach.
- **Estados loading/error**: usar `CircularProgressIndicator` + `FigmaColors.brandOrange`
  para erros — padrão da app.

---

## 1. AJUSTES > COACH (`/profile/settings/coach`)

**Por quê:** o usuário precisa configurar como o Coach.AI fala com ele (tom, intensidade,
voz TTS, frequência de mensagens). Os campos já existem parcialmente no profile (`coachVoiceId`).

### Seções

#### 1.1 Personalidade do Coach
`FigmaSelectionButton` × 3 opções (mutually exclusive):
- **Motivador** (default) — "Vamos lá! Você consegue."
- **Técnico** — "Pace 5:30/km, BPM 165, zona 3."
- **Sereno** — "Respire fundo, mantenha o ritmo."

Campo: `coachPersonality` (string, novo no profile, default `'motivador'`).

#### 1.2 Voz do Coach
`FigmaSelectionButton` × 3 opções (preview de áudio ao tap):
- **Bruno** (voz masculina pt-BR)
- **Clara** (voz feminina pt-BR)
- **Luna** (voz neutra ElevenLabs)

Campo: `coachVoiceId` (já existe; valores: `'bruno' | 'clara' | 'luna'`).
Preview tap → POST `/coach/message` com `event: 'preview'` e tocar `audioBase64`.

#### 1.3 Frequência de mensagens durante corrida
`FigmaSelectionButton` × 4 opções:
- **A cada km** (default)
- **A cada 2km**
- **Só em alertas (pace/BPM)**
- **Silencioso**

Campo: `coachMessageFrequency` (novo; default `'per_km'`).

#### 1.4 Tipos de feedback ativos (toggles)
Cada um é um `FigmaSelectionButton` em modo toggle (selected/unselected). Multi-select.
- **Análise pré-treino** (default ON)
- **Alertas de pace** (default ON)
- **Alertas de BPM** (default ON)
- **Splits ao vivo** (default ON)
- **Relatório pós-treino** (default ON)
- **Notificações diárias** (default ON)

Persistir em `coachFeedbackEnabled` (map<string,bool>).

### Critério done
- Botão "SALVAR" inferior (PrimaryButton style) faz PATCH `/users/me` com todos os campos
- Toast de sucesso/erro
- Voltar com `<` no TopNav volta para `/profile`

---

## 2. AJUSTES > ALERTAS (`/profile/settings/notifications`)

**Por quê:** controlar quais notificações o servidor envia (push, in-app, email).
Hoje todas as 7 notifs diárias chegam — usuário precisa filtrar.

### Seções

#### 2.1 Canais ativos
Toggles (FigmaSelectionButton):
- **Push notifications** (default ON)
- **In-app banner** (default ON)
- **Email** (default OFF) — futuro, deixa cinza com "em breve" se não houver wiring

#### 2.2 Tipos de notificação diária
Lista vertical com 1 toggle por tipo (os 7 atuais de `ensure-daily-insights.use-case.ts`):
- Melhor horário para correr
- Preparo nutricional
- Hidratação
- Checklist pré-easy run
- Sono → performance
- BPM real
- Fechamento mensal

Persistir em `notificationsEnabled` (map<string,bool>, default tudo true).

#### 2.3 Janela de silêncio (Do Not Disturb)
2 `FigmaFormTextField` (TimeOfDay picker on tap):
- **Início**: default 22:00
- **Fim**: default 06:30

Campo: `dndWindow: { start: '22:00', end: '06:30' }` (novo).

### Critério done
- PATCH `/users/me` com `notificationPreferences` (objeto novo)
- Server respeita `notificationsEnabled[type]` ao gerar notifs (acrescentar filtro em `ensure-daily-insights.use-case.ts`)
- Sem janela DND wiring server-side ainda (só persiste cliente)

---

## 3. AJUSTES > UNIDADES (`/profile/settings/units`)

**Por quê:** suporte a métrico/imperial. Hoje tudo é hardcoded métrico.

### Seções

#### 3.1 Sistema de unidades
`FigmaSelectionButton` × 2 (radio):
- **Métrico** — km, kg, cm, °C (default)
- **Imperial** — mi, lb, ft, °F

Campo: `unitsSystem` (`'metric' | 'imperial'`, novo, default `'metric'`).

Aplicação no app: criar helper `lib/core/units/units.dart` com `formatDistance(m)`,
`formatWeight(kg)`, `formatHeight(cm)`, `formatPace(secsPerKm)` que respeitam o setting.

#### 3.2 Formato de pace
`FigmaSelectionButton` × 2 (radio):
- **min/km** (default no metric, hidden no imperial)
- **min/mi** (default no imperial, hidden no metric)

Campo: `paceFormat` (`'min_per_km' | 'min_per_mi'`).

#### 3.3 Formato de horário
`FigmaSelectionButton` × 2 (radio):
- **24h** (default)
- **12h AM/PM**

Campo: `timeFormat` (`'24h' | '12h'`).

### Critério done
- PATCH `/users/me` com `unitsSystem`, `paceFormat`, `timeFormat`
- Criar helper `units.dart` e aplicar em pelo menos 1 lugar visível (HOME stats ou history) como prova de conceito
- Cobertura completa de conversões cross-app fica fora desta issue (separar)

---

## Estrutura de arquivos

```
app/lib/features/profile/presentation/pages/settings/
  ├── coach_settings_page.dart           (1)
  ├── notifications_settings_page.dart   (2)
  └── units_settings_page.dart           (3)
```

Rotas a adicionar em `app/lib/core/router/app_router.dart`:
```dart
GoRoute(path: '/profile/settings/coach',         builder: (_, _) => const CoachSettingsPage()),
GoRoute(path: '/profile/settings/notifications', builder: (_, _) => const NotificationsSettingsPage()),
GoRoute(path: '/profile/settings/units',         builder: (_, _) => const UnitsSettingsPage()),
```

Menu PERFIL (`account_page.dart`): substituir o `_showComingSoon('Ajustes…')` por
sub-menu com 3 entradas (Coach / Alertas / Unidades) OU manter um único item AJUSTES
que abre uma página índice com as 3 opções. **Recomendado**: página índice
`/profile/settings` que lista os 3 cards.

## Backend new fields (alteração em `users` collection)

```ts
// server/src/modules/users/domain/user.entity.ts — adicionar:
coachPersonality?: 'motivador' | 'tecnico' | 'sereno';
coachMessageFrequency?: 'per_km' | 'per_2km' | 'alerts_only' | 'silent';
coachFeedbackEnabled?: Record<string, boolean>;
notificationsEnabled?: Record<string, boolean>;
dndWindow?: { start: string; end: string };
unitsSystem?: 'metric' | 'imperial';
paceFormat?: 'min_per_km' | 'min_per_mi';
timeFormat?: '24h' | '12h';
```

PATCH `/users/me` já aceita arbitrary fields (verificar `update-profile.use-case.ts`).
Se não, adicionar passthrough para esses campos novos.
