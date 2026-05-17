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
  final int builtinCorpusChunks;

  RagStatusSummary({
    required this.adminDocs,
    required this.indexed,
    required this.pending,
    required this.totalChunksInUse,
    required this.chunksWithEmbedding,
    required this.builtinCorpusChunks,
  });

  factory RagStatusSummary.fromJson(Map<String, dynamic> j) => RagStatusSummary(
        adminDocs: (j['adminDocs'] as num).toInt(),
        indexed: (j['indexed'] as num).toInt(),
        pending: (j['pending'] as num).toInt(),
        totalChunksInUse: (j['totalChunksInUse'] as num).toInt(),
        chunksWithEmbedding: (j['chunksWithEmbedding'] as num).toInt(),
        builtinCorpusChunks: (j['builtinCorpusChunks'] as num).toInt(),
      );
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
  Future<({List<RagDocStatus> docs, RagStatusSummary summary})> status() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/rag/status');
    final data = res.data ?? {};
    final docs = ((data['documents'] as List?) ?? [])
        .map((e) => RagDocStatus.fromJson(e as Map<String, dynamic>))
        .toList();
    final summary = RagStatusSummary.fromJson(
        data['summary'] as Map<String, dynamic>);
    return (docs: docs, summary: summary);
  }

  Future<RagReindexResult> reindex() async {
    final res = await apiClient.post<Map<String, dynamic>>('/admin/rag/reindex');
    return RagReindexResult.fromJson(res.data ?? {});
  }
}
