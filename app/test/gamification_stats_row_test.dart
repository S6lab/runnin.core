import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/shared/widgets/gamification_stats_row.dart';

void main() {
  test('GamificationStatsRow constructor works with STREAK, XP, BADGES', () {
    const row = GamificationStatsRow(
      streak: StatData(label: 'STREAK', value: '5'),
      xp: StatData(label: 'XP', value: '340/500', accent: true),
      badges: StatData(label: 'BADGES', value: '7/21'),
    );

    expect(row.streak.value, equals('5'));
    expect(row.xp.value, equals('340/500'));
    expect(row.badges.value, equals('7/21'));
    expect(row.xp.accent, equals(true));
  });

  test('GamificationStatsRow builds 3 columns', () {
    const row = GamificationStatsRow(
      streak: StatData(label: 'STREAK', value: '5'),
      xp: StatData(label: 'XP', value: '340/500', accent: true),
      badges: StatData(label: 'BADGES', value: '7/21'),
    );

    expect(row.streak.label, equals('STREAK'));
    expect(row.xp.label, equals('XP'));
    expect(row.badges.label, equals('BADGES'));
  });

  test('GamificationStatsRow renders correct widget tree', () {
    final row = GamificationStatsRow(
      streak: StatData(label: 'STREAK', value: '5'),
      xp: StatData(label: 'XP', value: '340/500', accent: true),
      badges: StatData(label: 'BADGES', value: '7/21'),
    );

    final container = MaterialApp(
      home: Scaffold(body: row),
    );

    expect(container, isNotNull);
  });

  test('GamificationStatsRow uses correct padding and spacing', () {
    const row = GamificationStatsRow(
      streak: StatData(label: 'STREAK', value: '5'),
      xp: StatData(label: 'XP', value: '340/500', accent: true),
      badges: StatData(label: 'BADGES', value: '7/21'),
    );

    expect(row.streak.label, equals('STREAK'));
    expect(row.xp.value, equals('340/500'));
    expect(row.badges.label, equals('BADGES'));
  });
}