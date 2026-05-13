import 'package:flutter/foundation.dart';

@immutable
class Badge {
  final String id;
  final String name;
  final String description;
  final String? unlockedAt;
  final double progress;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    this.unlockedAt,
    this.progress = 0.0,
  });

  bool get isUnlocked => unlockedAt != null;

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      unlockedAt: json['unlockedAt'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'unlockedAt': unlockedAt,
      'progress': progress,
    };
  }

  Badge copyWith({
    String? id,
    String? name,
    String? description,
    String? unlockedAt,
    double? progress,
  }) {
    return Badge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }
}
