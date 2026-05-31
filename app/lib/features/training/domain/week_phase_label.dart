import 'package:runnin/features/training/domain/entities/plan.dart';

/// Nome/fase canônico de uma semana do plano. É a MESMA nomenclatura usada
/// em todo o app (plano base, visão mensal, detalhe) pra os títulos baterem.
///
/// Ordem de prioridade (igual ao "Plano Base"):
///   1. blockName do backend (em CAIXA ALTA)
///   2. focus/narrative → "FASE · subtítulo"
///   3. derivado das sessões → BASE/BUILD/SPECIFIC (nunca "PROGRESSÃO")
String planWeekLabel(PlanWeek week) {
  final block = week.blockName?.trim() ?? '';
  if (block.isNotEmpty) return block.toUpperCase();
  final focus = week.focus?.trim() ?? '';
  if (focus.isNotEmpty) return _phaseLabelFromFocus(focus, week.narrative);
  return _phaseFromSessions(week);
}

/// Prioriza week.focus; se vazio, tenta extrair [FASE] do narrative;
/// fallback genérico por palavras-chave.
String _phaseLabelFromFocus(String? focus, String? narrative) {
  final f = (focus ?? '').trim();
  if (f.isNotEmpty) {
    final phase = _normalizePhase(f);
    return '$phase · ${_focusSubtitle(f)}';
  }
  final n = (narrative ?? '').trim();
  final phaseTag = RegExp(r'\[([A-Z\+]+)\]').firstMatch(n);
  final phase = phaseTag?.group(1) ?? 'PROGRESSÃO';
  final firstSentence = n.split(RegExp(r'[.!]')).first.trim();
  final cleanSub = firstSentence.replaceAll(RegExp(r'\[[A-Z\+]+\]\s*'), '');
  return cleanSub.length > 50
      ? '$phase · ${cleanSub.substring(0, 50)}…'
      : (cleanSub.isEmpty ? phase : '$phase · $cleanSub');
}

/// Fase derivada das sessões da semana (fallback quando não há blockName nem
/// focus). Evita o label genérico "PROGRESSÃO".
String _phaseFromSessions(PlanWeek week) {
  final types = week.sessions.map((s) => s.type.toLowerCase()).toList();
  if (types.any((t) =>
      t.contains('interval') || t.contains('tiro') || t.contains('tempo'))) {
    return 'BUILD';
  }
  if (types.any((t) =>
      t.contains('long') || t.contains('longã') || t.contains('longao'))) {
    return 'SPECIFIC';
  }
  return 'BASE';
}

String _normalizePhase(String f) {
  final low = f.toLowerCase();
  if (low.contains('recup') || low.contains('deload')) return 'DELOAD';
  if (low.contains('taper')) return 'TAPER';
  if (low.contains('peak') || low.contains('pico')) return 'PEAK';
  if (low.contains('intervalad') || low.contains('tempo') || low.contains('build')) {
    return 'BUILD';
  }
  if (low.contains('long') || low.contains('specific')) return 'SPECIFIC';
  return 'BASE';
}

String _focusSubtitle(String f) {
  final stripped = f
      .replaceAll(RegExp(r'\[[A-Z\+]+\]\s*'), '')
      .replaceAll(
          RegExp(r'^(BUILD|PEAK|TAPER|DELOAD|BASE|SPECIFIC)\s*[·-]?\s*',
              caseSensitive: false),
          '')
      .trim();
  return stripped.isEmpty ? f : stripped;
}
