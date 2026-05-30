import 'package:flutter/material.dart';

import '../../config/supabase_config.dart';
import '../../data/backoffice_mock/backoffice_demo_store.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../domain/course_taxonomy.dart';
import '../../repositories/backoffice/backoffice_registry.dart';
import '../../repositories/study_access_repository.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';
import '../../widgets/backoffice/backoffice_new_practice_dialog.dart';
import '../../widgets/backoffice/student_360_detail_view.dart';
import '../../theme/app_visual_tokens.dart';

/// Shell desktop-oriented per gestione interna allievi.
///
/// **Lettura e scrittura:** [backofficeRepository] (Supabase se configurato, altrimenti mock in memoria).
class SchoolManagementShellPage extends StatefulWidget {
  const SchoolManagementShellPage({
    super.key,
    this.embedded = false,
    this.bootstrapSelectStudentId,
  });

  final bool embedded;

  /// Se non null, al primo caricamento elenco seleziona questa anagrafica (es. dopo “Nuova pratica” dalla dashboard).
  final StudentId? bootstrapSelectStudentId;

  static const Color primary = AppVisual.logoBlue;
  static const Color accent = AppVisual.brandAzure;
  static const Color background = AppVisual.canvas;
  static const Color card = AppVisual.surface;
  static const Color neutral = AppVisual.chipFill;
  static const Color textPrimary = AppVisual.ink;

  @override
  State<SchoolManagementShellPage> createState() =>
      SchoolManagementShellPageState();
}

class SchoolManagementShellPageState extends State<SchoolManagementShellPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  StudentId? _selectedStudentId;

  EnrollmentCoursePath? _pathFilter;
  StudentRegistrationStatus? _statusFilter;

  static const double _listPaneWidth = 300;

  /// Solo layout desktop: nasconde la colonna elenco per dare spazio alla scheda.
  bool _listPaneVisible = true;
  static const Color _listRowBg = Color(0xFFFFFFFF);
  static const Color _listRowSelectedBg = Color(0xFFE8EEF9);

  List<StudentProfile>? _profiles;
  Object? _listError;
  bool _listLoading = true;

  StudentAdmin360View? _detailView;
  bool _detailLoading = false;
  Object? _detailError;

  StudentId? _pendingSelectAfterListLoad;
  bool _pendingCollapseListAfterOpen = false;
  bool _bootstrapFocusConsumed = false;

  int _profilesLoadGen = 0;
  int _detailLoadGen = 0;

  bool get _useRemoteReads => SupabaseConfig.isConfigured;

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.isConfigured) {
      backofficeDemoStore.addListener(_onMockStoreChanged);
    }
    _loadProfiles();
  }

  void _onMockStoreChanged() {
    _loadProfiles();
  }

  @override
  void dispose() {
    if (!SupabaseConfig.isConfigured) {
      backofficeDemoStore.removeListener(_onMockStoreChanged);
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Dopo creazione o deep-link da altre card: ricarica elenco e apre la scheda.
  ///
  /// Su layout desktop, [collapseListAfter] nasconde la colonna elenco per dare
  /// più spazio alla 360 (es. da Pratiche o Guide / Agenda).
  Future<void> openStudentAfterCreate(
    StudentId id, {
    bool collapseListAfter = false,
  }) async {
    _pendingCollapseListAfterOpen = collapseListAfter;
    _pendingSelectAfterListLoad = id;
    await _loadProfiles();
    if (!mounted) return;
    // Ricarica esplicita la 360 per l’ID richiesto (evita race con initState).
    if (_selectedStudentId == id) {
      await _loadDetail(id);
    }
  }

  Future<void> _onNewPracticePressed() async {
    final outcome = await showBackofficeNewPracticeDialog(
      context,
      repository: backofficeRepository,
    );
    if (!mounted || outcome == null) return;
    await openStudentAfterCreate(outcome.profile.id);
  }

  Future<void> _loadProfiles() async {
    final gen = ++_profilesLoadGen;
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final list = await backofficeRepository.listStudentProfiles();
      if (!mounted || gen != _profilesLoadGen) return;

      final pending = _pendingSelectAfterListLoad;
      _pendingSelectAfterListLoad = null;

      var nextSel = _ensureSelectionStillValid(_selectedStudentId, list);
      if (pending != null && list.any((p) => p.id == pending)) {
        nextSel = pending;
      } else if (!_bootstrapFocusConsumed &&
          widget.bootstrapSelectStudentId != null) {
        final b = widget.bootstrapSelectStudentId!;
        if (list.any((p) => p.id == b)) {
          nextSel = b;
        }
        _bootstrapFocusConsumed = true;
      }

      _selectedStudentId = nextSel;

      setState(() {
        _profiles = list;
        _listLoading = false;
      });
      if (_selectedStudentId != null) {
        await _loadDetail(_selectedStudentId!);
      }
      if (!mounted || gen != _profilesLoadGen) return;
      if (_pendingCollapseListAfterOpen) {
        final narrow = MediaQuery.sizeOf(context).width < 880;
        final collapseRequested = _pendingCollapseListAfterOpen;
        _pendingCollapseListAfterOpen = false;
        final deepLinkedOk = pending != null && _selectedStudentId == pending;
        if (collapseRequested && !narrow && deepLinkedOk) {
          setState(() => _listPaneVisible = false);
        }
      }
    } catch (e, st) {
      debugPrint('Backoffice list load failed: $e\n$st');
      if (!mounted || gen != _profilesLoadGen) return;
      _pendingCollapseListAfterOpen = false;
      setState(() {
        _listError = e;
        _listLoading = false;
        _profiles = null;
      });
    }
  }

  StudentId? _ensureSelectionStillValid(
    StudentId? current,
    List<StudentProfile> list,
  ) {
    if (current == null) return null;
    final exists = list.any((p) => p.id == current);
    return exists ? current : null;
  }

  Future<void> _loadDetail(StudentId id) async {
    final gen = ++_detailLoadGen;
    setState(() {
      _detailLoading = true;
      _detailError = null;
      _detailView = null;
    });
    try {
      final view = await backofficeRepository.getStudentAdmin360(id);
      if (!mounted || gen != _detailLoadGen) return;
      if (view != null) {
        debugPrint(
          'SchoolManagementShell DEBUG _loadDetail id=$id '
          'appointments=${view.appointments.length} '
          'payments=${view.payments.length} '
          'totalPaidCents=${view.financialSummary.totalPaidCents}',
        );
      }
      setState(() {
        _detailView = view;
        _detailLoading = false;
        if (view == null) {
          _detailError = StateError('Scheda non disponibile');
        }
      });
    } catch (e, st) {
      debugPrint('Backoffice detail load failed: $e\n$st');
      if (!mounted || gen != _detailLoadGen) return;
      setState(() {
        _detailError = StateError(
          'Impossibile aprire la scheda. Riprova o aggiorna l’elenco.',
        );
        _detailLoading = false;
      });
    }
  }

  /// Ricarica dopo mutazioni dal backoffice (senza spinner a schermo intero).
  Future<void> _refreshCurrentStudentSheet([
    StudentAdmin360View? updated,
  ]) async {
    final id = _selectedStudentId;
    if (id == null) return;
    try {
      final view = updated ?? await backofficeRepository.getStudentAdmin360(id);
      if (!mounted) return;
      setState(() {
        _detailView = view;
      });
    } catch (e, st) {
      debugPrint('Backoffice refresh after mutation failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aggiornamento scheda fallito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<StudentProfile> _filteredProfiles() {
    final all = _profiles;
    if (all == null) return [];
    final q = _searchCtrl.text.trim().toLowerCase();
    return all
        .where((p) {
          if (_pathFilter != null) {
            if (!p.hasEnrollmentCoursePath ||
                p.enrolledCoursePath != _pathFilter) {
              return false;
            }
          }
          if (_statusFilter != null && p.registrationStatus != _statusFilter) {
            return false;
          }
          if (q.isEmpty) return true;
          final fn = p.firstName.toLowerCase();
          final ln = p.lastName.toLowerCase();
          final em = (p.email ?? '').toLowerCase();
          return fn.contains(q) || ln.contains(q) || em.contains(q);
        })
        .toList(growable: false)
      ..sort((a, b) {
        final ap = a.onboardingStatus == StudentOnboardingStatus.pendingReview
            ? 0
            : 1;
        final bp = b.onboardingStatus == StudentOnboardingStatus.pendingReview
            ? 0
            : 1;
        if (ap != bp) return ap.compareTo(bp);
        final c = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
        if (c != 0) return c;
        return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
      });
  }

  /// Etichette filtro allineate ai codici catalogo pratica (PATCH 5E).
  String _enrollmentPathFilterLabel(EnrollmentCoursePath p) {
    switch (p) {
      case EnrollmentCoursePath.entro12Miglia:
        return 'Entro le 12 miglia motore · entro_12_miglia_motore';
      case EnrollmentCoursePath.d1:
        return 'D1 · d1';
      case EnrollmentCoursePath.entro12MigliaVela:
        return 'Oltre 12 miglia vela e motore · oltre_12_miglia_vela_motore';
    }
  }

  Widget _buildFilters({required bool compact}) {
    final pathDropdown = _filterDropdown<EnrollmentCoursePath?>(
      label: 'Percorso',
      value: _pathFilter,
      items: [
        const DropdownMenuItem<EnrollmentCoursePath?>(
          value: null,
          child: Text('Tutti i percorsi'),
        ),
        ...EnrollmentCoursePath.values.map(
          (path) => DropdownMenuItem(
            value: path,
            child: Text(_enrollmentPathFilterLabel(path)),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _pathFilter = v),
    );
    final statusDropdown = _filterDropdown<StudentRegistrationStatus?>(
      label: 'Stato iscr.',
      value: _statusFilter,
      items: [
        const DropdownMenuItem<StudentRegistrationStatus?>(
          value: null,
          child: Text('Tutti gli stati'),
        ),
        ...StudentRegistrationStatus.values.map(
          (s) => DropdownMenuItem(
            value: s,
            child: Text(BackofficeFormatters.registrationStatus(s)),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _statusFilter = v),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [pathDropdown, const SizedBox(height: 6), statusDropdown],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: pathDropdown),
        const SizedBox(width: 6),
        Expanded(child: statusDropdown),
      ],
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: _listRowBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SchoolManagementShellPage.neutral),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return InputDecorator(
      decoration: _filterDecoration(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    final items = _filteredProfiles();
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessun allievo trovato con questi filtri.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: SchoolManagementShellPage.textPrimary.withValues(
                alpha: 0.7,
              ),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final p = items[i];
        final selected = p.id == _selectedStudentId;
        final isNuovo =
            p.onboardingStatus == StudentOnboardingStatus.pendingReview;
        final tileBg = selected ? _listRowSelectedBg : _listRowBg;
        final borderColor = selected
            ? SchoolManagementShellPage.primary
            : AppVisual.border;
        final nameLine = '${p.firstName} ${p.lastName}'.trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: tileBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: borderColor, width: selected ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: SchoolManagementShellPage.primary.withValues(
                alpha: 0.06,
              ),
              onTap: () {
                setState(() => _selectedStudentId = p.id);
                _loadDetail(p.id);
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isNuovo
                          ? SchoolManagementShellPage.accent
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameLine,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: SchoolManagementShellPage.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SchoolManagementShellPage.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          BackofficeFormatters.studentListPracticeBadge(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: SchoolManagementShellPage.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftPanel({required bool compact}) {
    final textTheme = Theme.of(context).textTheme;
    final total = _profiles?.length ?? 0;
    final visible = _listLoading || _profiles == null
        ? 0
        : _filteredProfiles().length;
    final countLine = _listLoading
        ? 'Caricamento elenco…'
        : _listError != null
        ? 'Elenco non disponibile'
        : visible != total && _profiles != null
        ? '$visible allievi (filtri attivi, su $total registrati)'
        : '$total ${total == 1 ? 'allievo registrato' : 'allievi registrati'}';

    return ColoredBox(
      color: SchoolManagementShellPage.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Allievi',
                        style: textTheme.titleSmall?.copyWith(
                          color: SchoolManagementShellPage.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: 'Nascondi elenco',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        onPressed: _listLoading
                            ? null
                            : () => setState(() => _listPaneVisible = false),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  countLine,
                  style: textTheme.bodySmall?.copyWith(
                    color: SchoolManagementShellPage.textPrimary.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Cerca',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: _listRowBg,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: SchoolManagementShellPage.neutral,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: SchoolManagementShellPage.neutral,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: SchoolManagementShellPage.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: FilledButton.icon(
                        onPressed: _listLoading ? null : _onNewPracticePressed,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                        ),
                        label: const Text('Nuova pratica'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppVisual.logoBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          minimumSize: const Size(0, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _buildFilters(compact: compact),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppVisual.border.withValues(alpha: 0.65),
          ),
          Expanded(
            child: _listLoading
                ? const Center(child: CircularProgressIndicator())
                : _listError != null
                ? _buildListError()
                : _buildStudentList(),
          ),
        ],
      ),
    );
  }

  Widget _buildListError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: SchoolManagementShellPage.textPrimary.withValues(
                alpha: 0.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Impossibile caricare l’elenco.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifica permessi (ruolo staff), rete e configurazione.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SchoolManagementShellPage.textPrimary.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    final id = _selectedStudentId;
    if (id == null) {
      return ColoredBox(
        color: SchoolManagementShellPage.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 48,
                    color: SchoolManagementShellPage.textPrimary.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seleziona un allievo dalla lista per aprire la scheda 360°.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: SchoolManagementShellPage.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _listPaneVisible
                        ? (_useRemoteReads
                              ? 'Dati letti dal database quando disponibili.'
                              : 'Interfaccia interna di revisione — dati di esempio locali.')
                        : 'L’elenco allievi è nascosto. Usa l’icona sulla sinistra per mostrarlo e selezionare un profilo.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SchoolManagementShellPage.textPrimary.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_detailLoading) {
      return const ColoredBox(
        color: SchoolManagementShellPage.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_detailError != null) {
      return ColoredBox(
        color: SchoolManagementShellPage.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: SchoolManagementShellPage.textPrimary.withValues(
                    alpha: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Errore caricamento scheda',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _loadDetail(id),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final view = _detailView;
    if (view == null) {
      return ColoredBox(
        color: SchoolManagementShellPage.background,
        child: Center(
          child: Text(
            'Scheda non disponibile per questo ID.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Student360DetailView(
      key: ValueKey(
        's360-${view.profile.id}-'
        'p${view.payments.length}-'
        'g${view.appointments.length}-'
        't${view.financialSummary.totalPaidCents}',
      ),
      view: view,
      repository: backofficeRepository,
      onRefreshDetail: _refreshCurrentStudentSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 880;
            final mq = MediaQuery.sizeOf(context);
            final listMaxHeight = c.maxHeight.isFinite
                ? c.maxHeight
                : mq.height.clamp(480.0, 920.0);
            final basis = c.maxHeight.isFinite ? c.maxHeight : mq.height;
            final mobileListHeight = (basis * 0.58)
                .clamp(420.0, 560.0)
                .toDouble();
            final listPane = narrow
                ? SizedBox(
                    height: mobileListHeight,
                    child: _buildLeftPanel(compact: true),
                  )
                : SizedBox(
                    width: _listPaneWidth,
                    height: listMaxHeight,
                    child: _buildLeftPanel(compact: false),
                  );
            final detail = Expanded(child: _buildDetailPanel());

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  listPane,
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppVisual.border.withValues(alpha: 0.65),
                  ),
                  detail,
                ],
              );
            }
            if (!_listPaneVisible) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: SchoolManagementShellPage.card,
                    child: SizedBox(
                      width: 48,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: IconButton(
                            tooltip: 'Mostra elenco allievi',
                            onPressed: () =>
                                setState(() => _listPaneVisible = true),
                            icon: const Icon(Icons.group_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppVisual.border.withValues(alpha: 0.65),
                  ),
                  detail,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                listPane,
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppVisual.border.withValues(alpha: 0.65),
                ),
                detail,
              ],
            );
          },
        );
      },
    );

    if (widget.embedded) {
      return ColoredBox(
        color: SchoolManagementShellPage.background,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: SchoolManagementShellPage.background,
      appBar: AppBar(
        backgroundColor: SchoolManagementShellPage.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Backoffice scuola · Gestione allievi'),
        actions: [
          TextButton.icon(
            onPressed: _listLoading ? null : _onNewPracticePressed,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Nuova pratica'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
          IconButton(
            tooltip: 'Aggiorna elenco',
            onPressed: _listLoading ? null : _loadProfiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  _listLoading || _profiles == null
                      ? '…'
                      : '${_profiles!.length} '
                            '${_profiles!.length == 1 ? 'allievo' : 'allievi'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}
