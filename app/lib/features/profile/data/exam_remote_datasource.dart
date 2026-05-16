import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

class Exam {
  final String id;
  final String examName;
  final String fileName;
  final int fileSize;
  final String storageUrl;
  final String uploadedAt;
  final String? coachAnalysis;

  const Exam({
    required this.id,
    required this.examName,
    required this.fileName,
    required this.fileSize,
    required this.storageUrl,
    required this.uploadedAt,
    this.coachAnalysis,
  });

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: j['id'] as String,
        examName: j['examName'] as String? ?? 'Exame',
        fileName: j['fileName'] as String? ?? '',
        fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
        storageUrl: j['storageUrl'] as String? ?? '',
        uploadedAt: j['uploadedAt'] as String? ?? '',
        coachAnalysis: j['coachAnalysis'] as String?,
      );
}

class UploadUrlResult {
  final String examId;
  final String uploadUrl;
  const UploadUrlResult({required this.examId, required this.uploadUrl});
}

class ExamRemoteDatasource {
  final Dio _dio;
  ExamRemoteDatasource() : _dio = apiClient;

  Future<List<Exam>> listExams({int limit = 20}) async {
    final res = await _dio.get('/exams', queryParameters: {'limit': limit});
    final data = res.data;
    final items = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['items'] as List? ?? const []) : const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(Exam.fromJson)
        .toList();
  }

  Future<UploadUrlResult> getUploadUrl({
    required String examName,
    required String fileName,
    required int fileSize,
  }) async {
    final res = await _dio.post('/exams/upload-url', data: {
      'examName': examName,
      'fileName': fileName,
      'fileSize': fileSize,
    });
    final data = res.data as Map<String, dynamic>;
    return UploadUrlResult(
      examId: data['examId'] as String,
      uploadUrl: data['uploadUrl'] as String,
    );
  }

  Future<Exam> finalize(String examId, {String? coachAnalysis}) async {
    final res = await _dio.post('/exams/$examId/finalize', data: {
      if (coachAnalysis != null) 'coachAnalysis': coachAnalysis,
    });
    return Exam.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String examId) async {
    await _dio.delete('/exams/$examId');
  }
}
