import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

const _boxName = 'gps_buffer';

class RunLocalDatasource {
  late Box<String> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<void> addPoint(String runId, GpsPoint point) async {
    await _box.add(jsonEncode({'runId': runId, ...point.toJson()}));
  }

  Future<List<GpsPoint>> getPoints(String runId) async {
    return _box.values
        .map((v) => jsonDecode(v) as Map<String, dynamic>)
        .where((m) => m['runId'] == runId)
        .map((m) => GpsPoint(
              lat: (m['lat'] as num).toDouble(),
              lng: (m['lng'] as num).toDouble(),
              ts: m['ts'] as int,
              accuracy: (m['accuracy'] as num).toDouble(),
              pace: (m['pace'] as num?)?.toDouble(),
              bpm: m['bpm'] as int?,
            ))
        .toList();
  }

  Future<void> clearRun(String runId) async {
    final toDelete = _box.keys
        .where((k) {
          final v = _box.get(k);
          if (v == null) return false;
          return (jsonDecode(v) as Map<String, dynamic>)['runId'] == runId;
        })
        .toList();
    await _box.deleteAll(toDelete);
  }
}
