import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

MaterialApp createTestApp(Widget child) {
  return MaterialApp(
    home: child,
    theme: ThemeData(
      extensions: [
        RunninThemeTokens(palette: RunninSkin.artico.palette),
      ],
    ),
  );
}
