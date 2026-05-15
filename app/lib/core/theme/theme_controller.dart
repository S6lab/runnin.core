import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_palette.dart';

const _settingsBoxName = 'runnin_settings';
const _skinPreferenceKey = 'selected_skin';

final themeController = ThemeController();

class ThemeController extends ChangeNotifier {
  RunninSkin _skin = RunninSkin.cyber;
  Box<dynamic>? _box;

  RunninSkin get skin => _skin;
  RunninPalette get palette => _skin.palette;

  Future<void> load() async {
    _box = await Hive.openBox<dynamic>(_settingsBoxName);
    final savedId = _box?.get(_skinPreferenceKey) as String?;
    _skin = RunninSkin.values.firstWhere(
      (candidate) => candidate.palette.id == savedId,
      orElse: () => RunninSkin.cyber,
    );
    notifyListeners();
  }

  Future<void> setSkin(RunninSkin skin) async {
    if (_skin == skin) return;
    _skin = skin;
    await _box?.put(_skinPreferenceKey, skin.palette.id);
    notifyListeners();
  }
}
