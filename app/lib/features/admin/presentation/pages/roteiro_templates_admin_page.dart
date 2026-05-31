import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/data/admin_registry_datasource.dart';
import 'package:runnin/features/admin/data/admin_roteiro_datasource.dart';
import 'package:runnin/features/admin/domain/registry_entries.dart';
import 'package:runnin/features/admin/presentation/widgets/override_status_badge.dart';

/// Editor cru (JSON) dos templates de roteiro de fases (Dossiê 4).
/// Lê o default do backend e o override de app_config/roteiro_templates.
/// Salva o override por TIPO (substitui o tipo inteiro) e invalida o cache.
class RoteiroTemplatesAdminPage extends StatefulWidget {
  const RoteiroTemplatesAdminPage({super.key});

  @override
  State<RoteiroTemplatesAdminPage> createState() =>
      _RoteiroTemplatesAdminPageState();
}

class _RoteiroTemplatesAdminPageState extends State<RoteiroTemplatesAdminPage> {
  final _api = AdminRoteiroDatasource();
  final _registry = AdminRegistryDatasource();
  final _docRef =
      FirebaseFirestore.instance.collection('app_config').doc('roteiro_templates');
  final _ctrl = TextEditingController();

  Map<String, dynamic> _defaults = {};
  bool _hasOverride = false;
  OverrideStatus? _roteiroStatus;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _msg;

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _msg = null;
    });
    try {
      final results = await Future.wait([
        _api.getDefaults(),
        _docRef.get(),
        _registry.getWiringStatus().catchError((_) =>
          const WiringStatusPayload(
            prompts: {},
            personas: {},
            knobs: {},
            roteiroTemplates: OverrideStatus(
              hasOverride: false,
              consumer: '',
              cacheKey: 'roteiro_templates',
              cacheTtlSec: 60,
            ),
          )),
      ]);
      final defaults = results[0] as Map<String, dynamic>;
      final snap = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final wiring = results[2] as WiringStatusPayload;
      final override =
          (snap.data()?['templates'] as Map?)?.cast<String, dynamic>();
      setState(() {
        _defaults = defaults;
        _hasOverride = override != null && override.isNotEmpty;
        _roteiroStatus = wiring.roteiroTemplates;
        // Editor mostra o override se existe, senão o default como ponto de partida.
        _ctrl.text = _encoder.convert(_hasOverride ? override : defaults);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Falha ao carregar: $e';
        _loading = false;
      });
    }
  }

  void _loadDefaultIntoEditor() {
    setState(() {
      _ctrl.text = _encoder.convert(_defaults);
      _msg = 'Default carregado no editor — clique SALVAR pra aplicar.';
    });
  }

  Future<void> _save() async {
    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(_ctrl.text);
      if (decoded is! Map) {
        throw const FormatException('JSON raiz precisa ser um objeto {tipo: ...}.');
      }
      parsed = decoded.cast<String, dynamic>();
    } catch (e) {
      setState(() => _error = 'JSON inválido: $e');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _msg = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _docRef.set({
        'templates': parsed,
        'updatedAt': DateTime.now().toIso8601String(),
        if (user?.uid != null) 'updatedByUid': user!.uid,
        if (user?.email != null) 'updatedByEmail': user!.email,
      }, SetOptions(merge: true));
      await _api.invalidateCache();
      setState(() {
        _saving = false;
        _msg = 'Salvo. Próximos planos gerados usam estes roteiros.';
      });
      await _load();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Falha ao salvar: $e';
      });
    }
  }

  Future<void> _removeOverride() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('REMOVER OVERRIDE?'),
        content: const Text(
          'Apaga o override do Firestore e volta a usar os templates default versionados no código.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('REMOVER')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _saving = true;
      _error = null;
      _msg = null;
    });
    try {
      await _docRef.set({'templates': FieldValue.delete()},
          SetOptions(merge: true));
      await _api.invalidateCache();
      setState(() {
        _saving = false;
        _msg = 'Override removido — usando defaults.';
      });
      await _load();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Falha ao remover: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('ROTEIROS · DOSSIÊ 4')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Templates de roteiro de fases por tipo de sessão. O builder lê as instruções '
                    'daqui (placeholders {km} {pace} {n} {total}). Cada fase aceita VÁRIAS opções — '
                    'o builder alterna entre elas pra variar a redação. Editável sem deploy.',
                    style: type.bodySm.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_roteiroStatus != null)
                        OverrideStatusBadge(status: _roteiroStatus!)
                      else
                        _StatusPill(
                          text: _hasOverride ? 'OVERRIDE ATIVO' : 'USANDO DEFAULT',
                          color: _hasOverride ? palette.warning : palette.muted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: type.dataXs.copyWith(
                          color: palette.text, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: palette.surface,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: palette.border),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: type.bodyXs.copyWith(color: palette.error)),
                    ),
                  if (_msg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_msg!,
                          style: type.bodyXs.copyWith(color: palette.muted)),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : _loadDefaultIntoEditor,
                        child: const Text('CARREGAR DEFAULT'),
                      ),
                      if (_hasOverride)
                        OutlinedButton(
                          onPressed: _saving ? null : _removeOverride,
                          child: const Text('REMOVER OVERRIDE'),
                        ),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'SALVANDO…' : 'SALVAR'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: type.dataXs.copyWith(color: color)),
    );
  }
}
