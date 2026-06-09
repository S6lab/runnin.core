import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/data/admin_coach_runtime_datasource.dart';

/// Editor da config dinâmica do Coach Live — distância entre cues,
/// cooldowns por evento, rotação preventiva da sessão Live, throttle do
/// pendingSends queue. Defaults TS no server; override Firestore via PATCH.
/// App fetcha do server no boot da Home (cache 1h Hive).
class AdminCoachRuntimePage extends StatefulWidget {
  const AdminCoachRuntimePage({super.key});

  @override
  State<AdminCoachRuntimePage> createState() => _AdminCoachRuntimePageState();
}

class _AdminCoachRuntimePageState extends State<AdminCoachRuntimePage> {
  final _ds = AdminCoachRuntimeDatasource();
  CoachRuntimeConfig? _current;
  CoachRuntimeConfig? _defaults;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _message;

  // Edits in flight (string controllers pra deixar o user digitar livre).
  late final _checkInDistanceM = TextEditingController();
  late final _checkInIdleSeconds = TextEditingController();
  late final _rotationAgeMinutes = TextEditingController();
  late final _maxReconnect = TextEditingController();
  late final _paceCooldown = TextEditingController();
  late final _segmentPaceOffCooldown = TextEditingController();
  late final _highBpmCooldown = TextEditingController();
  late final _segmentEndCooldown = TextEditingController();
  late final _pendingThrottleMs = TextEditingController();
  late final _pendingMaxQueue = TextEditingController();
  late final _suppressGreetingMs = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _checkInDistanceM.dispose();
    _checkInIdleSeconds.dispose();
    _rotationAgeMinutes.dispose();
    _maxReconnect.dispose();
    _paceCooldown.dispose();
    _segmentPaceOffCooldown.dispose();
    _highBpmCooldown.dispose();
    _segmentEndCooldown.dispose();
    _pendingThrottleMs.dispose();
    _pendingMaxQueue.dispose();
    _suppressGreetingMs.dispose();
    super.dispose();
  }

  void _hydrate(CoachRuntimeConfig c) {
    _checkInDistanceM.text = c.checkInDistanceM.toStringAsFixed(0);
    _checkInIdleSeconds.text = c.checkInIdleSeconds.toString();
    _rotationAgeMinutes.text = c.rotationAgeMinutes.toString();
    _maxReconnect.text = c.maxReconnectAttempts.toString();
    _paceCooldown.text = c.cooldownsBy.paceAlert.toString();
    _segmentPaceOffCooldown.text = c.cooldownsBy.segmentPaceOff.toString();
    _highBpmCooldown.text = c.cooldownsBy.highBpm.toString();
    _segmentEndCooldown.text = c.cooldownsBy.segmentEnd.toString();
    _pendingThrottleMs.text = c.pendingSendsThrottleMs.toString();
    _pendingMaxQueue.text = c.pendingSendsMaxQueue.toString();
    _suppressGreetingMs.text = c.suppressCuesGreetingMs.toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final bundle = await _ds.get();
      if (!mounted) return;
      setState(() {
        _current = bundle.current;
        _defaults = bundle.defaults;
        _hydrate(bundle.current);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final body = <String, dynamic>{
        'checkInDistanceM': double.tryParse(_checkInDistanceM.text) ??
            _current?.checkInDistanceM ?? 500,
        'checkInIdleSeconds': int.tryParse(_checkInIdleSeconds.text) ??
            _current?.checkInIdleSeconds ?? 240,
        'rotationAgeMinutes': int.tryParse(_rotationAgeMinutes.text) ??
            _current?.rotationAgeMinutes ?? 4,
        'maxReconnectAttempts': int.tryParse(_maxReconnect.text) ??
            _current?.maxReconnectAttempts ?? 10,
        'cooldownsBy': {
          'pace_alert': int.tryParse(_paceCooldown.text) ?? 60,
          'segment_pace_off':
              int.tryParse(_segmentPaceOffCooldown.text) ?? 60,
          'high_bpm': int.tryParse(_highBpmCooldown.text) ?? 90,
          'segment_end': int.tryParse(_segmentEndCooldown.text) ?? 999999,
        },
        'pendingSendsThrottleMs':
            int.tryParse(_pendingThrottleMs.text) ?? 2000,
        'pendingSendsMaxQueue': int.tryParse(_pendingMaxQueue.text) ?? 3,
        'suppressCuesGreetingMs':
            int.tryParse(_suppressGreetingMs.text) ?? 12000,
      };
      final bundle = await _ds.patch(body);
      if (!mounted) return;
      setState(() {
        _current = bundle.current;
        _defaults = bundle.defaults;
        _hydrate(bundle.current);
        _message = 'Salvo. App pega na próxima sessão (cache 1h).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreDefaults() async {
    final d = _defaults;
    if (d == null) return;
    _hydrate(d);
    setState(() => _message = 'Defaults carregados (não salvo ainda).');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('COACH RUNTIME · PARÂMETROS'),
        actions: [
          IconButton(
            tooltip: 'Restaurar defaults',
            onPressed: _loading || _defaults == null ? null : _restoreDefaults,
            icon: const Icon(Icons.restore),
          ),
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _current == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Configs lidas pelo app no boot da Home (cache 1h Hive) e pelo server na criação da sessão Live (cache 60s). Save aqui = doc Firestore `app_config/coach_runtime` com merge raso.',
                  style: context.runninType.bodyXs.copyWith(color: palette.muted),
                ),
                const SizedBox(height: 16),
                if (_error != null) _notice(_error!, palette.error),
                if (_message != null) _notice(_message!, palette.success),
                _Section('CHECK-INS DO COACH', children: [
                  _Field(
                    label: 'checkInDistanceM',
                    hint: 'Distância (m) entre cues — default 500',
                    controller: _checkInDistanceM,
                    defaultValue:
                        _defaults?.checkInDistanceM.toStringAsFixed(0),
                  ),
                  _Field(
                    label: 'checkInIdleSeconds',
                    hint: 'Idle (s) sem coach falar — default 240',
                    controller: _checkInIdleSeconds,
                    defaultValue: _defaults?.checkInIdleSeconds.toString(),
                  ),
                ]),
                _Section('SESSÃO LIVE', children: [
                  _Field(
                    label: 'rotationAgeMinutes',
                    hint: 'Idade (min) antes de rotação preventiva — default 4',
                    controller: _rotationAgeMinutes,
                    defaultValue: _defaults?.rotationAgeMinutes.toString(),
                  ),
                  _Field(
                    label: 'maxReconnectAttempts',
                    hint: 'Cap de tentativas reconnect — default 10',
                    controller: _maxReconnect,
                    defaultValue: _defaults?.maxReconnectAttempts.toString(),
                  ),
                ]),
                _Section('COOLDOWNS POR EVENTO (s)', children: [
                  _Field(
                    label: 'pace_alert',
                    hint: 'default 60',
                    controller: _paceCooldown,
                    defaultValue:
                        _defaults?.cooldownsBy.paceAlert.toString(),
                  ),
                  _Field(
                    label: 'segment_pace_off',
                    hint: 'default 60',
                    controller: _segmentPaceOffCooldown,
                    defaultValue:
                        _defaults?.cooldownsBy.segmentPaceOff.toString(),
                  ),
                  _Field(
                    label: 'high_bpm',
                    hint: 'default 90',
                    controller: _highBpmCooldown,
                    defaultValue:
                        _defaults?.cooldownsBy.highBpm.toString(),
                  ),
                  _Field(
                    label: 'segment_end',
                    hint: 'one-shot — default 999999',
                    controller: _segmentEndCooldown,
                    defaultValue:
                        _defaults?.cooldownsBy.segmentEnd.toString(),
                  ),
                ]),
                _Section('PENDING SENDS / GREETING', children: [
                  _Field(
                    label: 'pendingSendsThrottleMs',
                    hint: 'Throttle (ms) entre cues drenadas — default 2000',
                    controller: _pendingThrottleMs,
                    defaultValue:
                        _defaults?.pendingSendsThrottleMs.toString(),
                  ),
                  _Field(
                    label: 'pendingSendsMaxQueue',
                    hint: 'Cap fila simultânea — default 3',
                    controller: _pendingMaxQueue,
                    defaultValue:
                        _defaults?.pendingSendsMaxQueue.toString(),
                  ),
                  _Field(
                    label: 'suppressCuesGreetingMs',
                    hint:
                        'Janela (ms) inicial com cues suprimidos — default 12000',
                    controller: _suppressGreetingMs,
                    defaultValue:
                        _defaults?.suppressCuesGreetingMs.toString(),
                  ),
                ]),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('SALVAR'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _notice(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, {required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.text,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? defaultValue;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.defaultValue,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (defaultValue != null)
                Text(
                  'default: $defaultValue',
                  style: TextStyle(color: palette.muted, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
            ],
            style: TextStyle(
                color: palette.text, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: palette.muted, fontSize: 11),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: palette.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
