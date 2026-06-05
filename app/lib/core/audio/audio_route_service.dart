// AudioDeviceType marcado como `experimental` no audio_session 0.1.x, mas
// é estável na prática e a única forma de classificar a saída. Aceitamos
// o risco (se a API mudar, breakage compila-time).
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'package:runnin/core/logger/logger.dart';

/// Detecta se há saída de áudio externa (fones, AirPods, BT speaker)
/// conectada ao device. Alimenta o indicador "AUDIO" do header da Home —
/// antes era `isOn: false` hardcoded e nunca refletia a realidade.
///
/// Estratégia: lê `AudioSession.instance.devicesStream` (iOS:
/// AVAudioSession route changes; Android: AudioManager devices). NÃO
/// chama `session.configure(...)` — `audioplayers` segue dono da
/// AVAudioSession; a gente só observa.
///
/// Web: package não suporta — fica desativado (sempre `false`).
class AudioRouteService extends ChangeNotifier {
  AudioRouteService._();
  static final AudioRouteService instance = AudioRouteService._();

  bool _hasExternalAudio = false;
  bool _initialized = false;
  StreamSubscription<Set<AudioDevice>>? _sub;
  String? _activeDeviceName;

  /// True quando há ao menos um device de output externo ativo (fone com
  /// fio, BT A2DP/HFP, USB audio, AirPlay). False quando só o speaker
  /// embutido / earpiece está ativo, ou no web.
  bool get hasExternalAudio => _hasExternalAudio;

  /// Nome do device ativo pra snackbar de confirmação ("Conectado: AirPods").
  /// Null quando hasExternalAudio é false ou plataforma não reporta nome.
  String? get activeDeviceName => _activeDeviceName;

  /// Idempotente. Inicia o listen e popula o estado com o snapshot atual.
  /// Best-effort — falhas (ex: web) viram noop silencioso.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      // Snapshot inicial (cobre app aberto com fones já conectados).
      _applyDevices(await session.getDevices(includeInputs: false));
      _sub = session.devicesStream.listen(
        (devices) => _applyDevices(devices.where((d) => !d.isInput).toSet()),
        onError: (Object e, StackTrace st) {
          Logger.warn('audio_route.devices_stream_err', context: {'err': '$e'});
        },
      );
      Logger.info('audio_route.init_ok',
          context: {'externalAt': _hasExternalAudio});
    } catch (e, st) {
      Logger.error('audio_route.init_failed', e, st);
    }
  }

  void _applyDevices(Set<AudioDevice> devices) {
    AudioDevice? externalActive;
    for (final d in devices) {
      switch (d.type) {
        case AudioDeviceType.bluetoothA2dp:
        case AudioDeviceType.bluetoothLe:
        case AudioDeviceType.bluetoothSco:
        case AudioDeviceType.wiredHeadphones:
        case AudioDeviceType.wiredHeadset:
        case AudioDeviceType.usbAudio:
        case AudioDeviceType.airPlay:
        case AudioDeviceType.hdmi:
          externalActive = d;
          break;
        default:
          // builtin speaker/earpiece/mic — ignora.
          break;
      }
      if (externalActive != null) break;
    }
    final next = externalActive != null;
    final nextName = externalActive?.name;
    if (next != _hasExternalAudio || nextName != _activeDeviceName) {
      _hasExternalAudio = next;
      _activeDeviceName = nextName;
      Logger.info('audio_route.changed', context: {
        'hasExternal': next,
        'device': ?nextName,
      });
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}

final audioRouteService = AudioRouteService.instance;
