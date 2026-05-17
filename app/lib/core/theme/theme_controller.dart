import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_palette.dart';

const _settingsBoxName = 'runnin_settings';
const _skinPreferenceKey = 'selected_skin';
const _textScalePreferenceKey = 'text_scale';

enum AppTextScale {
  small(0.9, 'A−'),
  normal(1.0, 'A'),
  large(1.15, 'A+');

  final double factor;
  final String label;
  const AppTextScale(this.factor, this.label);
}

final themeController = ThemeController();

class ThemeController extends ChangeNotifier {
  RunninSkin _skin = RunninSkin.artico;
  AppTextScale _textScale = AppTextScale.normal;
  Box<dynamic>? _box;

  RunninSkin get skin => _skin;
  RunninPalette get palette => _skin.palette;
  AppTextScale get textScale => _textScale;
  double get textScaleFactor => _textScale.factor;

  Future<void> load() async {
    _box = await Hive.openBox<dynamic>(_settingsBoxName);
    final savedId = _box?.get(_skinPreferenceKey) as String?;
    _skin = RunninSkin.values.firstWhere(
      (candidate) => candidate.palette.id == savedId,
      orElse: () => RunninSkin.artico,
    );
    final savedScale = _box?.get(_textScalePreferenceKey) as String?;
    _textScale = AppTextScale.values.firstWhere(
      (c) => c.name == savedScale,
      orElse: () => AppTextScale.normal,
    );
    notifyListeners();
  }

  Future<void> setSkin(RunninSkin skin) async {
    if (_skin == skin) return;
    _skin = skin;
    await _box?.put(_skinPreferenceKey, skin.palette.id);
    notifyListeners();
  }

  Future<void> setTextScale(AppTextScale scale) async {
    if (_textScale == scale) return;
    _textScale = scale;
    await _box?.put(_textScalePreferenceKey, scale.name);
    notifyListeners();
  }
}
