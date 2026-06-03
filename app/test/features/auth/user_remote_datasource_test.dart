import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';

void main() {
  group('UserProfile.fromJson — regression cast int/double (Firestore wire)', () {
    test('aceita frequency como int', () {
      final p = UserProfile.fromJson(_baseJson(frequency: 3));
      expect(p.frequency, 3);
    });

    test('aceita frequency como double (Firestore JS serializa Number)', () {
      final p = UserProfile.fromJson(_baseJson(frequencyRaw: 3.0));
      expect(p.frequency, 3);
    });

    test('aceita restingBpm/maxBpm como double (promotion server-side)', () {
      final j = _baseJson();
      j['restingBpm'] = 52.0;
      j['maxBpm'] = 188.0;
      final p = UserProfile.fromJson(j);
      expect(p.restingBpm, 52);
      expect(p.maxBpm, 188);
    });

    test('restingBpm/maxBpm null não estoura', () {
      final j = _baseJson();
      j['restingBpm'] = null;
      j['maxBpm'] = null;
      final p = UserProfile.fromJson(j);
      expect(p.restingBpm, null);
      expect(p.maxBpm, null);
    });
  });

  group('UserProfile.fromJson — authId/email/phone (Frente B)', () {
    test('authId vem do JSON quando presente', () {
      final j = _baseJson();
      j['authId'] = 'AUTH_123';
      final p = UserProfile.fromJson(j);
      expect(p.authId, 'AUTH_123');
    });

    test('authId cai pro id quando ausente (legado pre-fix)', () {
      final j = _baseJson();
      j.remove('authId');
      final p = UserProfile.fromJson(j);
      expect(p.authId, p.id);
    });

    test('email/phone podem ser null sem crashar', () {
      final j = _baseJson();
      j['email'] = null;
      j['phone'] = null;
      final p = UserProfile.fromJson(j);
      expect(p.email, null);
      expect(p.phone, null);
    });

    test('email/phone populados são preservados', () {
      final j = _baseJson();
      j['email'] = 'foo@bar.com';
      j['phone'] = '+5511999999999';
      final p = UserProfile.fromJson(j);
      expect(p.email, 'foo@bar.com');
      expect(p.phone, '+5511999999999');
    });
  });
}

Map<String, dynamic> _baseJson({int frequency = 3, num? frequencyRaw}) => {
      'id': 'uid_123',
      'authId': 'uid_123',
      'name': 'Test User',
      'level': 'iniciante',
      'goal': 'completar 10K',
      'frequency': frequencyRaw ?? frequency,
      'hasWearable': false,
      'medicalConditions': <String>[],
      'coachVoiceId': 'coach-bruno',
      'onboarded': true,
      'premium': false,
    };
