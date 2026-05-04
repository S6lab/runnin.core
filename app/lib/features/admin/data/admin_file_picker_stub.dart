import 'package:file_picker/file_picker.dart';
import 'package:runnin/features/admin/data/admin_picked_file.dart';

Future<AdminPickedFile?> pickAdminFile(List<String> allowedExtensions) async {
  final picked = await FilePicker.pickFiles(
    allowMultiple: false,
    withData: true,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
  );

  if (picked == null || picked.files.isEmpty) return null;

  final file = picked.files.single;
  final bytes = file.bytes;
  if (bytes == null) return null;

  return AdminPickedFile(
    name: file.name,
    extension: (file.extension ?? '').toLowerCase(),
    bytes: bytes,
    size: file.size,
  );
}
