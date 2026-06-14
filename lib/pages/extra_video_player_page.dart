import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_visual_tokens.dart';

/// Player minimo per videocorsi Extra (URL pubblico/esterno).
class ExtraVideoPlayerPage extends StatefulWidget {
  const ExtraVideoPlayerPage({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  final String title;
  final String videoUrl;

  @override
  State<ExtraVideoPlayerPage> createState() => _ExtraVideoPlayerPageState();
}

class _ExtraVideoPlayerPageState extends State<ExtraVideoPlayerPage> {
  static const Color _primaryColor = AppVisual.logoBlue;

  VideoPlayerController? _controller;
  Object? _initError;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      setState(() {
        _initError = StateError('URL video mancante.');
        _initializing = false;
      });
      return;
    }

    if (_isGoogleDriveViewUrl(url)) {
      setState(() {
        _initError = _GoogleDrivePlaybackError();
        _initializing = false;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = null;
      });
    } catch (e, st) {
      debugPrint('ExtraVideoPlayerPage init: $e\n$st');
      if (!mounted) return;
      setState(() {
        _initError = e;
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: _buildPlayerBody(textTheme, controller),
            ),
          ),
          if (controller != null && controller.value.isInitialized)
            _buildControls(controller),
        ],
      ),
    );
  }

  Widget _buildPlayerBody(TextTheme textTheme, VideoPlayerController? c) {
    if (_initializing) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Caricamento video…',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    if (_initError != null || c == null || !c.value.isInitialized) {
      final driveError = _initError is _GoogleDrivePlaybackError;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              driveError
                  ? 'Link Google Drive non diretto'
                  : 'Impossibile riprodurre il video.',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              driveError
                  ? 'Link Google Drive non diretto: il video potrebbe non essere '
                      'riproducibile dal player. Usa un link MP4 diretto o un '
                      'servizio video compatibile.'
                  : 'Verifica che l\'URL sia pubblico e riproducibile dal browser '
                      '(CORS e formato supportato).',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
      child: VideoPlayer(c),
    );
  }

  Widget _buildControls(VideoPlayerController c) {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          IconButton(
            onPressed: _togglePlay,
            icon: Icon(
              c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          Expanded(
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: _primaryColor,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isGoogleDriveViewUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host.contains('drive.google.com') && uri.path.contains('/file/');
}

class _GoogleDrivePlaybackError implements Exception {}
