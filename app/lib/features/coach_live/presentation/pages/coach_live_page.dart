import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/coach_live/data/live_audio_service.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// MVP da conversa live com o coach via Gemini Live (WebSocket).
///
/// Esta versão suporta apenas TEXTO (envia user msg, recebe partes do coach).
/// Audio recording/playback streaming entra na próxima iteração.
///
/// Fluxo:
///  1. Open WS em <api>/v1/coach/live?token=<firebase-id-token>
///  2. Aguarda "ready" do server
///  3. Envia { type: 'text', text } → recebe { kind: 'content', serverContent: { modelTurn: { parts: [{ text? | inlineData? }] } } }
class CoachLivePage extends StatefulWidget {
  final String? runId;
  const CoachLivePage({super.key, this.runId});

  @override
  State<CoachLivePage> createState() => _CoachLivePageState();
}

class _CoachLivePageState extends State<CoachLivePage> {
  // Override opcional via env (testes locais). Senão deriva do API_BASE_URL
  // já configurado — staging usa staging, prod usa prod, sem hardcode.
  static const _wsFromEnv = String.fromEnvironment('COACH_LIVE_WS', defaultValue: '');

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _input = TextEditingController();
  final _messages = <_Msg>[];
  final _audio = LiveAudioService();
  bool _connecting = true;
  bool _connected = false;
  bool _micOn = false;
  String? _error;
  String _coachStream = '';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _input.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Login necessário');
      final token = await user.getIdToken();
      final baseWs = _wsFromEnv.isEmpty ? resolveCoachLiveWsUrl() : _wsFromEnv;
      final qs = <String, String>{'token': token ?? ''};
      if (widget.runId != null && widget.runId!.isNotEmpty) {
        qs['runId'] = widget.runId!;
      }
      final url = Uri.parse(baseWs).replace(queryParameters: qs);
      final channel = WebSocketChannel.connect(url);
      _channel = channel;
      _sub = channel.stream.listen(
        _handleServerMessage,
        onError: (err) {
          if (mounted) setState(() {
            _error = 'Erro: $err';
            _connecting = false;
            _connected = false;
          });
        },
        onDone: () {
          if (mounted) setState(() {
            _connected = false;
          });
        },
      );
    } catch (e) {
      if (mounted) setState(() {
        _error = '$e';
        _connecting = false;
      });
    }
  }

  void _handleServerMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final kind = msg['kind'] as String?;
      if (kind == 'ready') {
        setState(() {
          _connecting = false;
          _connected = true;
        });
        return;
      }
      if (kind == 'error') {
        setState(() {
          _error = msg['message'] as String? ?? 'erro desconhecido';
          _connecting = false;
          _connected = false;
        });
        return;
      }
      if (kind == 'content') {
        final serverContent = msg['serverContent'] as Map<String, dynamic>?;
        final modelTurn = serverContent?['modelTurn'] as Map<String, dynamic>?;
        final parts = modelTurn?['parts'] as List?;
        if (parts != null) {
          for (final p in parts) {
            final part = p as Map<String, dynamic>;
            final text = part['text'] as String?;
            if (text != null) {
              setState(() => _coachStream += text);
            }
            final inline = part['inlineData'] as Map<String, dynamic>?;
            final inlineB64 = inline?['data'] as String?;
            if (inlineB64 != null && inlineB64.isNotEmpty) {
              try {
                _audio.addSpeakerChunk(base64Decode(inlineB64));
              } catch (_) {/* ignore decoder errors */}
            }
          }
        }
        final turnComplete = serverContent?['turnComplete'] as bool? ?? false;
        if (turnComplete) {
          if (_coachStream.isNotEmpty) {
            setState(() {
              _messages.add(_Msg(role: 'coach', text: _coachStream));
              _coachStream = '';
            });
          }
          _audio.flushAndPlay();
        }
      }
    } catch (e) {
      debugPrint('coach_live parse err: $e / raw=$raw');
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || !_connected) return;
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _input.clear();
    });
    _channel?.sink.add(jsonEncode({'type': 'text', 'text': text}));
  }

  Future<void> _toggleMic() async {
    if (!_connected) return;
    if (_micOn) {
      await _audio.stopCapture();
      if (mounted) setState(() => _micOn = false);
      return;
    }
    try {
      await _audio.startCapture(_onMicChunk);
      if (mounted) setState(() => _micOn = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Mic: $e');
    }
  }

  void _onMicChunk(Uint8List pcmChunk) {
    final channel = _channel;
    if (channel == null || !_connected) return;
    channel.sink.add(jsonEncode({
      'type': 'audio',
      'mimeType': 'audio/pcm;rate=16000',
      'data': base64Encode(pcmChunk),
    }));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: const RunninAppBar(title: 'COACH AO VIVO'),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _connected ? palette.primary.withValues(alpha: 0.1) : palette.surface,
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _connected ? palette.primary : palette.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _connecting ? 'CONECTANDO…' : _connected ? 'AO VIVO • GEMINI' : 'DESCONECTADO',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: _connected ? palette.primary : palette.muted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (!_connected && !_connecting)
                    TextButton(
                      onPressed: _connect,
                      child: Text('RECONECTAR', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w500, color: palette.primary)),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: palette.error, fontSize: 12)),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_coachStream.isNotEmpty ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _messages.length) {
                    return _MsgBubble(msg: _Msg(role: 'coach', text: '$_coachStream…'));
                  }
                  return _MsgBubble(msg: _messages[i]);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: _connected,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, color: palette.text),
                      decoration: InputDecoration(
                        hintText: _connected ? 'Pergunte ao coach…' : '...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: palette.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: palette.primary)),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: _micOn ? 'Parar microfone' : 'Falar com o coach',
                    onPressed: _connected ? _toggleMic : null,
                    icon: Icon(
                      _micOn ? Icons.mic : Icons.mic_none,
                      color: _micOn
                          ? palette.error
                          : (_connected ? palette.primary : palette.muted),
                    ),
                  ),
                  IconButton(
                    onPressed: _connected ? _send : null,
                    icon: Icon(Icons.send, color: _connected ? palette.primary : palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  final String role; // 'user' | 'coach'
  final String text;
  _Msg({required this.role, required this.text});
}

class _MsgBubble extends StatelessWidget {
  final _Msg msg;
  const _MsgBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? palette.primary.withValues(alpha: 0.12) : palette.surfaceAlt,
                border: Border(
                  left: isUser ? BorderSide.none : BorderSide(color: palette.primary, width: 1.041),
                  right: isUser ? BorderSide(color: palette.primary, width: 1.041) : BorderSide.none,
                ),
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: palette.text,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
