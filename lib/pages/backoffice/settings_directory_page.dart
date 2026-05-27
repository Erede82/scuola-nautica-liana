import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repositories.dart';
import '../../theme/app_visual_tokens.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';
import '../../widgets/backoffice/backoffice_ui_tokens.dart';

/// Modulo Impostazioni — catalogo prestazioni preimpostate (Fase A).
class SettingsDirectoryPage extends StatefulWidget {
  const SettingsDirectoryPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SettingsDirectoryPage> createState() => _SettingsDirectoryPageState();
}

class _SettingsDirectoryPageState extends State<SettingsDirectoryPage> {
  List<PracticeServiceTemplate>? _items;
  Object? _error;
  bool _loading = true;
  bool _showInactive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await managementRepository.listPracticeServiceTemplates(
        includeInactive: _showInactive,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('SettingsDirectoryPage load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _items = null;
      });
    }
  }

  Future<void> _openForm({PracticeServiceTemplate? existing}) async {
    final saved = await showPracticeServiceTemplateDialog(
      context,
      existing: existing,
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleActive(PracticeServiceTemplate item) async {
    try {
      await managementRepository.setPracticeServiceTemplateActive(
        item.id,
        !item.active,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.active ? 'Prestazione disattivata.' : 'Prestazione attivata.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aggiornamento fallito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppVisual.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            Material(
              color: AppVisual.logoBlue,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  'Impostazioni',
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impostazioni',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BackofficeUiTokens.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Parametri gestionali della scuola nautica',
                  style: textTheme.bodyMedium?.copyWith(
                    color: BackofficeUiTokens.text.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Prestazioni preimpostate',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BackofficeUiTokens.text,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Mostra non attive'),
                  selected: _showInactive,
                  onSelected: (v) async {
                    setState(() => _showInactive = v);
                    await _load();
                  },
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Aggiorna elenco',
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : () => _openForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuova prestazione'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(textTheme)),
        ],
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Impossibile caricare le prestazioni.', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Riprova')),
            ],
          ),
        ),
      );
    }
    final items = _items ?? const <PracticeServiceTemplate>[];
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nessuna prestazione configurata.',
          style: textTheme.bodyLarge?.copyWith(
            color: BackofficeUiTokens.text.withValues(alpha: 0.65),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pad = wide ? 16.0 : 12.0;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _TemplateCard(
              item: items[index],
              wide: wide,
              onEdit: () => _openForm(existing: items[index]),
              onToggleActive: () => _toggleActive(items[index]),
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.item,
    required this.wide,
    required this.onEdit,
    required this.onToggleActive,
  });

  final PracticeServiceTemplate item;
  final bool wide;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final notes = item.internalNotes?.trim();
    final notesShort = notes == null || notes.isEmpty
        ? null
        : (notes.length > 80 ? '${notes.substring(0, 80)}…' : notes);

    return Material(
      color: AppVisual.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppVisual.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(wide ? 14 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BackofficeUiTokens.text,
                        ),
                      ),
                      if (item.description != null &&
                          item.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!.trim(),
                          style: textTheme.bodySmall?.copyWith(
                            color: BackofficeUiTokens.text.withValues(alpha: 0.72),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(active: item.active),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  label: 'Tipo',
                  value: BackofficeFormatters.practiceServiceType(item.practiceType),
                ),
                _MetaChip(
                  label: 'Percorso',
                  value: BackofficeFormatters.enrolledCoursePathStorage(
                    item.enrolledCoursePath,
                  ),
                ),
                _MetaChip(
                  label: 'Categoria',
                  value: BackofficeFormatters.enrolledLicenseCategory(
                    item.enrolledLicenseCategory,
                  ),
                ),
                _MetaChip(
                  label: 'Costo totale',
                  value: BackofficeFormatters.moneyEur(
                    item.defaultRegistrationFeeCents,
                  ),
                ),
                _MetaChip(
                  label: 'Acconto consigliato',
                  value: BackofficeFormatters.moneyEur(
                    item.suggestedDepositCents,
                  ),
                ),
              ],
            ),
            if (notesShort != null) ...[
              const SizedBox(height: 8),
              Text(
                notesShort,
                style: textTheme.labelSmall?.copyWith(
                  color: BackofficeUiTokens.text.withValues(alpha: 0.62),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifica'),
                ),
                OutlinedButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(
                    item.active ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(item.active ? 'Disattiva' : 'Attiva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? BackofficeUiTokens.success.withValues(alpha: 0.12)
            : BackofficeUiTokens.text.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? BackofficeUiTokens.success.withValues(alpha: 0.35)
              : AppVisual.border,
        ),
      ),
      child: Text(
        active ? 'Attiva' : 'Non attiva',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: active ? BackofficeUiTokens.success : BackofficeUiTokens.text,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppVisual.chipFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppVisual.border.withValues(alpha: 0.8)),
      ),
      child: RichText(
        text: TextSpan(
          style: textTheme.labelSmall?.copyWith(color: BackofficeUiTokens.text),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog creazione/modifica prestazione preimpostata.
Future<bool?> showPracticeServiceTemplateDialog(
  BuildContext context, {
  PracticeServiceTemplate? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _PracticeServiceTemplateDialog(existing: existing),
  );
}

class _PracticeServiceTemplateDialog extends StatefulWidget {
  const _PracticeServiceTemplateDialog({this.existing});

  final PracticeServiceTemplate? existing;

  @override
  State<_PracticeServiceTemplateDialog> createState() =>
      _PracticeServiceTemplateDialogState();
}

class _PracticeServiceTemplateDialogState
    extends State<_PracticeServiceTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _depositCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _sortCtrl;

  String _practiceType = 'new_license';
  String? _coursePath;
  String? _licenseCategory;
  bool _active = true;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _slugCtrl = TextEditingController(text: e?.slug ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _feeCtrl = TextEditingController(
      text: e != null
          ? (e.defaultRegistrationFeeCents / 100).toStringAsFixed(2)
          : '0.00',
    );
    _depositCtrl = TextEditingController(
      text: e != null
          ? (e.suggestedDepositCents / 100).toStringAsFixed(2)
          : '0.00',
    );
    _notesCtrl = TextEditingController(text: e?.internalNotes ?? '');
    _sortCtrl = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _practiceType = e?.practiceType ?? 'new_license';
    _coursePath = e?.enrolledCoursePath;
    _licenseCategory = e?.enrolledLicenseCategory;
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _descriptionCtrl.dispose();
    _feeCtrl.dispose();
    _depositCtrl.dispose();
    _notesCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  static String _slugify(String raw) {
    var s = raw.trim().toLowerCase();
    const map = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(map[ch] ?? ch);
    }
    s = buf.toString();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return s.isEmpty ? 'prestazione' : s;
  }

  int _parseEuroCents(String raw, String fieldLabel) {
    final t = raw.trim().replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
    if (t.isEmpty) return 0;
    final v = double.tryParse(t);
    if (v == null || v < 0) {
      throw FormatException('$fieldLabel non valido.');
    }
    return (v * 100).round();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final slug = _slugCtrl.text.trim().isEmpty
          ? _slugify(_titleCtrl.text)
          : _slugify(_slugCtrl.text);
      final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
      final input = PracticeServiceTemplateInput(
        slug: slug,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        practiceType: _practiceType,
        enrolledCoursePath: _coursePath,
        enrolledLicenseCategory: _licenseCategory,
        defaultRegistrationFeeCents: _parseEuroCents(_feeCtrl.text, 'Costo totale'),
        suggestedDepositCents:
            _parseEuroCents(_depositCtrl.text, 'Acconto consigliato'),
        internalNotes: _notesCtrl.text.trim(),
        active: _active,
        sortOrder: sort,
      );
      if (_isEdit) {
        await managementRepository.updatePracticeServiceTemplate(
          widget.existing!.id,
          input,
        );
      } else {
        await managementRepository.createPracticeServiceTemplate(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salvataggio fallito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifica prestazione' : 'Nuova prestazione'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titolo prestazione *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                  onChanged: (v) {
                    if (!_isEdit && _slugCtrl.text.trim().isEmpty) {
                      _slugCtrl.text = _slugify(v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _slugCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Slug (identificativo)',
                    border: OutlineInputBorder(),
                    helperText: 'Usato internamente; deve essere univoco.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _practiceType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo pratica *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'new_license', child: Text('Nuova patente')),
                    DropdownMenuItem(value: 'renewal', child: Text('Rinnovo')),
                    DropdownMenuItem(value: 'duplicate', child: Text('Duplicato')),
                    DropdownMenuItem(value: 'other', child: Text('Altro')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _practiceType = v);
                        },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _coursePath,
                  decoration: const InputDecoration(
                    labelText: 'Percorso iscrizione',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('— Nessuno —')),
                    DropdownMenuItem(
                      value: 'entro_12_miglia',
                      child: Text('Entro le 12 miglia motore'),
                    ),
                    DropdownMenuItem(
                      value: 'entro_12_miglia_vela',
                      child: Text('Oltre 12 miglia vela e motore'),
                    ),
                    DropdownMenuItem(value: 'd1', child: Text('D1')),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _coursePath = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _licenseCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoria patente',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('— Nessuna —')),
                    DropdownMenuItem(value: 'motore', child: Text('Motore')),
                    DropdownMenuItem(value: 'vela', child: Text('Vela')),
                    DropdownMenuItem(value: 'd1', child: Text('D1')),
                  ],
                  onChanged:
                      _busy ? null : (v) => setState(() => _licenseCategory = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _feeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Costo totale (€)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _depositCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Acconto consigliato (€)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note interne',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _sortCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ordine visualizzazione',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prestazione attiva'),
                  value: _active,
                  onChanged: _busy ? null : (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Salva' : 'Crea'),
        ),
      ],
    );
  }
}
