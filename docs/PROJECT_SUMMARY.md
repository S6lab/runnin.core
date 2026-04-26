# runrun — Project Summary

## O que é

`runrun` é um app de corrida com coach em IA. O produto combina onboarding guiado, autenticação com Firebase, geração de plano de treino, acompanhamento de corridas, histórico, área de conta e recursos de coaching para ajudar o corredor a treinar com mais consistência.

O foco atual é fechar um MVP funcional com dados reais de ponta a ponta:
- login
- onboarding
- criação/atualização de perfil
- geração de plano
- visualização da home e do treino
- corrida com tracking

---

## Stack de tecnologia

### App
- Flutter
- `go_router` para navegação
- Dio para rede
- Hive para persistência local
- Firebase Auth para autenticação

### Backend
- Node.js
- TypeScript
- Express
- Firestore
- Firebase Admin

### Infra
- Google Cloud Run
- Firebase
- Firestore
- Secret Manager

### IA
- arquitetura desacoplada por provider
- `Gemini` como provider padrão atual
- `Groq` e `Together` mantidos como opções configuráveis para uso futuro

---

## Estado atual do projeto

### Já implementado
- backend publicado no Cloud Run
- módulos backend:
  - `users`
  - `runs`
  - `plans`
  - `coach`
- módulos app:
  - `auth`
  - `onboarding`
  - `home`
  - `training`
  - `run`
  - `history`
  - `profile`
  - `coach`
  - `dashboard`
- login anônimo no Firebase
- base para login Google
- onboarding persistido localmente
- menu `Conta`
- edição de perfil em tela dedicada
- logout
- camada de LLM refatorada para trocar provider por configuração

### Em estabilização
- fluxo real de criação de plano
- validação de perfil + onboarding + plano em produção
- UX das telas principais com dados reais
- testes reais de tracking e corrida

### Ainda faltando como módulo fechado
- gamificação
- notificações
- health / wearables
- exames / saúde avançada
- billing / premium

---

## Roadmap concluído

- estrutura monorepo com `app/` e `server/`
- backend funcional em TypeScript com Cloud Run
- autenticação com Firebase no app
- onboarding implementado
- persistência local para não reapresentar onboarding automaticamente
- home, treino, histórico, corrida, conta e perfil disponíveis no app
- refatoração da camada de IA para suportar múltiplos providers
- Gemini preparado como provider padrão configurável
- correções importantes de UX no onboarding inicial

---

## Próximos passos

### Curto prazo
- validar o fluxo real completo em produção:
  - login
  - onboarding
  - `POST /v1/users/onboarding`
  - geração de plano
  - `GET /v1/plans/current`
- revisar estados de erro e empty state
- melhorar a paridade visual com o protótipo
- validar corrida e GPS em device real

### Médio prazo
- coach pós-corrida
- chat assíncrono
- share card
- gamificação básica
- integrações com Health Connect / HealthKit

### Longo prazo
- premium / billing
- wearables completos
- saúde avançada e exames
- white-label / multi-tenant

---

## Dependências externas importantes

Para o fluxo real funcionar bem, o projeto depende de:
- Firebase Auth corretamente configurado
- Firestore acessível pelo backend
- secrets e env vars do Cloud Run corretamente configuradas
- `GEMINI_API_KEY` disponível no serviço

---

## Resumo executivo

`runrun` já deixou de ser apenas estrutura e protótipo. O projeto hoje tem app e backend publicados, autenticação, onboarding, plano, telas principais e uma arquitetura preparada para usar IA com flexibilidade. O trabalho agora é menos “construir do zero” e mais “estabilizar produção, validar dados reais e fechar os módulos que ainda faltam para retenção e monetização”.
