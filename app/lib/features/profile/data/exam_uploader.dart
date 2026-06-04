import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/profile/data/exam_remote_datasource.dart';

/// Resultado de uma tentativa de upload de exame. Carrega o [Exam] criado
/// quando sucesso ou uma mensagem amigável de erro quando falha — caller
/// decide exibir SnackBar/inline banner.
class ExamUploadOutcome {
  const ExamUploadOutcome.success(this.exam) : errorMessage = null;
  const ExamUploadOutcome.failure(this.errorMessage) : exam = null;
  const ExamUploadOutcome.cancelled()
      : exam = null,
        errorMessage = null;

  final Exam? exam;
  final String? errorMessage;

  bool get isSuccess => exam != null;
  bool get isCancelled => exam == null && errorMessage == null;
}

/// Fluxo de upload de exame compartilhado entre Perfil → Saúde → Exames e
/// o passo "Sincronizar dados de saúde" do onboarding. Abre bottom sheet
/// com câmera vs arquivos, pega bytes, chama upload-url + finalize.
class ExamUploader {
  ExamUploader({ExamRemoteDatasource? remote})
      : _remote = remote ?? ExamRemoteDatasource();

  final ExamRemoteDatasource _remote;

  Future<ExamUploadOutcome> pickAndUpload(BuildContext context) async {
    final source = await _showSourcePicker(context);
    if (source == null) return const ExamUploadOutcome.cancelled();
    switch (source) {
      case _UploadSource.camera:
        return _fromCamera();
      case _UploadSource.file:
        return _fromFile();
    }
  }

  Future<_UploadSource?> _showSourcePicker(BuildContext context) {
    return showModalBottomSheet<_UploadSource>(
      context: context,
      backgroundColor: FigmaColors.surfaceCard,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: context.runninPalette.primary),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(sheetContext, _UploadSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.folder_outlined,
                  color: context.runninPalette.primary),
              title: const Text('Escolher arquivo (PDF, foto)'),
              onTap: () => Navigator.pop(sheetContext, _UploadSource.file),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<ExamUploadOutcome> _fromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? photo =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo == null) {
        Logger.info('exams.camera.cancelled');
        return const ExamUploadOutcome.cancelled();
      }
      final bytes = await File(photo.path).readAsBytes();
      return _uploadBytes(
        name: 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fileName: photo.name,
        size: bytes.length,
        bytes: bytes,
      );
    } catch (e, st) {
      Logger.error('exams.camera.failed', e, st);
      return const ExamUploadOutcome.failure(
        'Falha ao abrir a câmera. Confirme a permissão em Ajustes > runnin.',
      );
    }
  }

  Future<ExamUploadOutcome> _fromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        Logger.info('exams.file_picker.cancelled');
        return const ExamUploadOutcome.cancelled();
      }
      final picked = result.files.first;
      final bytes = picked.bytes;
      if (bytes == null) {
        Logger.warn('exams.file_picker.empty_bytes',
            context: {'name': picked.name});
        return const ExamUploadOutcome.failure(
            'Não foi possível ler o arquivo selecionado.');
      }
      return _uploadBytes(
        name: picked.name,
        fileName: picked.name,
        size: picked.size,
        bytes: bytes,
      );
    } catch (e, st) {
      Logger.error('exams.file_picker.failed', e, st);
      return const ExamUploadOutcome.failure('Falha ao abrir os arquivos.');
    }
  }

  Future<ExamUploadOutcome> _uploadBytes({
    required String name,
    required String fileName,
    required int size,
    required List<int> bytes,
  }) async {
    try {
      final urlResult = await _remote.getUploadUrl(
        examName: name,
        fileName: fileName,
        fileSize: size,
      );
      final exam = await _remote.finalize(urlResult.examId);
      return ExamUploadOutcome.success(exam);
    } catch (e, st) {
      Logger.error('exams.upload_failed', e, st, {'name': name, 'size': size});
      return const ExamUploadOutcome.failure(
          'Falha no upload. Tente novamente.');
    }
  }
}

enum _UploadSource { camera, file }
