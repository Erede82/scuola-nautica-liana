import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import '../../theme/app_visual_tokens.dart';
import 'backoffice_ui_tokens.dart';
import 'student_360_storage_thumbnail.dart';

class Student360PhotoSignatureSection extends StatelessWidget {
  const Student360PhotoSignatureSection({
    super.key,
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
    this.sidebarLayout = false,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  /// Colonna compatta per affiancare anagrafica (tab Scheda).
  final bool sidebarLayout;

  static void _showOpenError(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossibile aprire il file. Riprova più tardi.'),
      ),
    );
  }

  Future<void> _openSignedUrl(
    BuildContext context,
    Future<String> Function() createSignedUrl, {
    String? fileName,
    String? mimeType,
  }) async {
    try {
      final signedUrl = await createSignedUrl();
      if (!context.mounted) return;
      final uri = Uri.tryParse(signedUrl);
      if (uri == null || !uri.hasScheme) {
        _showOpenError(context);
        return;
      }
      if (_isImageFile(mimeType: mimeType, fileName: fileName)) {
        await _showLargeImageDialog(context, signedUrl);
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showOpenError(context);
      }
    } catch (_) {
      if (!context.mounted) return;
      _showOpenError(context);
    }
  }

  Future<void> _showLargeImageDialog(BuildContext context, String imageUrl) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Impossibile caricare l\'immagine.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPhoto(BuildContext context, StudentPhoto photo) {
    final path = photo.storagePath;
    if (path == null || path.isEmpty) return Future.value();
    return _openSignedUrl(
      context,
      () => repository.createStudentPhotoSignedUrl(path),
      fileName: photo.fileName,
      mimeType: photo.mimeType,
    );
  }

  static bool _isImageFile({String? mimeType, String? fileName}) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) return true;
    final name = (fileName ?? '').toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif');
  }
  static void _showUploadMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Student360PickedUploadFile?> _pickUploadFile(
    BuildContext context, {
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );
      if (!context.mounted) return null;
      if (result == null || result.files.isEmpty) {
        _showUploadMessage(context, 'Nessun file selezionato.');
        return null;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showUploadMessage(
          context,
          'Il file selezionato non contiene dati leggibili.',
        );
        return null;
      }
      return Student360PickedUploadFile(
        name: file.name,
        bytes: bytes,
        mimeType: _mimeTypeFromExtension(file.extension),
      );
    } catch (_) {
      if (!context.mounted) return null;
      _showUploadMessage(context, 'Impossibile selezionare il file.');
      return null;
    }
  }

  static String? _mimeTypeFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }

  Future<void> _refreshAfterUpload(BuildContext context) async {
    final updated = await repository.getStudentAdmin360(view.profile.id);
    if (!context.mounted) return;
    await onRefreshDetail(updated);
  }
  Future<void> _showUploadSignatureDialog(BuildContext context) async {
    await _showUploadPhotoDialog(
      context,
      initialPhotoUiType: StudentDocumentTypes.uiPhotoKindSignature,
      dialogTitle: 'Carica firma',
      uploadSuccessMessage: 'Firma caricata correttamente.',
      forceSignatureNotes: true,
      hideKindDropdown: true,
    );
  }

  Future<void> _showUploadPhotoDialog(
    BuildContext context, {
    String? initialPhotoUiType,
    String dialogTitle = 'Carica foto',
    String uploadSuccessMessage = 'Foto caricata correttamente.',
    bool forceSignatureNotes = false,
    bool hideKindDropdown = false,
  }) async {
    final isSignatureUpload =
        initialPhotoUiType == StudentDocumentTypes.uiPhotoKindSignature ||
        forceSignatureNotes;
    final photoKinds = isSignatureUpload
        ? StudentDocumentTypes.uploadSignaturePhotoOptions
        : StudentDocumentTypes.uploadPhotoOptions;
    var photoKind = initialPhotoUiType ?? StudentDocumentTypes.uiPhotoKindProfile;
    if (!photoKinds.containsKey(photoKind)) {
      photoKind = photoKinds.keys.first;
    }

    final notesController = TextEditingController();
    Student360PickedUploadFile? pickedFile;
    var uploading = false;

    bool showNotesFieldForKind(String kind) {
      if (isSignatureUpload) return false;
      return kind != StudentDocumentTypes.uiPhotoKindProfile &&
          kind != StudentDocumentTypes.uiPhotoKindSignature;
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> pickFile() async {
                final picked = await _pickUploadFile(
                  dialogContext,
                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                );
                if (picked == null || !dialogContext.mounted) return;
                setDialogState(() => pickedFile = picked);
              }

              Future<void> submit() async {
                final file = pickedFile;
                if (file == null) {
                  _showUploadMessage(
                    dialogContext,
                    'Seleziona una foto da caricare.',
                  );
                  return;
                }
                setDialogState(() => uploading = true);
                try {
                  final String? uploadNotes;
                  if (isSignatureUpload ||
                      photoKind ==
                          StudentDocumentTypes.uiPhotoKindSignature) {
                    uploadNotes =
                        StudentDocumentTypes.signaturePhotoNotesMarker;
                  } else if (photoKind ==
                      StudentDocumentTypes.uiPhotoKindProfile) {
                    uploadNotes = null;
                  } else if (notesController.text.trim().isNotEmpty) {
                    uploadNotes = notesController.text.trim();
                  } else {
                    uploadNotes = null;
                  }
                  await repository.uploadStudentPhoto(
                    studentId: view.profile.id,
                    photoKind: photoKind,
                    fileName: file.name,
                    bytes: file.bytes,
                    mimeType: file.mimeType,
                    notes: uploadNotes,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _showUploadMessage(context, uploadSuccessMessage);
                  await _refreshAfterUpload(context);
                } catch (error) {
                  debugPrint('Upload foto allievo non riuscito: $error');
                  if (!dialogContext.mounted) return;
                  setDialogState(() => uploading = false);
                  _showUploadMessage(
                    dialogContext,
                    'Upload foto non riuscito. Riprova più tardi.',
                  );
                }
              }

              return AlertDialog(
                title: Text(dialogTitle),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!hideKindDropdown)
                        DropdownButtonFormField<String>(
                          initialValue: photoKind,
                          decoration: const InputDecoration(
                            labelText: 'Tipo foto',
                          ),
                          items: photoKinds.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: uploading
                              ? null
                              : (value) => setDialogState(
                                  () => photoKind = value ?? photoKind,
                                ),
                        ),
                      if (!hideKindDropdown) const SizedBox(height: 12),
                      if (showNotesFieldForKind(photoKind))
                        TextField(
                          controller: notesController,
                          enabled: !uploading,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Note opzionali',
                          ),
                        ),
                      if (showNotesFieldForKind(photoKind))
                        const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: uploading ? null : pickFile,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(pickedFile?.name ?? 'Seleziona foto'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: uploading
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed: uploading ? null : submit,
                    child: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Carica'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      notesController.dispose();
    }
  }
  static const double _portraitPhotoWidth = 160;
  static const double _portraitPhotoHeight = 200;
  static const double _signaturePreviewWidth = 220;
  static const double _signaturePreviewHeight = 80;

  StudentPhoto? _primaryStudentPhoto(List<StudentPhoto> studentPhotos) {
    for (final photo in studentPhotos) {
      if (StudentDocumentTypes.normalizePhotoDbValue(photo.photoKind) ==
          StudentDocumentTypes.dbPhotoKindProfile) {
        return photo;
      }
    }
    return studentPhotos.isNotEmpty ? studentPhotos.first : null;
  }

  StudentPhoto? _primarySignaturePhoto(List<StudentPhoto> signaturePhotos) {
    return signaturePhotos.isNotEmpty ? signaturePhotos.first : null;
  }

  Widget _photoSignatureSection(
    BuildContext context, {
    required TextTheme textTheme,
    required List<StudentPhoto> studentPhotos,
    required List<StudentPhoto> signaturePhotos,
  }) {
    final portraitPhoto = _primaryStudentPhoto(studentPhotos);
    final signaturePhoto = _primarySignaturePhoto(signaturePhotos);

    Future<void> openPortrait() {
      if (portraitPhoto == null) return Future.value();
      return _openPhoto(context, portraitPhoto);
    }

    Future<void> openSignature() {
      if (signaturePhoto == null) return Future.value();
      return _openPhoto(context, signaturePhoto);
    }

    final photoColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Foto allievo',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BackofficeUiTokens.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Student360StorageThumbnailPreview(
                    storagePath: portraitPhoto?.storagePath,
                    fileName: portraitPhoto?.fileName,
                    mimeType: portraitPhoto?.mimeType,
                    createSignedUrl: repository.createStudentPhotoSignedUrl,
                    onTap: portraitPhoto?.storagePath != null &&
                            portraitPhoto!.storagePath!.isNotEmpty
                        ? openPortrait
                        : null,
                    fallbackIcon: Icons.person_outline,
                    showImagePreview: portraitPhoto != null,
                    previewWidth: _portraitPhotoWidth,
                    height: _portraitPhotoHeight,
                    hideFileNameInPlaceholder: true,
                    backgroundColor: AppVisual.inkMuted.withValues(alpha: 0.06),
                    borderRadius: 12,
                    imageFit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showUploadPhotoDialog(
                      context,
                      initialPhotoUiType:
                          StudentDocumentTypes.uiPhotoKindProfile,
                    ),
                    icon: Icon(
                      portraitPhoto == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.swap_horiz_outlined,
                      size: 18,
                    ),
                    label: Text(
                      portraitPhoto == null ? 'Carica' : 'Cambia',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Firma',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BackofficeUiTokens.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Student360StorageThumbnailPreview(
                    storagePath: signaturePhoto?.storagePath,
                    fileName: signaturePhoto?.fileName,
                    mimeType: signaturePhoto?.mimeType,
                    createSignedUrl: repository.createStudentPhotoSignedUrl,
                    onTap: signaturePhoto?.storagePath != null &&
                            signaturePhoto!.storagePath!.isNotEmpty
                        ? openSignature
                        : null,
                    fallbackIcon: Icons.draw_outlined,
                    showImagePreview: signaturePhoto != null,
                    previewWidth: _signaturePreviewWidth,
                    height: _signaturePreviewHeight,
                    hideFileNameInPlaceholder: true,
                    backgroundColor: Colors.white,
                    borderRadius: 8,
                    borderColor: AppVisual.inkMuted.withValues(alpha: 0.22),
                    imageFit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showUploadSignatureDialog(context),
                    icon: Icon(
                      signaturePhoto == null
                          ? Icons.draw_outlined
                          : Icons.swap_horiz_outlined,
                      size: 18,
                    ),
                    label: Text(
                      signaturePhoto == null ? 'Carica' : 'Cambia',
                    ),
                  ),
                ],
              );

    if (sidebarLayout) {
      return photoColumn;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto e firma',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: BackofficeUiTokens.text,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: AppVisual.inkMuted.withValues(alpha: 0.18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: photoColumn,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final photos = view.photos;
    final signaturePhotos = photos
        .where(
          (p) => StudentDocumentTypes.isSignaturePhoto(
            photoKind: p.photoKind,
            notes: p.notes,
            fileName: p.fileName,
          ),
        )
        .toList(growable: false);
    final studentPhotos = photos
        .where(
          (p) => !StudentDocumentTypes.isSignaturePhoto(
            photoKind: p.photoKind,
            notes: p.notes,
            fileName: p.fileName,
          ),
        )
        .toList(growable: false);
    return _photoSignatureSection(
      context,
      textTheme: textTheme,
      studentPhotos: studentPhotos,
      signaturePhotos: signaturePhotos,
    );
  }
}
