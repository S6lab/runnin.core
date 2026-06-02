package com.s6lab.runnin

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // Plugin custom (não vai pelo pubspec) — registra manualmente aqui.
    flutterEngine.plugins.add(WorkoutRealtimePlugin())
  }
}
