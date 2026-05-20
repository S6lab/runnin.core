import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/data/admin_file_picker.dart';
import 'package:runnin/features/admin/data/admin_rag_datasource.dart';

/// Console do Coach.AI organizado pelos 5 MOMENTOS da jornada (arquitetura v3:
/// 4 modelos / 5 momentos). Cada momento mostra o modelo, seus system prompts
/// (editáveis em /admin/prompts) e, no momento 1, a base de conhecimento (RAG).
class CoachAiAdminPage extends StatefulWidget {
  const CoachAiAdminPage({super.key});

  @override
  State<CoachAiAdminPage> createState() => _CoachAiAdminPageState();
}

class _Moment {
  final int n;
  final String title;
  final String model;
  final String description;
  final List<String> promptIds;
  final bool usesRag;
  const _Moment({
    required this.n,
    required this.title,
    required this.model,
    required this.description,
    required this.promptIds,
    required this.usesRag,
  });
}

const _moments = <_Moment>[
  _Moment(
    n: 1,
    title: 'Indexação do conhecimento (RAG)',
    model: 'gemini-embedding-001',
    description: 'A base científica (Doc 1) é vetorizada e recuperada por similaridade. Os limites clínicos (seção R) são vinculantes.',
    promptIds: [],
    usesRag: true,
  ),
  _Moment(
    n: 2,
    title: 'Geração de Plano + Ajuste',
    model: 'gemini-3.1-pro-preview',
    description: 'Raciocínio: gera a estrutura do plano e decide os ajustes. "Pro decide".',
    promptIds: ['plan-init', 'plan-revision'],
    usesRag: true,
  ),
  _Moment(
    n: 3,
    title: 'Operação de Texto',
    model: 'gemini-3.5-flash',
    description: 'Redação na voz do Coach: relatórios, briefing, checkpoint, copy, cues. "Flash escreve".',
    promptIds: [
      'post-run-report',
      'post-run-report-enriched',
      'weekly-report',
      'period-analysis',
      'coach-chat',
      'live-coach',
    ],
    usesRag: true,
  ),
  _Moment(
    n: 4,
    title: 'Multimodal / Exame',
    model: 'gemini-3.5-flash',
    description: 'Lê exame (PDF/foto) e extrai dados estruturados. Nunca diagnostica.',
    promptIds: ['exam-analysis'],
    usesRag: true,
  ),
  _Moment(
    n: 5,
    title: 'Voz ao Vivo',
    model: 'gemini-2.5-flash-native-audio',
    description: 'Fala durante a corrida. Executa o que foi decidido — não raciocina, NÃO faz RAG.',
    promptIds: ['live-voice'],
    usesRag: false,
  ),
];

class _CoachAiAdminPageState extends State<CoachAiAdminPage> {
  final _rag = AdminRagDatasource();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('COACH.AI · CONSOLE'),
        actions: [
          TextButton(
            onPressed: () => context.push('/admin/prompts'),
            child: const Text('PERSONAS / KNOBS'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '4 modelos · 5 momentos. Pro decide, flash escreve. A voz só fala na corrida.',
            style: context.runninType.bodySm.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 16),
          for (final m in _moments) _MomentCard(moment: m, rag: _rag),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  final _Moment moment;
  final AdminRagDatasource rag;
  const _MomentCard({required this.moment, required this.rag});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${moment.n}',
                    style: type.dataSm.copyWith(color: palette.background)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(moment.title, style: type.labelMd),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(text: moment.model, color: palette.secondary),
              _Badge(
                text: moment.usesRag ? 'usa RAG' : 'sem RAG',
                color: moment.usesRag ? palette.tertiary : palette.muted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(moment.description, style: type.bodySm.copyWith(color: palette.muted)),
          const SizedBox(height: 10),
          if (moment.usesRag && moment.n == 1)
            _RagPanel(rag: rag)
          else
            _PromptList(promptIds: moment.promptIds),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

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

class _PromptList extends StatelessWidget {
  final List<String> promptIds;
  const _PromptList({required this.promptIds});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in promptIds)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(id, style: type.dataXs.copyWith(color: palette.text)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => context.push('/admin/prompts'),
            child: const Text('EDITAR PROMPTS'),
          ),
        ),
      ],
    );
  }
}

class _RagPanel extends StatefulWidget {
  final AdminRagDatasource rag;
  const _RagPanel({required this.rag});

  @override
  State<_RagPanel> createState() => _RagPanelState();
}

class _RagPanelState extends State<_RagPanel> {
  RagStatusSummary? _summary;
  List<RagChunkInfo> _chunks = const [];
  bool _loading = false;
  bool _busy = false;
  String? _msg;
  bool _showChunks = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.rag.status();
      if (!mounted) return;
      setState(() {
        _summary = res.summary;
        _chunks = res.chunks;
      });
    } catch (e) {
      if (mounted) setState(() => _msg = 'Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reindex() async {
    setState(() => _busy = true);
    try {
      final r = await widget.rag.reindex();
      if (mounted) setState(() => _msg = 'Reindex: ${r.totalChunks} chunks, ${r.withEmbedding} com embedding.');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _msg = 'Erro no reindex: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    const allowed = ['pdf', 'txt', 'md', 'csv', 'json', 'doc', 'docx'];
    final file = await pickAdminFile(allowed);
    if (file == null) return;
    if (!allowed.contains(file.extension)) {
      if (mounted) setState(() => _msg = 'Formato não suportado.');
      return;
    }
    setState(() => _busy = true);
    try {
      final safe = file.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final ref = FirebaseStorage.instance.ref('rag/uploads/${ts}_$safe');
      await ref.putData(
        file.bytes,
        SettableMetadata(customMetadata: {'originalName': file.name, 'ragStatus': 'pending'}),
      );
      // Reindexa pra embedar o novo arquivo na base.
      final r = await widget.rag.reindex();
      if (mounted) setState(() => _msg = 'Arquivo enviado e reindexado: ${r.totalChunks} chunks.');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _msg = 'Erro no upload: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purge() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PURGAR BASE RAG?'),
        content: const Text(
          'Apaga TODOS os chunks, documentos e uploads e reindexa o corpus canônico (Doc 1). Operação destrutiva.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('PURGAR')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await widget.rag.purge();
      if (mounted) {
        setState(() => _msg =
            'Purga: ${r.ragChunks} chunks + ${r.ragDocuments} docs + ${r.storageFiles} uploads removidos. Reindexado: ${r.reindexedChunks}.');
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _msg = 'Erro na purga: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final s = _summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (s != null)
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Stat(label: 'CHUNKS', value: '${s.totalChunksInUse}'),
              _Stat(label: 'EMBEDDING', value: '${s.chunksWithEmbedding}'),
              _Stat(label: 'VINCULANTES', value: '${s.vinculanteChunks}'),
              _Stat(label: 'UPLOADS', value: '${s.adminDocs}'),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: _busy ? null : _load, child: const Text('ATUALIZAR')),
            OutlinedButton(onPressed: _busy ? null : _upload, child: const Text('ENVIAR ARQUIVO')),
            OutlinedButton(onPressed: _busy ? null : _reindex, child: const Text('REINDEXAR')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: palette.error),
              onPressed: _busy ? null : _purge,
              child: const Text('PURGAR + RESEMEAR'),
            ),
            TextButton(
              onPressed: () => setState(() => _showChunks = !_showChunks),
              child: Text(_showChunks ? 'OCULTAR CHUNKS' : 'VER CHUNKS (${_chunks.length})'),
            ),
          ],
        ),
        if (_busy) const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
        if (_msg != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_msg!, style: type.bodyXs.copyWith(color: palette.muted)),
        ),
        if (_showChunks)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                for (final c in _chunks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(c.secao ?? '—', style: type.dataXs.copyWith(color: palette.secondary)),
                        ),
                        Expanded(
                          child: Text(c.title, style: type.bodyXs.copyWith(color: palette.text)),
                        ),
                        if (c.vinculante)
                          _Badge(text: 'VINCULANTE', color: palette.warning),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: type.dataMd.copyWith(color: palette.primary)),
        Text(label, style: type.dataXs.copyWith(color: palette.muted)),
      ],
    );
  }
}
