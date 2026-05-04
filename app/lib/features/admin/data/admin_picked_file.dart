import 'dart:typed_data';

class AdminPickedFile {
  final String name;
  final String extension;
  final Uint8List bytes;
  final int size;

  const AdminPickedFile({
    required this.name,
    required this.extension,
    required this.bytes,
    required this.size,
  });
}
