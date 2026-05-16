/// Single source of truth for level definitions across HOME (XP card), PERFIL
/// (header), GAMIFICAÇÃO (XP tab), Report (post-run "Nível: Corredor (340/500)").
///
/// XP credit comes from server (`complete-run.use-case.ts`): `distancia*10 +
/// minutos*0.5`. Bonus XP for new badges and pace target hits are promised in
/// the GAMIFICAÇÃO XP table but not yet implemented server-side (gap E5).
class LevelDefinition {
  final int xpThreshold;
  final String name;
  const LevelDefinition({required this.xpThreshold, required this.name});
}

const kLevelDefinitions = <LevelDefinition>[
  LevelDefinition(xpThreshold: 0, name: 'Iniciante'),
  LevelDefinition(xpThreshold: 200, name: 'Aprendiz'),
  LevelDefinition(xpThreshold: 500, name: 'Corredor'),
  LevelDefinition(xpThreshold: 1000, name: 'Atleta'),
  LevelDefinition(xpThreshold: 2000, name: 'Veterano'),
  LevelDefinition(xpThreshold: 4000, name: 'Mestre'),
  LevelDefinition(xpThreshold: 8000, name: 'Lenda'),
];

class LevelProgress {
  final int currentLevel;     // 1-based (1 = Iniciante)
  final String currentName;
  final int xpIntoLevel;      // xp accumulated within current level
  final int xpForNextLevel;   // xp needed to complete current level
  final bool isMax;

  const LevelProgress({
    required this.currentLevel,
    required this.currentName,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.isMax,
  });

  double get fraction =>
      xpForNextLevel == 0 ? 1.0 : (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0);
}

LevelProgress computeLevel(int totalXp) {
  if (totalXp < 0) totalXp = 0;
  for (int i = kLevelDefinitions.length - 1; i >= 0; i--) {
    final def = kLevelDefinitions[i];
    if (totalXp >= def.xpThreshold) {
      final next = i + 1 < kLevelDefinitions.length ? kLevelDefinitions[i + 1] : null;
      if (next == null) {
        return LevelProgress(
          currentLevel: i + 1,
          currentName: def.name,
          xpIntoLevel: 0,
          xpForNextLevel: 0,
          isMax: true,
        );
      }
      return LevelProgress(
        currentLevel: i + 1,
        currentName: def.name,
        xpIntoLevel: totalXp - def.xpThreshold,
        xpForNextLevel: next.xpThreshold - def.xpThreshold,
        isMax: false,
      );
    }
  }
  return const LevelProgress(
    currentLevel: 1,
    currentName: 'Iniciante',
    xpIntoLevel: 0,
    xpForNextLevel: 200,
    isMax: false,
  );
}
