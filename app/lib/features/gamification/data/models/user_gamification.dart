import 'package:flutter/foundation.dart';

@immutable
class UserGamification {
  final String userId;
  final int totalXp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final String? lastActivityDate;
  final String updatedAt;

  const UserGamification({
    required this.userId,
    required this.totalXp,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
    required this.updatedAt,
  });

  int get xpInCurrentLevel {
    final xpForPreviousLevels = (level - 1) * 500;
    return totalXp - xpForPreviousLevels;
  }

  int get xpRequiredForNextLevel => 500;

  int get xpToNextLevel => xpRequiredForNextLevel - xpInCurrentLevel;

  double get progressToNextLevel {
    return (xpInCurrentLevel / xpRequiredForNextLevel).clamp(0.0, 1.0);
  }

  factory UserGamification.fromJson(Map<String, dynamic> json) {
    return UserGamification(
      userId: json['userId'] as String,
      totalXp: json['totalXp'] as int,
      level: json['level'] as int,
      currentStreak: json['currentStreak'] as int,
      longestStreak: json['longestStreak'] as int,
      lastActivityDate: json['lastActivityDate'] as String?,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalXp': totalXp,
      'level': level,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActivityDate': lastActivityDate,
      'updatedAt': updatedAt,
    };
  }

  UserGamification copyWith({
    String? userId,
    int? totalXp,
    int? level,
    int? currentStreak,
    int? longestStreak,
    String? lastActivityDate,
    String? updatedAt,
  }) {
    return UserGamification(
      userId: userId ?? this.userId,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
