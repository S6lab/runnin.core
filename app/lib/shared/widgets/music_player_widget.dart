import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'file_picker/file_picker.dart';
import '../audio/music_player_service.dart';

final musicPlayerProvider = Provider((ref) => MusicPlayerService());

class MusicPlayerWidget extends ConsumerStatefulWidget {
  const MusicPlayerWidget({super.key});

  @override
  ConsumerState<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends ConsumerState<MusicPlayerWidget> {
  String? _currentTrackName;
  bool _isPlaying = false;

  Future<void> _selectAndPlayMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: MediaType.audio,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final player = ref.read(musicPlayerProvider);
        
        await player.playAsset(path);
        setState(() {
          _currentTrackName = result.files.single.name;
          _isPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar música: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(musicPlayerProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.runninPalette.surface,
        border: Border.all(color: context.runninPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.music_note_rounded, color: context.runninPalette.primary),
              Text(_currentTrackName ?? 'Nenhuma música selecionada', 
                  style: context.runninType.labelCaps.copyWith(
                    fontSize: 12,
                    color: context.runninPalette.muted,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: () {},
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 48,
                  color: context.runninPalette.primary,
                ),
                onPressed: () async {
                  final player = ref.read(musicPlayerProvider);
                  if (_isPlaying) {
                    await player.pause();
                  } else {
                    await _selectAndPlayMusic();
                  }
                },
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: () {},
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: player.volume ?? 0.5,
            onChanged: (value) => player.setVolume(value),
            activeColor: context.runninPalette.primary,
          ),
        ],
      ),
    );
  }
}
