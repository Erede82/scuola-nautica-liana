import 'package:flutter/material.dart';

import 'backoffice_ui_tokens.dart';
import '../../theme/app_visual_tokens.dart';

bool student360StoragePreviewIsImage({String? mimeType, String? fileName}) {
  final mime = (mimeType ?? '').toLowerCase();
  if (mime.startsWith('image/')) return true;
  final name = (fileName ?? '').toLowerCase();
  return name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.png') ||
      name.endsWith('.webp') ||
      name.endsWith('.gif');
}

/// Anteprima file storage (immagine reale o placeholder icona).
class Student360StorageThumbnailPreview extends StatefulWidget {
  const Student360StorageThumbnailPreview({
    super.key,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.createSignedUrl,
    this.onTap,
    required this.fallbackIcon,
    this.showImagePreview = true,
    this.height = 96,
    this.previewWidth,
    this.hideFileNameInPlaceholder = false,
    this.backgroundColor,
    this.borderRadius = 10,
    this.borderColor,
    this.imageFit = BoxFit.cover,
  });

  final String? storagePath;
  final String? fileName;
  final String? mimeType;
  final Future<String> Function(String storagePath) createSignedUrl;
  final VoidCallback? onTap;
  final IconData fallbackIcon;
  final bool showImagePreview;
  final double height;
  final double? previewWidth;
  final bool hideFileNameInPlaceholder;
  final Color? backgroundColor;
  final double borderRadius;
  final Color? borderColor;
  final BoxFit imageFit;

  @override
  State<Student360StorageThumbnailPreview> createState() =>
      _Student360StorageThumbnailPreviewState();
}

class _Student360StorageThumbnailPreviewState
    extends State<Student360StorageThumbnailPreview> {
  String? _signedUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant Student360StorageThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    final path = widget.storagePath;
    if (path == null ||
        path.isEmpty ||
        !widget.showImagePreview ||
        !student360StoragePreviewIsImage(
          mimeType: widget.mimeType,
          fileName: widget.fileName,
        )) {
      return;
    }
    setState(() {
      _loading = true;
      _signedUrl = null;
    });
    try {
      final url = await widget.createSignedUrl(path);
      if (!mounted) return;
      final valid =
          url.trim().isNotEmpty && Uri.tryParse(url)?.hasScheme == true;
      setState(() {
        _signedUrl = valid ? url : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final width = widget.previewWidth ?? widget.height;
    Widget inner = SizedBox(
      width: width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: radius,
        child: _buildInner(context),
      ),
    );
    if (widget.borderColor != null) {
      inner = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: widget.borderColor!),
        ),
        child: inner,
      );
    }
    if (widget.onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        child: inner,
      ),
    );
  }

  Widget _buildInner(BuildContext context) {
    final bg =
        widget.backgroundColor ?? AppVisual.inkMuted.withValues(alpha: 0.08);

    if (_loading) {
      return ColoredBox(
        color: bg,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_signedUrl != null) {
      return ColoredBox(
        color: bg,
        child: Image.network(
          _signedUrl!,
          fit: widget.imageFit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => _placeholder(context),
        ),
      );
    }

    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor ??
          AppVisual.brandAzure.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          size: 32,
          color: BackofficeUiTokens.primary.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class Student360PickedUploadFile {
  const Student360PickedUploadFile({
    required this.name,
    required this.bytes,
    this.mimeType,
  });

  final String name;
  final List<int> bytes;
  final String? mimeType;
}
