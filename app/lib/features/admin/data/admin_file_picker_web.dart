// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:runnin/features/admin/data/admin_picked_file.dart';

Future<AdminPickedFile?> pickAdminFile(List<String> allowedExtensions) async {
  final input = html.FileUploadInputElement()
    ..accept = allowedExtensions.map((extension) => '.$extension').join(',')
    ..multiple = false;

  final changeEvent = input.onChange.first.timeout(
    const Duration(minutes: 2),
    onTimeout: () => html.Event('timeout'),
  );

  input.click();

  final event = await changeEvent;
  if (event.type == 'timeout') return null;

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  final extension = _extensionFromName(file.name);
  final bytes = await _readBytes(file);
  if (bytes == null) return null;

  return AdminPickedFile(
    name: file.name,
    extension: extension,
    bytes: bytes,
    size: file.size,
  );
}

Future<Uint8List?> _readBytes(html.File file) {
  final reader = html.FileReader();
  final completer = Completer<Uint8List?>();

  reader.onLoad.first.then((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
    } else if (result is Uint8List) {
      completer.complete(result);
    } else {
      completer.complete(null);
    }
  });
  reader.onError.first.then((_) => completer.complete(null));
  reader.readAsArrayBuffer(file);

  return completer.future;
}

String _extensionFromName(String name) {
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == name.length - 1) return '';
  return name.substring(dotIndex + 1).toLowerCase();
}
