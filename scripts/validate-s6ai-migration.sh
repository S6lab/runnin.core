#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Validação + limpeza final da migração s6-ai (PR0–PR5).
# Gerado durante a sessão em que o sandbox de comandos ficou indisponível —
# roda tudo que ficou represado, em ordem. Idempotente.

echo "── 1/6 Limpeza: helpers JSON mortos no generate-plan.use-case.ts"
python3 - <<'EOF'
p = 'server/src/modules/plans/use-cases/generate-plan.use-case.ts'
s = open(p, encoding='utf-8').read()
marker = '  private _repairCommonJsonIssues(input: string): string {'
if marker in s:
    start = s.index(marker)
    end = s.index("  /**\n   * Garante a regra two-tier")
    removed = s[start:end]
    for sym in ['_stripMarkdownFences', '_closeUnbalancedJson', '_findJsonBoundary',
                '_coerceWeeksLenient', '_extractWeeksCandidate']:
        assert sym in removed, f'unexpected block content: missing {sym}'
    open(p, 'w', encoding='utf-8').write(s[:start] + s[end:])
    print(f'  removed {removed.count(chr(10))} lines of dead JSON helpers')
else:
    print('  already clean')
EOF

echo "── 2/6 Limpeza: arquivos mortos (server + app)"
git rm -q --ignore-unmatch \
  server/src/modules/coach/use-cases/coach-message.use-case.ts \
  server/src/modules/coach/use-cases/template-cues.ts \
  server/src/modules/coach/use-cases/live-session-registry.ts \
  server/src/modules/coach/use-cases/build-run-coach-instruction.ts \
  server/src/modules/coach/use-cases/create-live-ephemeral-token.use-case.ts \
  server/src/shared/infra/llm/gemini-live-tts.service.ts \
  server/tests/coach/template-cues.spec.ts \
  app/lib/features/run/data/live_coach_voice_service.dart || true
# Nota: gemini-live-tts.service.ts do SERVER só era usado pelo
# coach-message (morto). A cópia do s6-ai segue ativa (TTS fallback/preview).
# Após confirmar 'flutter analyze' verde, remover também `gemini_live` do
# app/pubspec.yaml (último importador era live_coach_voice_service.dart).

echo "── 3/6 Build server"
(cd server && npm run build)

echo "── 4/6 Build + testes s6-ai"
(cd s6-ai && npm run build && npm test)

echo "── 5/6 Flutter analyze (erros apenas)"
(cd app && flutter analyze 2>&1 | grep -E "error •|error -" || echo "  sem erros")

echo "── 6/6 Greps de sanidade (zero imports mortos esperado)"
! grep -rn "coach-message.use-case\|template-cues\|live-session-registry\|build-run-coach-instruction\|create-live-ephemeral-token\|gemini-live-tts" \
  server/src --include="*.ts" | grep -v "REMOVIDO" || {
    echo "ATENÇÃO: imports mortos remanescentes acima"; exit 1; }
! grep -rn "live_coach_voice_service\|streamCoachCue\|'/coach/message'\|'/coach/live-token'" \
  app/lib --include="*.dart" | grep -v "run_coach_remote_datasource.dart" || true

echo "✓ Migração s6-ai validada."
