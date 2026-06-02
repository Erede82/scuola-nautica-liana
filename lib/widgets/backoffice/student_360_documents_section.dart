import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import '../../theme/app_visual_tokens.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';
import 'practice_document_checklist_card.dart';
import 'student_360_section_layout.dart';
import 'student_360_storage_thumbnail.dart';

class Student360DocumentsSection extends StatelessWidget {
  const Student360DocumentsSection({
    super.key,
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  static String _readableToken(String raw) {
    final cleaned = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return '—';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }

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

  Future<void> _openDocument(BuildContext context, StudentDocument doc) {
    final path = doc.storagePath;
    if (path == null || path.isEmpty) return Future.value();
    return _openSignedUrl(
      context,
      () => repository.createStudentDocumentSignedUrl(path),
      fileName: doc.fileName,
      mimeType: doc.mimeType,
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

  static bool _isPdfFile({String? mimeType, String? fileName}) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.contains('pdf')) return true;
    return (fileName ?? '').toLowerCase().endsWith('.pdf');
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

  Future<void> _handleChecklistUpload(
    BuildContext context, {
    String? documentUiType,
    String? photoUiType,
  }) async {
    if (photoUiType != null &&
        (documentUiType == null ||
            photoUiType == StudentDocumentTypes.uiPhotoKindLicense)) {
      await _showUploadPhotoDialog(
        context,
        initialPhotoUiType: photoUiType,
      );
      return;
    }
    await _showUploadDocumentDialog(
      context,
      initialDocumentUiType: documentUiType,
    );
  }

  Future<void> _showUploadDocumentDialog(
    BuildContext context, {
    String? initialDocumentUiType,
  }) async {
    final documentTypes = StudentDocumentTypes.uploadDocumentOptions;
    var documentType =
        initialDocumentUiType ?? StudentDocumentTypes.uiIdentityCard;
    if (!documentTypes.containsKey(documentType)) {
      documentType = StudentDocumentTypes.uiIdentityCard;
    }

    DateTime? expiresAt;
    Student360PickedUploadFile? pickedFile;
    var uploading = false;

    await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> pickFile() async {
                final picked = await _pickUploadFile(dialogContext);
                if (picked == null || !dialogContext.mounted) return;
                setDialogState(() => pickedFile = picked);
              }

              Future<void> pickExpiration() async {
                final now = DateTime.now();
                final selected = await showDatePicker(
                  context: dialogContext,
                  initialDate: expiresAt ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 20),
                );
                if (selected == null || !dialogContext.mounted) return;
                setDialogState(() => expiresAt = selected);
              }

              Future<void> submit() async {
                final file = pickedFile;
                if (file == null) {
                  _showUploadMessage(
                    dialogContext,
                    'Seleziona un file da caricare.',
                  );
                  return;
                }
                setDialogState(() => uploading = true);
                try {
                  await repository.uploadStudentDocument(
                    studentId: view.profile.id,
                    practiceDossierId: view.practiceDossier?.id,
                    documentType: documentType,
                    title: StudentDocumentTypes.autoTitleForDocumentUiType(
                      documentType,
                    ),
                    fileName: file.name,
                    bytes: file.bytes,
                    mimeType: file.mimeType,
                    expiresAt: expiresAt,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _showUploadMessage(
                    context,
                    'Documento caricato correttamente.',
                  );
                  await _refreshAfterUpload(context);
                } catch (error) {
                  debugPrint('Upload documento allievo non riuscito: $error');
                  if (!dialogContext.mounted) return;
                  setDialogState(() => uploading = false);
                  _showUploadMessage(
                    dialogContext,
                    'Upload documento non riuscito. Riprova più tardi.',
                  );
                }
              }

              return AlertDialog(
                title: const Text('Carica documento'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: documentType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo documento',
                        ),
                        items: documentTypes.entries
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
                                () => documentType = value ?? documentType,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: uploading ? null : pickExpiration,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              expiresAt == null
                                  ? 'Scadenza opzionale'
                                  : BackofficeFormatters.dateUi(expiresAt),
                            ),
                          ),
                          if (expiresAt != null)
                            TextButton(
                              onPressed: uploading
                                  ? null
                                  : () =>
                                        setDialogState(() => expiresAt = null),
                              child: const Text('Rimuovi scadenza'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: uploading ? null : pickFile,
                        icon: const Icon(Icons.attach_file_outlined),
                        label: Text(pickedFile?.name ?? 'Seleziona file'),
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
  }

  Future<void> _confirmDeleteDocument(
    BuildContext context,
    StudentDocument doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina documento'),
        content: Text(
          'Vuoi eliminare questo documento? L\'operazione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await repository.deleteStudentDocument(
        documentId: doc.id,
        storagePath: doc.storagePath,
      );
      if (!context.mounted) return;
      _showUploadMessage(context, 'Documento eliminato.');
      await _refreshAfterUpload(context);
    } catch (error) {
      debugPrint('Eliminazione documento non riuscita: $error');
      if (!context.mounted) return;
      _showUploadMessage(
        context,
        'Eliminazione non riuscita. Riprova più tardi.',
      );
    }
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

  Widget _documentTile(BuildContext context, StudentDocument doc) {
    final textTheme = Theme.of(context).textTheme;
    final isImage = _isImageFile(mimeType: doc.mimeType, fileName: doc.fileName);
    final isPdf = _isPdfFile(mimeType: doc.mimeType, fileName: doc.fileName);
    final path = doc.storagePath;
    final typeLabel = StudentDocumentTypes.documentTypeLabel(doc.documentType);
    final statusLabel = _readableToken(doc.status);

    Future<void> openFile() => _openDocument(context, doc);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppVisual.inkMuted.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Student360StorageThumbnailPreview(
              storagePath: path,
              fileName: doc.fileName,
              mimeType: doc.mimeType,
              createSignedUrl: repository.createStudentDocumentSignedUrl,
              onTap: path != null && path.isNotEmpty ? openFile : null,
              fallbackIcon: isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
              showImagePreview: isImage,
              previewWidth: 88,
              height: 88,
              hideFileNameInPlaceholder: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stato: $statusLabel',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppVisual.inkMuted,
                    ),
                  ),
                  if (doc.expiresAt != null)
                    Text(
                      'Scadenza: ${BackofficeFormatters.dateUi(doc.expiresAt)}',
                      style: textTheme.labelSmall?.copyWith(
                        color: BackofficeUiTokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (path != null && path.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: openFile,
                          icon: const Icon(Icons.open_in_new_outlined, size: 18),
                          label: const Text('Apri'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _confirmDeleteDocument(context, doc),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                          label: Text(
                            'Elimina',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteDocument(context, doc),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red.shade700,
                      ),
                      label: Text(
                        'Elimina',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = view.practiceDossier;
    final documents = view.documents;
    final photos = view.photos;

    return Student360SectionScroll(
      child: Student360SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Foto e firma sono nella tab Scheda.',
              style: textTheme.bodySmall?.copyWith(
                color: AppVisual.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            if (d == null)
              Text(
                'Nessun fascicolo pratica — la checklist documenti richiesti '
                'compare dopo l’apertura del fascicolo (tab Scheda → Aggiorna fascicolo).',
                style: textTheme.bodyMedium,
              )
            else ...[
              PracticeDocumentChecklistCard(
                checklist: evaluatePracticeDocumentChecklist(
                  practiceType: d.practiceType,
                  documents: documents,
                  photos: photos,
                ),
                onUploadRequested: ({
                  documentUiType,
                  photoUiType,
                }) =>
                    _handleChecklistUpload(
                      context,
                      documentUiType: documentUiType,
                      photoUiType: photoUiType,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Documenti allievo',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BackofficeUiTokens.text,
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: BackofficeUiTokens.primary,
                  ),
                  onPressed: () => _showUploadDocumentDialog(context),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Carica documento'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (documents.isEmpty)
              Text('Nessun documento caricato.', style: textTheme.bodyMedium)
            else
              ...documents.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _documentTile(context, doc),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
