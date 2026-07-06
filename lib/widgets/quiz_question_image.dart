import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../theme/app_visual_tokens.dart';

/// Bucket Storage per figure quiz (`questions.image_path` → `figures/...`).
const String kQuizQuestionImagesBucket = 'quiz-images';

/// Altezza massima figure quiz: mobile compatto, desktop/web più ampia.
double quizQuestionImageMaxHeight(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) return 160;
  return 200;
}

/// Risolve e mostra l’immagine di una domanda quiz (`questions.image_path`).
class QuizQuestionImage extends StatefulWidget {
  const QuizQuestionImage({super.key, required this.imagePath, this.maxHeight});

  final String? imagePath;

  /// Se null, usa [quizQuestionImageMaxHeight] in base al viewport.
  final double? maxHeight;

  @override
  State<QuizQuestionImage> createState() => _QuizQuestionImageState();
}

class _QuizQuestionImageState extends State<QuizQuestionImage> {
  String? _imageUrl;
  bool _loadingUrl = false;
  bool _triedSignedUrl = false;
  int _loadGeneration = 0;

  static const Color _frameBackground = Color(0xFFF7F8FA);
  static const Color _frameBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _prepareUrl();
  }

  @override
  void didUpdateWidget(covariant QuizQuestionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _triedSignedUrl = false;
      _prepareUrl();
    }
  }

  double _resolvedMaxHeight(BuildContext context) =>
      widget.maxHeight ?? quizQuestionImageMaxHeight(context);

  Future<void> _prepareUrl() async {
    final path = widget.imagePath?.trim();
    if (path == null || path.isEmpty) {
      setState(() {
        _imageUrl = null;
        _loadingUrl = false;
      });
      return;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      setState(() {
        _imageUrl = path;
        _loadingUrl = false;
      });
      return;
    }

    if (!SupabaseConfig.isConfigured) {
      setState(() {
        _imageUrl = null;
        _loadingUrl = false;
      });
      return;
    }

    setState(() => _loadingUrl = true);
    final publicUrl = resolveQuizQuestionPublicUrl(path);
    if (!mounted) return;
    setState(() {
      _imageUrl = publicUrl;
      _loadingUrl = false;
    });
  }

  Future<void> _trySignedUrlFallback() async {
    if (_triedSignedUrl || !SupabaseConfig.isConfigured) return;
    final objectPath = resolveQuizQuestionObjectPath(widget.imagePath);
    if (objectPath == null) return;

    _triedSignedUrl = true;
    final generation = ++_loadGeneration;
    try {
      final signed = await Supabase.instance.client.storage
          .from(kQuizQuestionImagesBucket)
          .createSignedUrl(objectPath, 3600);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _imageUrl = signed);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _imageUrl = null);
    }
  }

  Widget _imageFrame({required BuildContext context, required Widget child}) {
    final maxHeight = _resolvedMaxHeight(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _frameBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _frameBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePath?.trim();
    if (path == null || path.isEmpty) return const SizedBox.shrink();

    final maxHeight = _resolvedMaxHeight(context);
    final imageHeight = maxHeight - 16;

    if (_loadingUrl) {
      return _imageFrame(
        context: context,
        child: SizedBox(
          height: imageHeight,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final url = _imageUrl;
    if (url == null) {
      return _imageFrame(
        context: context,
        child: _ImageFallback(path: path, compact: true),
      );
    }

    return _imageFrame(
      context: context,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        height: imageHeight,
        width: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) {
          if (!_triedSignedUrl) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _trySignedUrlFallback();
            });
          }
          return _ImageFallback(path: path, compact: true);
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: imageHeight,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.path, this.compact = false});

  final String path;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppVisual.chipFill.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade600,
            size: compact ? 18 : 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Figura non disponibile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Path oggetto in `quiz-images` (es. `figures/figura_26.png`).
String? resolveQuizQuestionObjectPath(String? imagePath) {
  final raw = imagePath?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return null;
  final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
  return normalized.isEmpty ? null : normalized;
}

/// URL pubblico Supabase Storage per figure quiz.
String? resolveQuizQuestionPublicUrl(String? imagePath) {
  final objectPath = resolveQuizQuestionObjectPath(imagePath);
  if (objectPath == null) return null;
  if (!SupabaseConfig.isConfigured) return null;

  try {
    return Supabase.instance.client.storage
        .from(kQuizQuestionImagesBucket)
        .getPublicUrl(objectPath);
  } catch (_) {
    return null;
  }
}

/// Compat legacy: alias del resolver pubblico.
String? resolveQuizQuestionImageUrl(String? imagePath) =>
    resolveQuizQuestionPublicUrl(imagePath);
