import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Bucket Storage per figure quiz (`questions.image_path` → `figures/...`).
const String kQuizQuestionImagesBucket = 'quiz-images';

/// Limiti layout figure quiz in base a viewport (mobile / tablet / desktop).
class QuizQuestionImageLayout {
  QuizQuestionImageLayout._();

  static double maxHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;

    double base;
    if (width < 360) {
      base = 112;
    } else if (width < 600) {
      base = 128;
    } else if (width < 1200) {
      base = 145;
    } else {
      base = 160;
    }

    if (height < 480) {
      return math.min(base, 105);
    }
    if (height < 640) {
      return math.min(base, 118);
    }
    return base;
  }

  static double maxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      return math.max(240, width - 48);
    }
    if (width < 900) {
      return 340;
    }
    return 360;
  }
}

/// Altezza massima figure quiz — alias di [QuizQuestionImageLayout.maxHeight].
double quizQuestionImageMaxHeight(BuildContext context) =>
    QuizQuestionImageLayout.maxHeight(context);

/// Risolve e mostra l’immagine di una domanda quiz (`questions.image_path`).
class QuizQuestionImage extends StatefulWidget {
  const QuizQuestionImage({
    super.key,
    required this.imagePath,
    this.maxHeight,
    this.maxWidth,
    this.sidePanelLayout = false,
  });

  final String? imagePath;

  /// Altezza massima esplicita (override layout responsive).
  final double? maxHeight;

  /// Larghezza massima esplicita.
  final double? maxWidth;

  /// Layout compatto per pannello laterale (figura a sinistra del testo).
  final bool sidePanelLayout;

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

  double _resolvedMaxHeight(BuildContext context) {
    if (widget.maxHeight != null) return widget.maxHeight!;
    if (widget.sidePanelLayout) {
      return 168;
    }
    return QuizQuestionImageLayout.maxHeight(context);
  }

  double _resolvedMaxWidth(BuildContext context) {
    if (widget.maxWidth != null) return widget.maxWidth!;
    if (widget.sidePanelLayout) {
      return 220;
    }
    return QuizQuestionImageLayout.maxWidth(context);
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

  BoxConstraints _constraints(BuildContext context) {
    return BoxConstraints(
      maxHeight: _resolvedMaxHeight(context),
      maxWidth: _resolvedMaxWidth(context),
    );
  }

  Widget _imageFrame({required BuildContext context, required Widget child}) {
    final constraints = _constraints(context);
    final bottomPad = widget.sidePanelLayout ? 0.0 : 10.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Align(
        alignment: widget.sidePanelLayout
            ? Alignment.topLeft
            : Alignment.center,
        child: ConstrainedBox(
          constraints: constraints,
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: _frameBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _frameBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _loadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePath?.trim();
    if (path == null || path.isEmpty) return const SizedBox.shrink();

    if (_loadingUrl) {
      return _imageFrame(context: context, child: _loadingIndicator());
    }

    final url = _imageUrl;
    if (url == null) {
      return _imageFrame(
        context: context,
        child: _ImageFallback(path: path, compact: true),
      );
    }

    final constraints = _constraints(context);

    return _imageFrame(
      context: context,
      child: ConstrainedBox(
        constraints: constraints,
        child: Image.network(
          url,
          fit: BoxFit.contain,
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
            return _loadingIndicator();
          },
        ),
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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade600,
            size: compact ? 16 : 18,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Figura non disponibile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: compact ? 11.5 : 12.5,
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
