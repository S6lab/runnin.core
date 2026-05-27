// Modelos do registry admin — refletem schemas dos endpoints
// /admin/prompts/registry, /admin/coach-ai/moments, /admin/crons,
// /admin/users/plans-catalog, /admin/constants/plan-rules, /admin/wiring-status.

class PromptRegistryEntry {
  final String id;
  final String label;
  final String category; // 'plan' | 'live' | 'report' | 'chat' | 'exam'
  final bool deprecated;

  const PromptRegistryEntry({
    required this.id,
    required this.label,
    required this.category,
    this.deprecated = false,
  });

  factory PromptRegistryEntry.fromJson(Map<String, dynamic> j) => PromptRegistryEntry(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? (j['id'] as String),
        category: (j['category'] as String?) ?? 'report',
        deprecated: j['deprecated'] == true,
      );
}

class CoachMoment {
  final int id;
  final String title;
  final String description;
  final String model;
  final bool ragEnabled;
  final List<String> promptIds;

  const CoachMoment({
    required this.id,
    required this.title,
    required this.description,
    required this.model,
    required this.ragEnabled,
    required this.promptIds,
  });

  factory CoachMoment.fromJson(Map<String, dynamic> j) => CoachMoment(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        model: (j['model'] as String?) ?? '',
        ragEnabled: j['ragEnabled'] == true,
        promptIds: ((j['promptIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class CronEntry {
  final String name;
  final String description;
  final String schedule;
  final String humanSchedule;
  final String timezone;
  final String env; // 'staging' | 'prod'
  final String httpTarget;

  const CronEntry({
    required this.name,
    required this.description,
    required this.schedule,
    required this.humanSchedule,
    required this.timezone,
    required this.env,
    required this.httpTarget,
  });

  factory CronEntry.fromJson(Map<String, dynamic> j) => CronEntry(
        name: (j['name'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        schedule: (j['schedule'] as String?) ?? '',
        humanSchedule: (j['humanSchedule'] as String?) ?? '',
        timezone: (j['timezone'] as String?) ?? '',
        env: (j['env'] as String?) ?? 'staging',
        httpTarget: (j['httpTarget'] as String?) ?? '',
      );
}

class SubscriptionPlanOption {
  final String id;
  final String label;
  final String? operatorId;
  final bool isDefault;
  final String? description;

  const SubscriptionPlanOption({
    required this.id,
    required this.label,
    this.operatorId,
    this.isDefault = false,
    this.description,
  });

  factory SubscriptionPlanOption.fromJson(Map<String, dynamic> j) => SubscriptionPlanOption(
        id: (j['id'] as String?) ?? '',
        label: (j['label'] as String?) ?? (j['id'] as String? ?? ''),
        operatorId: j['operatorId'] as String?,
        isDefault: j['isDefault'] == true,
        description: j['description'] as String?,
      );
}

/// Snapshot read-only das constantes de regra do plano. Estrutura aninhada
/// conforme `getPlanRulesSnapshot()` no server.
class PlanRulesSnapshot {
  final Map<String, dynamic> raceWindows;
  final Map<String, dynamic> peakWeeklyKm;
  final double weeklyRampRate;
  final double rampBaseFloorKm;
  final Map<String, dynamic> minFreqByProfileDistance;
  final Map<String, dynamic> windowRestrictionByProfile;
  final Map<String, dynamic> improvePaceBypassByLevel;
  final Map<String, dynamic> maxKmPerSession;
  final List<String> seriousMedicalKeywords;
  final Map<String, dynamic> ageRestrictionThresholds;
  final Map<String, dynamic> paceImprovementCeilingPct;

  const PlanRulesSnapshot({
    required this.raceWindows,
    required this.peakWeeklyKm,
    required this.weeklyRampRate,
    required this.rampBaseFloorKm,
    required this.minFreqByProfileDistance,
    required this.windowRestrictionByProfile,
    required this.improvePaceBypassByLevel,
    required this.maxKmPerSession,
    required this.seriousMedicalKeywords,
    required this.ageRestrictionThresholds,
    required this.paceImprovementCeilingPct,
  });

  factory PlanRulesSnapshot.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> obj(String k) => (j[k] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return PlanRulesSnapshot(
      raceWindows: obj('raceWindows'),
      peakWeeklyKm: obj('peakWeeklyKm'),
      weeklyRampRate: ((j['weeklyRampRate'] as num?) ?? 0).toDouble(),
      rampBaseFloorKm: ((j['rampBaseFloorKm'] as num?) ?? 0).toDouble(),
      minFreqByProfileDistance: obj('minFreqByProfileDistance'),
      windowRestrictionByProfile: obj('windowRestrictionByProfile'),
      improvePaceBypassByLevel: obj('improvePaceBypassByLevel'),
      maxKmPerSession: obj('maxKmPerSession'),
      seriousMedicalKeywords: ((j['seriousMedicalKeywords'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      ageRestrictionThresholds: obj('ageRestrictionThresholds'),
      paceImprovementCeilingPct: obj('paceImprovementCeilingPct'),
    );
  }
}

class OverrideStatus {
  final bool hasOverride;
  final String? overrideAt;
  final String consumer;
  final String cacheKey;
  final int cacheTtlSec;

  const OverrideStatus({
    required this.hasOverride,
    required this.consumer,
    required this.cacheKey,
    required this.cacheTtlSec,
    this.overrideAt,
  });

  factory OverrideStatus.fromJson(Map<String, dynamic> j) => OverrideStatus(
        hasOverride: j['hasOverride'] == true,
        overrideAt: j['overrideAt'] as String?,
        consumer: (j['consumer'] as String?) ?? '',
        cacheKey: (j['cacheKey'] as String?) ?? '',
        cacheTtlSec: (j['cacheTtlSec'] as num?)?.toInt() ?? 60,
      );

  /// Estado visual derivado:
  ///  - 'default' quando não há override
  ///  - 'cached' quando override < cacheTtlSec
  ///  - 'active' quando override >= cacheTtlSec
  String get visualState {
    if (!hasOverride) return 'default';
    if (overrideAt == null) return 'active';
    final at = DateTime.tryParse(overrideAt!);
    if (at == null) return 'active';
    final age = DateTime.now().difference(at).inSeconds;
    return age < cacheTtlSec ? 'cached' : 'active';
  }

  /// Segundos restantes pra cache expirar (0 se já ativo / sem override).
  int get cacheCountdownSec {
    if (!hasOverride || overrideAt == null) return 0;
    final at = DateTime.tryParse(overrideAt!);
    if (at == null) return 0;
    final age = DateTime.now().difference(at).inSeconds;
    return (cacheTtlSec - age).clamp(0, cacheTtlSec);
  }
}

class WiringStatusPayload {
  final Map<String, OverrideStatus> prompts;
  final Map<String, OverrideStatus> personas;
  final Map<String, OverrideStatus> knobs;
  final OverrideStatus roteiroTemplates;

  const WiringStatusPayload({
    required this.prompts,
    required this.personas,
    required this.knobs,
    required this.roteiroTemplates,
  });

  factory WiringStatusPayload.fromJson(Map<String, dynamic> j) {
    Map<String, OverrideStatus> parseGroup(String k) {
      final obj = (j[k] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      return {
        for (final e in obj.entries)
          e.key: OverrideStatus.fromJson((e.value as Map).cast<String, dynamic>())
      };
    }

    final roteiro = (j['roteiroTemplates'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return WiringStatusPayload(
      prompts: parseGroup('prompts'),
      personas: parseGroup('personas'),
      knobs: parseGroup('knobs'),
      roteiroTemplates: OverrideStatus.fromJson(roteiro),
    );
  }
}
