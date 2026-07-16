import 'package:flutter/material.dart';

import '../../config/supabase_config.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_registry.dart';
import '../../theme/app_visual_tokens.dart';
import '../../widgets/backoffice/student_360_detail_view.dart';

/// Scheda 360 a schermo intero — apertura diretta senza elenco allievi.
class Student360DirectPage extends StatefulWidget {
  const Student360DirectPage({
    super.key,
    required this.studentId,
    this.initialTabIndex = Student360DetailView.tabIndexScheda,
  });

  final StudentId studentId;
  final int initialTabIndex;

  @override
  State<Student360DirectPage> createState() => _Student360DirectPageState();
}

class _Student360DirectPageState extends State<Student360DirectPage> {
  StudentAdmin360View? _view;
  Object? _error;
  bool _loading = true;

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
      final view = await backofficeRepository.getStudentAdmin360(
        widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        _view = view;
        _loading = false;
        if (view == null) {
          _error = StateError('Scheda non disponibile per questo allievo.');
        }
      });
    } catch (e, st) {
      debugPrint('Student360DirectPage load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refreshDetail([StudentAdmin360View? updated]) async {
    if (!mounted) return;
    if (updated != null) {
      setState(() => _view = updated);
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _view?.profile.displayName ?? 'Scheda allievo';

    return Scaffold(
      backgroundColor: AppVisual.canvas,
      appBar: AppBar(
        backgroundColor: AppVisual.logoBlue,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Impossibile caricare la Scheda 360.\n$_error',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ),
            )
          : Student360DetailView(
              view: _view!,
              repository: backofficeRepository,
              onRefreshDetail: _refreshDetail,
              initialTabIndex: widget.initialTabIndex,
              isStaffPreview: !SupabaseConfig.isConfigured,
            ),
    );
  }
}
