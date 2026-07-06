import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Bucket Storage per figure quiz (`questions.image_path` → `figures/...`).
const String kQuizQuestionImagesBucket = 'quiz-images';

/// Risolve e mostra l’immagine di una domanda quiz (`questions.image_path`).
class QuizQuestionImage extends StatefulWidget {
  const QuizQuestionImage({
    super.key,
    required this.imagePath,
    this.maxHeight = 220,
  });

  final String? imagePath;
  final double maxHeight;

  @override
  State<QuizQuestionImage> createState() => _QuizQuestionImageState();
}

class _QuizQuestionImageState extends State<QuizQuestionImage> {
  String? _imageUrl;
  bool _loadingUrl = false;
  bool _triedSignedUrl = false;
  int _loadGeneration = 0;

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

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePath?.trim();
    if (path == null || path.isEmpty) return const SizedBox.shrink();

    if (_loadingUrl) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          height: widget.maxHeight,
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final url = _imageUrl;
    if (url == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _ImageFallback(path: path),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          height: widget.maxHeight,
          width: double.infinity,
          errorBuilder: (_, _, _) {
            if (!_triedSignedUrl) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _trySignedUrlFallback();
              });
            }
            return _ImageFallback(path: path);
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: widget.maxHeight,
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Figura non disponibile',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
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
