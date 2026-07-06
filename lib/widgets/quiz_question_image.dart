import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Risolve e mostra l’immagine di una domanda quiz (`questions.image_path`).
class QuizQuestionImage extends StatelessWidget {
  const QuizQuestionImage({
    super.key,
    required this.imagePath,
    this.maxHeight = 220,
  });

  final String? imagePath;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final url = resolveQuizQuestionImageUrl(imagePath);
    if (url == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          height: maxHeight,
          width: double.infinity,
          errorBuilder: (_, _, _) => _ImageFallback(path: imagePath!),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: maxHeight,
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
              'Immagine non disponibile',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tenta di costruire un URL pubblico Supabase Storage da path relativo.
String? resolveQuizQuestionImageUrl(String? imagePath) {
  final raw = imagePath?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  if (!SupabaseConfig.isConfigured) return null;

  final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
  final segments = normalized.split('/');
  if (segments.length < 2) return null;

  final bucket = segments.first;
  final objectPath = segments.sublist(1).join('/');
  if (bucket.isEmpty || objectPath.isEmpty) return null;

  try {
    return Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(objectPath);
  } catch (_) {
    return null;
  }
}
