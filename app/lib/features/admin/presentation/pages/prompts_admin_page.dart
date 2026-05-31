import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/features/admin/data/admin_prompts_datasource.dart';
import 'package:runnin/features/admin/data/admin_registry_datasource.dart';
import 'package:runnin/features/admin/domain/registry_entries.dart';
import 'package:runnin/features/admin/presentation/widgets/override_status_badge.dart';

/// Minimal admin console for personas/prompts/knobs.
/// Reads/writes directly to Firestore `app_config/prompts`.
/// Uses backend endpoints only for preview + defaults.
class PromptsAdminPage extends StatefulWidget {
  const PromptsAdminPage({super.key});

  @override
  State<PromptsAdminPage> createState() => _PromptsAdminPageState();
}

class _PromptsAdminPageState extends State<PromptsAdminPage> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  final _api = AdminPromptsDatasource();
  final _registry = AdminRegistryDatasource();
  final _docRef = FirebaseFirestore.instance.collection('app_config').doc('prompts');

  Map<String, dynamic> _doc = {};
  Map<String, dynamic> _defaults = {};
  List<PromptRegistryEntry> _prompts = const [];
  WiringStatusPayload? _wiring;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _docRef.get(),
        _api.getDefaults(),
        _registry.listPrompts(),
        _registry.getWiringStatus(),
      ]);
      final snap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final defaults = results[1] as Map<String, dynamic>;
      final prompts = results[2] as List<PromptRegistryEntry>;
      final wiring = results[3] as WiringStatusPayload;
      setState(() {
        _doc = snap.data() ?? {};
        _defaults = defaults;
        _prompts = prompts;
        _wiring = wiring;
        _loading = false;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final hint = status == 403
          ? 'Sua conta não tem permissão de admin. Faça logout e login de novo (após admin claim ser concedida).'
          : status == 401
              ? 'Sessão expirada. Faça logout e login.'
              : 'HTTP $status — ${e.message ?? "erro desconhecido"}';
      setState(() {
        _error = 'Falha ao carregar: $hint';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Falha ao carregar: $e';
        _loading = false;
      });
    }
  }

  Future<void> _persistMerge(Map<String, dynamic> partial) async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final audit = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        if (user?.uid != null) 'updatedByUid': user!.uid,
        if (user?.email != null) 'updatedByEmail': user!.email,
      };
      await _docRef.set({...partial, ...audit}, SetOptions(merge: true));
      await _api.invalidateCache();
      await _load();
    } catch (e) {
      setState(() {
        _error = 'Falha ao salvar: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompts & Personas'),
        actions: [
          IconButton(
            tooltip: 'Console Coach.AI (por momento)',
            onPressed: () => context.push('/admin/coach-ai'),
            icon: const Icon(Icons.hub_outlined),
          ),
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'PERSONAS'),
            Tab(text: 'PROMPTS'),
            Tab(text: 'KNOBS'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _PersonasTab(
                      doc: _doc,
                      defaults: _defaults,
                      saving: _saving,
                      wiring: _wiring,
                      onSave: _persistMerge,
                    ),
                    _PromptsTab(
                      doc: _doc,
                      defaults: _defaults,
                      saving: _saving,
                      api: _api,
                      prompts: _prompts,
                      wiring: _wiring,
                      onSave: _persistMerge,
                    ),
                    _KnobsTab(
                      doc: _doc,
                      saving: _saving,
                      wiring: _wiring,
                      onSave: _persistMerge,
                    ),
                  ],
                ),
    );
  }
}

// ───────────────────────────── PERSONAS ──────────────────────────────────

class _PersonasTab extends StatelessWidget {
  final Map<String, dynamic> doc;
  final Map<String, dynamic> defaults;
  final bool saving;
  final WiringStatusPayload? wiring;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _PersonasTab({
    required this.doc,
    required this.defaults,
    required this.saving,
    required this.wiring,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    // Lista de personas vem do wiring-status (server). Fallback pros 2
    // padrão caso o endpoint não responda (ex: cache loading).
    final ids = wiring?.personas.keys.toList() ?? const ['motivador', 'tecnico'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: ids.map((id) {
        final override = (doc['personas'] as Map?)?[id] as Map?;
        final defaultDesc = ((defaults['personas'] as Map?)?[id] as Map?)?['description'] as String? ?? '';
        final initial = (override?['description'] as String?) ?? defaultDesc;
        return _PersonaCard(
          id: id,
          defaultDescription: defaultDesc,
          initialDescription: initial,
          saving: saving,
          status: wiring?.personas[id],
          onSave: (text) => onSave({
            'personas': {
              id: {'description': text}
            }
          }),
          onReset: () => onSave({
            'personas': {id: FieldValue.delete()}
          }),
        );
      }).toList(),
    );
  }
}

class _PersonaCard extends StatefulWidget {
  final String id;
  final String defaultDescription;
  final String initialDescription;
  final OverrideStatus? status;
  final bool saving;
  final Future<void> Function(String) onSave;
  final Future<void> Function() onReset;

  const _PersonaCard({
    required this.id,
    required this.defaultDescription,
    required this.initialDescription,
    required this.status,
    required this.saving,
    required this.onSave,
    required this.onReset,
  });

  bool get isOverridden => status?.hasOverride ?? false;

  @override
  State<_PersonaCard> createState() => _PersonaCardState();
}

class _PersonaCardState extends State<_PersonaCard> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialDescription);
  }

  @override
  void didUpdateWidget(covariant _PersonaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDescription != widget.initialDescription) {
      _ctrl.text = widget.initialDescription;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(widget.id.toUpperCase(), style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (widget.status != null)
                  OverrideStatusBadge(status: widget.status!),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: widget.saving ? null : () => widget.onSave(_ctrl.text),
                  icon: const Icon(Icons.save),
                  label: const Text('SALVAR'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.saving ? null : () => _ctrl.text = widget.defaultDescription,
                  child: const Text('CARREGAR DEFAULT'),
                ),
                const SizedBox(width: 8),
                if (widget.isOverridden)
                  TextButton(
                    onPressed: widget.saving ? null : widget.onReset,
                    child: const Text('REMOVER OVERRIDE'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── PROMPTS ──────────────────────────────────

class _PromptsTab extends StatelessWidget {
  final Map<String, dynamic> doc;
  final Map<String, dynamic> defaults;
  final bool saving;
  final AdminPromptsDatasource api;
  final List<PromptRegistryEntry> prompts;
  final WiringStatusPayload? wiring;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _PromptsTab({
    required this.doc,
    required this.defaults,
    required this.saving,
    required this.api,
    required this.prompts,
    required this.wiring,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: prompts.map((entry) {
        final id = entry.id;
        final override = (doc['prompts'] as Map?)?[id] as Map?;
        final defaultPrompt = (defaults['prompts'] as Map?)?[id] as Map?;
        if (defaultPrompt == null) return const SizedBox.shrink();
        final status = wiring?.prompts[id];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (entry.deprecated)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Chip(
                      label: Text('DEPRECATED', style: TextStyle(fontSize: 9)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$id · ${entry.category}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'temp ${(override?['temperature'] ?? defaultPrompt['temperature'])} · maxTokens ${(override?['maxTokens'] ?? defaultPrompt['maxTokens'])} · ragChunks ${(override?['ragChunks'] ?? defaultPrompt['ragChunks'])}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            trailing: status != null
                ? OverrideStatusBadge(status: status, dense: true)
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _PromptEditorPage(
                id: id,
                currentOverride: override?.cast<String, dynamic>() ?? {},
                defaults: defaultPrompt.cast<String, dynamic>(),
                api: api,
                onSave: onSave,
                saving: saving,
              ),
            )),
          ),
        );
      }).toList(),
    );
  }
}

class _PromptEditorPage extends StatefulWidget {
  final String id;
  final Map<String, dynamic> currentOverride;
  final Map<String, dynamic> defaults;
  final AdminPromptsDatasource api;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final bool saving;

  const _PromptEditorPage({
    required this.id,
    required this.currentOverride,
    required this.defaults,
    required this.api,
    required this.onSave,
    required this.saving,
  });

  @override
  State<_PromptEditorPage> createState() => _PromptEditorPageState();
}

class _PromptEditorPageState extends State<_PromptEditorPage> {
  late TextEditingController _sysCtrl;
  late TextEditingController _userCtrl;
  late double _temperature;
  late int _maxTokens;
  late int _ragChunks;

  String? _previewSystem;
  String? _previewUser;
  String? _previewLlmOutput;
  String? _previewError;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _sysCtrl = TextEditingController(text: (widget.currentOverride['systemPrompt'] as String?) ?? widget.defaults['systemPrompt'] as String? ?? '');
    _userCtrl = TextEditingController(text: (widget.currentOverride['userTemplate'] as String?) ?? widget.defaults['userTemplate'] as String? ?? '');
    _temperature = ((widget.currentOverride['temperature'] ?? widget.defaults['temperature']) as num).toDouble();
    _maxTokens = ((widget.currentOverride['maxTokens'] ?? widget.defaults['maxTokens']) as num).toInt();
    _ragChunks = ((widget.currentOverride['ragChunks'] ?? widget.defaults['ragChunks']) as num).toInt();
  }

  @override
  void dispose() {
    _sysCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave({
      'prompts': {
        widget.id: {
          'systemPrompt': _sysCtrl.text,
          'userTemplate': _userCtrl.text,
          'temperature': _temperature,
          'maxTokens': _maxTokens,
          'ragChunks': _ragChunks,
        }
      }
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _resetToDefault() async {
    await widget.onSave({
      'prompts': {widget.id: FieldValue.delete()}
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _runPreview({required bool withLlm}) async {
    setState(() {
      _previewing = true;
      _previewError = null;
    });
    try {
      // Save current draft before preview so the backend reads it from Firestore
      await widget.onSave({
        'prompts': {
          widget.id: {
            'systemPrompt': _sysCtrl.text,
            'userTemplate': _userCtrl.text,
            'temperature': _temperature,
            'maxTokens': _maxTokens,
            'ragChunks': _ragChunks,
          }
        }
      });
      final res = await widget.api.preview(builder: widget.id, runLlm: withLlm);
      setState(() {
        _previewSystem = res['systemPrompt'] as String?;
        _previewUser = res['userPrompt'] as String?;
        _previewLlmOutput = res['llmOutput'] as String?;
        _previewing = false;
      });
    } catch (e) {
      setState(() {
        _previewError = '$e';
        _previewing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id),
        actions: [
          TextButton(
            onPressed: widget.saving ? null : _resetToDefault,
            child: const Text('REMOVER OVERRIDE', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: widget.saving ? null : _save,
            child: const Text('SALVAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('SYSTEM PROMPT', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: _sysCtrl,
            maxLines: 15,
            minLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),
          const Text('USER TEMPLATE', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text(
            'Placeholders: {{persona.tone}} {{profile.context}} {{rag}} {{input.*}} {{plan.*}} {{run.*}} {{revision.*}} {{recentRuns}} {{eventPrompt}} {{feedback.rules}} {{period.*}} {{question}} {{schema}}',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _userCtrl,
            maxLines: 20,
            minLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),
          const Text('KNOBS', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              const SizedBox(width: 8),
              const Text('temperature'),
              Expanded(
                child: Slider(
                  value: _temperature.clamp(0.0, 1.5),
                  min: 0,
                  max: 1.5,
                  divisions: 30,
                  label: _temperature.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _temperature = v),
                ),
              ),
              SizedBox(width: 50, child: Text(_temperature.toStringAsFixed(2))),
            ],
          ),
          Row(children: [
            const SizedBox(width: 8),
            const Text('maxTokens'),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: _maxTokens.toString(),
                keyboardType: TextInputType.number,
                onChanged: (v) => _maxTokens = int.tryParse(v) ?? _maxTokens,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 24),
            const Text('ragChunks'),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: _ragChunks.toString(),
                keyboardType: TextInputType.number,
                onChanged: (v) => _ragChunks = int.tryParse(v) ?? _ragChunks,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _previewing ? null : () => _runPreview(withLlm: false),
                icon: const Icon(Icons.visibility),
                label: const Text('COMPILAR'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _previewing ? null : () => _runPreview(withLlm: true),
                icon: const Icon(Icons.play_arrow),
                label: const Text('COMPILAR + RODAR LLM'),
              ),
            ],
          ),
          if (_previewing) const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
          if (_previewError != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_previewError!, style: const TextStyle(color: Colors.red)),
          ),
          if (_previewSystem != null) ...[
            const SizedBox(height: 16),
            const Text('PREVIEW — SYSTEM COMPILADO', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _PreviewBox(text: _previewSystem!),
            const SizedBox(height: 16),
            const Text('PREVIEW — USER COMPILADO', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _PreviewBox(text: _previewUser ?? ''),
          ],
          if (_previewLlmOutput != null) ...[
            const SizedBox(height: 16),
            const Text('OUTPUT DO LLM', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _PreviewBox(text: _previewLlmOutput!),
          ],
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final String text;
  const _PreviewBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

// ───────────────────────────── KNOBS ──────────────────────────────────

class _KnobsTab extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool saving;
  final WiringStatusPayload? wiring;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _KnobsTab({
    required this.doc,
    required this.saving,
    required this.wiring,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final knobs = ((doc['knobs'] as Map?)?['decisionLayer'] as Map?) ?? {};
    bool getFlag(String key, [bool def = true]) {
      final v = knobs[key];
      return v is bool ? v : def;
    }

    Widget knobTile(String knobKey, String title, String subtitle) {
      final status = wiring?.knobs[knobKey];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text(title),
              subtitle: Text(subtitle),
              value: getFlag(knobKey),
              onChanged: saving ? null : (v) => onSave({
                'knobs': {'decisionLayer': {knobKey: v}}
              }),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OverrideStatusBadge(status: status, dense: true),
                ),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Toggles globais que regulam o decision layer do live-coach. Aplicam após cache TTL (60s).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        knobTile(
          'respectMessageFrequency',
          'Respeitar coachMessageFrequency',
          'silent / alerts_only / per_2km / per_km',
        ),
        knobTile(
          'respectFeedbackToggles',
          'Respeitar coachFeedbackEnabled',
          'Filtra menções a pace/bpm/etc no prompt',
        ),
        knobTile(
          'respectDndWindow',
          'Respeitar DND window',
          'Suprime cues durante a janela do user (exceto pace_alert/finish)',
        ),
      ],
    );
  }
}
