/// Label PT-BR relativo pra ranges de período (history_page).
///
/// Em vez do hardcoded "DE dd/mm/yyyy ATÉ dd/mm/yyyy", produz strings tipo
/// "ESTA SEMANA", "MÊS PASSADO", "HÁ 2 TRIMESTRES". Cursor negativo = passado;
/// 0 = corrente; positivo = futuro (raro).
///
/// O caller passa o tipo de período (`week`/`month`/`threeMonths`) e o
/// cursor — mesma fonte de verdade que o history_page já mantém. Sem locale
/// dependency (app não tem i18n ainda; doc'd no comment).
enum PeriodKind { week, month, threeMonths }

String formatRelativePeriod(PeriodKind kind, int cursor) {
  switch (kind) {
    case PeriodKind.week:
      if (cursor == 0) return 'ESTA SEMANA';
      if (cursor == -1) return 'SEMANA PASSADA';
      if (cursor < -1) {
        final n = -cursor;
        return 'HÁ $n ${n == 1 ? 'SEMANA' : 'SEMANAS'}';
      }
      // Futuro (raro, geralmente N/A na UI atual).
      final n = cursor;
      return 'EM $n ${n == 1 ? 'SEMANA' : 'SEMANAS'}';

    case PeriodKind.month:
      if (cursor == 0) return 'ESTE MÊS';
      if (cursor == -1) return 'MÊS PASSADO';
      if (cursor == -12) return 'ANO PASSADO';
      if (cursor < 0) {
        final n = -cursor;
        return 'HÁ $n ${n == 1 ? 'MÊS' : 'MESES'}';
      }
      final n = cursor;
      return 'EM $n ${n == 1 ? 'MÊS' : 'MESES'}';

    case PeriodKind.threeMonths:
      if (cursor == 0) return 'ÚLTIMOS 90 DIAS';
      if (cursor == -1) return 'TRIMESTRE PASSADO';
      if (cursor < -1) {
        final n = -cursor;
        return 'HÁ $n ${n == 1 ? 'TRIMESTRE' : 'TRIMESTRES'}';
      }
      final n = cursor;
      return 'EM $n ${n == 1 ? 'TRIMESTRE' : 'TRIMESTRES'}';
  }
}
