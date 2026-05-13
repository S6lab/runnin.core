import 'package:flutter/foundation.dart';

/// Stub — plataforma não-web sem suporte nativo a share.
/// Futuro: integrar share_plus ou platform channel.
Future<void> shareText(String text) async {
  debugPrint('Share text (stub):\n$text');
}
