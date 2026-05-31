import 'package:runnin/core/network/api_client.dart';

class RagDocStatus {
  final String id;
  final String? originalName;
  final String? storagePath;
  final String ragStatus; // 'indexed' | 'pending' | 'unknown'
  final int chunkCount;
  final String? uploadedAt;
  final String? indexedAt;
  final String? uploadedByEmail;
  final int? size;

  RagDocStatus({
    required this.id,
    required this.originalName,
    required this.storagePath,
    required this.ragStatus,
    required this.chunkCount,
    required this.uploadedAt,
    required this.indexedAt,
    required this.uploadedByEmail,
    required this.size,
  });

  factory RagDocStatus.fromJson(Map<String, dynamic> j) => RagDocStatus(
        id: j['id'] as String,
        originalName: j['originalName'] as String?,
        storagePath: j['storagePath'] as String?,
        ragStatus: (j['ragStatus'] as String?) ?? 'unknown',
        chunkCount: (j['chunkCount'] as num?)?.toInt() ?? 0,
        uploadedAt: j['uploadedAt'] as String?,
        indexedAt: j['indexedAt'] as String?,
        uploadedByEmail: j['uploadedByEmail'] as String?,
        size: (j['size'] as num?)?.toInt(),
      );
}

class RagStatusSummary {
  final int adminDocs;
  final int indexed;
  final int pending;
  final int totalChunksInUse;
  final int chunksWithEmbedding;
  final int vinculanteChunks;
  final int builtinCorpusChunks;

  RagStatusSummary({
    required this.adminDocs,
    required this.indexed,
    required this.pending,
    required this.totalChunksInUse,
    required this.chunksWithEmbedding,
    required this.vinculanteChunks,
    required this.builtinCorpusChunks,
  });

  factory RagStatusSummary.fromJson(Map<String, dynamic> j) => RagStatusSummary(
        adminDocs: (j['adminDocs'] as num).toInt(),
        indexed: (j['indexed'] as num).toInt(),
        pending: (j['pending'] as num).toInt(),
        totalChunksInUse: (j['totalChunksInUse'] as num).toInt(),
        chunksWithEmbedding: (j['chunksWithEmbedding'] as num).toInt(),
        vinculanteChunks: (j['vinculanteChunks'] as num?)?.toInt() ?? 0,
        builtinCorpusChunks: (j['builtinCorpusChunks'] as num).toInt(),
      );
}

/// Chunk da base RAG com os metadados v3 (Doc 1) pra inspeção no admin.
class RagChunkInfo {
  final String id;
  final String? secao;
  final String title;
  final List<String> categoria;
  final bool vinculante;
  final List<String> encaminhamento;
  final bool hasEmbedding;

  RagChunkInfo({
    required this.id,
    required this.secao,
    required this.title,
    required this.categoria,
    required this.vinculante,
    required this.encaminhamento,
    required this.hasEmbedding,
  });

  factory RagChunkInfo.fromJson(Map<String, dynamic> j) => RagChunkInfo(
        id: j['id'] as String,
        secao: j['secao'] as String?,
        title: (j['title'] as String?) ?? '',
        categoria: ((j['categoria'] as List?) ?? []).map((e) => e.toString()).toList(),
        vinculante: j['vinculante'] == true,
        encaminhamento: ((j['encaminhamento'] as List?) ?? []).map((e) => e.toString()).toList(),
        hasEmbedding: j['hasEmbedding'] == true,
      );
}

class RagPurgeResult {
  final int ragChunks;
  final int ragDocuments;
  final int storageFiles;
  final int reindexedChunks;

  RagPurgeResult({
    required this.ragChunks,
    required this.ragDocuments,
    required this.storageFiles,
    required this.reindexedChunks,
  });

  factory RagPurgeResult.fromJson(Map<String, dynamic> j) {
    final purged = (j['purged'] as Map<String, dynamic>?) ?? {};
    final reindexed = (j['reindexed'] as Map<String, dynamic>?) ?? {};
    return RagPurgeResult(
      ragChunks: (purged['ragChunks'] as num?)?.toInt() ?? 0,
      ragDocuments: (purged['ragDocuments'] as num?)?.toInt() ?? 0,
      storageFiles: (purged['storageFiles'] as num?)?.toInt() ?? 0,
      reindexedChunks: (reindexed['totalChunks'] as num?)?.toInt() ?? 0,
    );
  }
}

class RagReindexResult {
  final int totalChunks;
  final int withEmbedding;
  final int fromStorage;
  final int fromCorpus;

  RagReindexResult({
    required this.totalChunks,
    required this.withEmbedding,
    required this.fromStorage,
    required this.fromCorpus,
  });

  factory RagReindexResult.fromJson(Map<String, dynamic> j) => RagReindexResult(
        totalChunks: (j['totalChunks'] as num).toInt(),
        withEmbedding: (j['withEmbedding'] as num).toInt(),
        fromStorage: (j['fromStorage'] as num).toInt(),
        fromCorpus: (j['fromCorpus'] as num).toInt(),
      );
}

class AdminRagDatasource {
  Future<({List<RagDocStatus> docs, List<RagChunkInfo> chunks, RagStatusSummary summary})>
      status() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/rag/status');
    final data = res.data ?? {};
    final docs = ((data['documents'] as List?) ?? [])
        .map((e) => RagDocStatus.fromJson(e as Map<String, dynamic>))
        .toList();
    final chunks = ((data['chunks'] as List?) ?? [])
        .map((e) => RagChunkInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    final summary = RagStatusSummary.fromJson(
        data['summary'] as Map<String, dynamic>);
    return (docs: docs, chunks: chunks, summary: summary);
  }

  Future<RagReindexResult> reindex() async {
    final res = await apiClient.post<Map<String, dynamic>>('/admin/rag/reindex');
    return RagReindexResult.fromJson(res.data ?? {});
  }

  /// Apaga toda a base RAG (chunks/documents/uploads) e reindexa o corpus.
  Future<RagPurgeResult> purge() async {
    final res = await apiClient.post<Map<String, dynamic>>('/admin/rag/purge');
    return RagPurgeResult.fromJson(res.data ?? {});
  }
}
