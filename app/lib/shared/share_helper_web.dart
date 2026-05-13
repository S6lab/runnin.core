// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> shareText(String text) async {
  try {
    if (html.navigator.share != null) {
      await html.navigator.share({'text': text});
      return;
    }
  } catch (_) {}

  // Fallback: copiar para a área de transferência
  await _copyToClipboard(text);
}

Future<void> _copyToClipboard(String text) async {
  try {
    await html.navigator.clipboard?.writeText(text);
  } catch (_) {
    // Último fallback: textarea oculto
    _fallbackCopy(text);
  }
}

void _fallbackCopy(String text) {
  final textarea = html.TextAreaElement()
    ..value = text
    ..style.position = 'absolute'
    ..style.left = '-9999px';
  html.document.body?.append(textarea);
  textarea.select();
  html.document.execCommand('copy');
  textarea.remove();
}

/// Compartilhar imagem gerada a partir de um widget.
/// Futuro: implementar com OffscreenCanvas + toBlob para download de imagem.
Future<void> shareImage(String imageDataUrl, {String? filename}) async {
  try {
    if (html.navigator.share != null) {
      final blob = _dataUrlToBlob(imageDataUrl);
      if (blob != null) {
        final file = html.File([blob], filename ?? 'runin-share.png');
        await html.navigator.share({'files': [file]});
        return;
      }
    }
  } catch (_) {}

  // Fallback: download
  final anchor = html.AnchorElement()
    ..href = imageDataUrl
    ..download = filename ?? 'runin-share.png'
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

html.Blob? _dataUrlToBlob(String dataUrl) {
  final parts = dataUrl.split(',');
  if (parts.length != 2) return null;
  final byteStrings = parts[0].split(';');
  final mimeType = byteStrings[0].replaceFirst('data:', '');
  final content = html.atob(parts[1]);
  final bytes = Uint8List(content.length);
  for (var i = 0; i < content.length; i++) {
    bytes[i] = content.codeUnitAt(i);
  }
  return html.Blob([bytes], mimeType);
}
