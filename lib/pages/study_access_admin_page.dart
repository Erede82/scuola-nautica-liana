import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../data/license_catalog.dart';
import '../domain/backoffice/backoffice.dart';
import '../domain/international_phone.dart';
import '../models/license_models.dart';
import '../repositories/backoffice/backoffice_registry.dart';
import '../repositories/backoffice/backoffice_repository.dart';
import '../services/app_update/update_protected_mutation.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/backoffice/backoffice_formatters.dart';
import '../widgets/backoffice/lesson_study_access_ui.dart';
import '../widgets/backoffice/student_backoffice_dialogs.dart';

/// Schermata segreteria per gestire gli accessi studio per allievo (schede, esame, ripasso).
class StudyAccessAdminPage extends StatefulWidget {
  const StudyAccessAdminPage({
    super.key,
    this.embedded = false,
    this.initialStudentId,
    this.repository,
  });

  final bool embedded;

  /// Preselezione opzionale (es. deep-link). Ha priorità su `students.first`.
  final StudentId? initialStudentId;

  /// Override test / DI locale. Produzione: [backofficeRepository].
  final BackofficeRepository? repository;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

  /// Layout lista + dettaglio affiancati (desktop gestionale).
  static const double desktopSplitMinWidth = 1024;

  @override
  State<StudyAccessAdminPage> createState() => _StudyAccessAdminPageState();
}

class _StudyAccessAdminPageState extends State<StudyAccessAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<StudentProfile> _profiles = [];
  Object? _listError;
  bool _listLoading = true;

  StudentId? _selectedStudentId;
  StudentAdmin360View? _view;
  Object? _detailError;
  bool _detailLoading = false;
  bool _examBusy = false;
  bool _errorReviewBusy = false;
  final Set<int> _busyLessonNumbers = {};
  final Map<int, bool> _optimisticLessonUnlock = {};

  /// Evita reconcile selection concorrenti (search + load).
  int _selectionGen = 0;

  LicenseCategoryId _categoryId = LicenseCategoryId.motore;

  BackofficeRepository get _repo => widget.repository ?? backofficeRepository;

  bool get _isDesktopSplit {
    return MediaQuery.sizeOf(context).width >=
        StudyAccessAdminPage.desktopSplitMinWidth;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _selectedStudentId = widget.initialStudentId;
    _loadProfiles();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted || _listLoading) {
      if (mounted) setState(() {});
      return;
    }
    final visible = _filteredProfiles;

    // Narrow: la ricerca filtra solo la lista (Cambia allievo). Non auto-selezionare
    // durante la digitazione — altrimenti il TextField sparisce a metà input.
    if (!_isDesktopSplit) {
      final current = _selectedStudentId;
      if (current != null && visible.every((p) => p.id != current)) {
        _clearStudentSelection();
      } else {
        setState(() {});
      }
      return;
    }

    final next = _resolveTargetSelection(visible);
    if (next == _selectedStudentId) {
      setState(() {});
      return;
    }
    _applyResolvedSelection(visible);
  }

  /// Selection target rispetto alla lista *visibile* (ordinata/filtrata).
  StudentId? _resolveTargetSelection(List<StudentProfile> visible) {
    if (visible.isEmpty) return null;
    final current = _selectedStudentId;
    if (current != null && visible.any((p) => p.id == current)) {
      return current;
    }
    final initial = widget.initialStudentId;
    if (current == null &&
        initial != null &&
        visible.any((p) => p.id == initial)) {
      return initial;
    }
    return visible.first.id;
  }

  Future<void> _applyResolvedSelection(List<StudentProfile> visible) async {
    final gen = ++_selectionGen;
    final next = _resolveTargetSelection(visible);
    if (!mounted || gen != _selectionGen) return;

    if (next == null) {
      if (_selectedStudentId != null || _view != null || _detailError != null) {
        setState(() {
          _selectedStudentId = null;
          _view = null;
          _detailError = null;
          _detailLoading = false;
        });
      } else if (mounted) {
        setState(() {});
      }
      return;
    }

    if (next == _selectedStudentId) {
      if (_view == null && !_detailLoading) {
        await _loadStudentDetail(next, selectionGen: gen);
      } else if (mounted) {
        setState(() {});
      }
      return;
    }

    await _selectStudent(next, selectionGen: gen);
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final list = await _repo.listStudentProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = list;
        _listLoading = false;
      });
      // Desktop split: auto-select / preserve / fallback (stesso percorso del click).
      // Narrow: lista-first (no auto-select) — evita overflow e mantiene ricerca.
      if (_isDesktopSplit) {
        await _applyResolvedSelection(_filteredProfiles);
      }
    } catch (e, st) {
      debugPrint('StudyAccessAdminPage._loadProfiles: $e\n$st');
      if (!mounted) return;
      setState(() {
        _listError = e;
        _listLoading = false;
      });
    }
  }

  Future<void> _loadStudentDetail(
    StudentId studentId, {
    int? selectionGen,
  }) async {
    setState(() {
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final fresh = await _repo.getStudentAdmin360(studentId);
      if (!mounted) return;
      if (selectionGen != null && selectionGen != _selectionGen) return;
      if (_selectedStudentId != studentId) return;
      if (fresh == null) {
        setState(() {
          _detailError = 'Scheda allievo non trovata.';
          _view = null;
          _detailLoading = false;
        });
        return;
      }
      setState(() {
        _view = fresh;
        _categoryId = fresh.profile.enrolledLicenseCategory;
        _detailLoading = false;
      });
    } catch (e, st) {
      debugPrint('StudyAccessAdminPage._loadStudentDetail: $e\n$st');
      if (!mounted) return;
      if (selectionGen != null && selectionGen != _selectionGen) return;
      if (_selectedStudentId != studentId) return;
      setState(() {
        _detailError = e;
        _view = null;
        _detailLoading = false;
      });
    }
  }

  Future<void> _selectStudent(StudentId id, {int? selectionGen}) async {
    final gen = selectionGen ?? ++_selectionGen;
    setState(() {
      _selectedStudentId = id;
      _view = null;
      _detailError = null;
    });
    await _loadStudentDetail(id, selectionGen: gen);
  }

  void _clearStudentSelection() {
    ++_selectionGen;
    setState(() {
      _selectedStudentId = null;
      _view = null;
      _detailError = null;
      _detailLoading = false;
    });
  }

  Future<void> _refreshView() async {
    final id = _selectedStudentId;
    if (id == null) return;
    await _loadStudentDetail(id, selectionGen: _selectionGen);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatWriteError(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  Future<void> _runWrite({
    required Future<void> Function() action,
    required String success,
    required void Function(bool) setBusy,
  }) async {
    setBusy(true);
    try {
      await runUpdateProtectedMutation(action);
      await _refreshView();
      if (mounted) _snack(success);
    } catch (e, st) {
      debugPrint('StudyAccessAdminPage write: $e\n$st');
      if (mounted) _snack('Errore: ${_formatWriteError(e)}');
    } finally {
      if (mounted) setBusy(false);
    }
  }

  Future<void> _applyWholeLesson({
    required int lessonNumber,
    required int quizSheets,
    required bool unlocked,
  }) async {
    final view = _view;
    if (view == null || _busyLessonNumbers.contains(lessonNumber)) return;

    setState(() {
      _busyLessonNumbers.add(lessonNumber);
      _optimisticLessonUnlock[lessonNumber] = unlocked;
    });
    if (mounted) {
      _snack(
        unlocked ? 'Sblocco lezione in corso…' : 'Blocco lezione in corso…',
      );
    }

    try {
      await runUpdateProtectedMutation(
        () => _repo.setLessonSheetsUnlockedForLesson(
          studentId: view.profile.id,
          categoryId: _categoryId,
          lessonNumber: lessonNumber,
          sheetCount: quizSheets,
          unlocked: unlocked,
        ),
      );
      await _refreshView();
      if (mounted) {
        _snack(unlocked ? 'Lezione sbloccata.' : 'Lezione bloccata.');
      }
    } catch (e, st) {
      debugPrint('StudyAccessAdminPage lesson write: $e\n$st');
      if (mounted) _snack('Errore: ${_formatWriteError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _busyLessonNumbers.remove(lessonNumber);
          _optimisticLessonUnlock.remove(lessonNumber);
        });
      }
    }
  }

  Future<void> _setExamUnlocked(bool unlocked) async {
    final view = _view;
    if (view == null) return;
    await _runWrite(
      action: () => _repo.setExamQuizAccessForCategory(
        studentId: view.profile.id,
        categoryId: _categoryId,
        examUnlocked: unlocked,
      ),
      success: 'Accesso quiz esame aggiornato.',
      setBusy: (v) => setState(() => _examBusy = v),
    );
  }

  Future<void> _setErrorReviewTopic({
    required int lessonNumber,
    required bool topicUnlocked,
    String? didacticNote,
  }) async {
    final view = _view;
    if (view == null) return;
    await _runWrite(
      action: () => _repo.setErrorReviewTopicAssignment(
        studentId: view.profile.id,
        categoryId: _categoryId,
        lessonNumber: lessonNumber,
        topicUnlocked: topicUnlocked,
        didacticNote: didacticNote,
      ),
      success: 'Ripasso errori aggiornato.',
      setBusy: (v) => setState(() => _errorReviewBusy = v),
    );
  }

  List<StudentProfile> get _filteredProfiles {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return _profiles;
    return _profiles
        .where(
          (p) => InternationalPhoneRules.matchesSearch(
            query: q,
            displayName: p.displayName,
            email: p.email,
            phone: p.phone,
          ),
        )
        .toList(growable: false);
  }

  StudentProfile? get _selectedProfile {
    final id = _selectedStudentId;
    if (id == null) return null;
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return _view?.profile;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final desktopSplit = _isDesktopSplit;
    final showTabs = _selectedStudentId != null && _view != null;

    return Scaffold(
      backgroundColor: StudyAccessAdminPage._backgroundColor,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: StudyAccessAdminPage._primaryColor,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: const Text('Gestione accessi studio'),
              centerTitle: true,
              bottom: showTabs ? _buildTabBar() : null,
            ),
      body: Column(
        children: [
          if (widget.embedded && showTabs)
            Material(
              color: StudyAccessAdminPage._primaryColor,
              child: _buildTabBar(),
            ),
          _InternalHeader(textTheme: textTheme),
          if (_listLoading)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_listError != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Impossibile caricare l’elenco allievi: $_listError',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFC62828),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadProfiles,
                        child: const Text('Riprova'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (desktopSplit)
            Expanded(child: _buildDesktopSplitBody(textTheme))
          else
            ..._buildNarrowBody(textTheme),
        ],
      ),
    );
  }

  Widget _buildDesktopSplitBody(TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 340,
          child: _StudentPickerSection(
            key: const Key('study_access_student_list'),
            textTheme: textTheme,
            searchCtrl: _searchCtrl,
            listLoading: false,
            listError: null,
            profiles: _filteredProfiles,
            allProfilesEmpty: _profiles.isEmpty,
            selectedProfile: _selectedProfile,
            selectedStudentId: _selectedStudentId,
            sidebarMode: true,
            onRetryList: _loadProfiles,
            onSelect: (id) => _selectStudent(id),
            onClearSelection: _clearStudentSelection,
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppVisual.border.withValues(alpha: 0.85),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_detailLoading) const LinearProgressIndicator(minHeight: 2),
              if (_detailError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Errore caricamento scheda: $_detailError',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ),
              Expanded(child: _buildDetailPane(textTheme)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNarrowBody(TextTheme textTheme) {
    return [
      _StudentPickerSection(
        key: const Key('study_access_student_list'),
        textTheme: textTheme,
        searchCtrl: _searchCtrl,
        listLoading: false,
        listError: null,
        profiles: _filteredProfiles,
        allProfilesEmpty: _profiles.isEmpty,
        selectedProfile: _selectedProfile,
        selectedStudentId: _selectedStudentId,
        sidebarMode: false,
        onRetryList: _loadProfiles,
        onSelect: (id) => _selectStudent(id),
        onClearSelection: _clearStudentSelection,
      ),
      if (_detailLoading) const LinearProgressIndicator(minHeight: 2),
      if (_detailError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Errore caricamento scheda: $_detailError',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFFC62828),
            ),
          ),
        ),
      // Picker fuori dall’Expanded (come prima): TabBarView prende il resto.
      ..._buildDetailSlivers(textTheme),
    ];
  }

  /// Contenuto detail come lista di children da inserire in un Column genitore
  /// che già offre un Expanded / spazio flex.
  List<Widget> _buildDetailSlivers(TextTheme textTheme) {
    final searchActive = _searchCtrl.text.trim().isNotEmpty;
    final visible = _filteredProfiles;

    if (_profiles.isEmpty) {
      return [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Nessun allievo disponibile',
                key: const Key('study_access_empty_profiles'),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppVisual.ink.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (visible.isEmpty && searchActive) {
      return [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Nessun allievo corrisponde alla ricerca.',
                key: const Key('study_access_empty_search'),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppVisual.ink.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (_selectedStudentId == null) {
      // Lista già visibile sopra: niente copy "Seleziona un allievo…".
      return [const Expanded(child: SizedBox.shrink())];
    }

    if (_view != null) {
      return [
        Padding(
          key: const Key('study_access_detail_pane'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _CategoryBar(
            value: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v!),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _LessonSheetsTab(
                view: _view!,
                categoryId: _categoryId,
                textTheme: textTheme,
                busyLessonNumbers: _busyLessonNumbers,
                optimisticLessonUnlock: _optimisticLessonUnlock,
                onApplyWholeLesson: _applyWholeLesson,
              ),
              _ExamTab(
                view: _view!,
                categoryId: _categoryId,
                textTheme: textTheme,
                actionBusy: _examBusy,
                onSetExamUnlocked: _setExamUnlocked,
              ),
              _ErrorReviewTab(
                view: _view!,
                categoryId: _categoryId,
                textTheme: textTheme,
                actionBusy: _errorReviewBusy,
                onSetTopic: _setErrorReviewTopic,
                onOpenDialog: () => showErrorReviewAssignDialog(
                  context,
                  initialView: _view!,
                  repository: _repo,
                  onRefreshDetail: ([StudentAdmin360View? updated]) async {
                    if (updated != null) {
                      setState(() => _view = updated);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ];
    }

    if (_detailLoading) {
      return [
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ];
    }

    return [
      Expanded(
        child: Center(
          child: Text(
            'Impossibile caricare lo stato studio dell’allievo.',
            style: textTheme.bodyMedium,
          ),
        ),
      ),
    ];
  }

  Widget _buildDetailPane(TextTheme textTheme) {
    // Desktop split: un solo child Expanded → riusa gli stessi sliver in Column.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _buildDetailSlivers(textTheme),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppVisual.accentLight,
      indicatorWeight: 3,
      dividerColor: Colors.white.withValues(alpha: 0.2),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
      tabs: const [
        Tab(text: 'Schede'),
        Tab(text: 'Esame'),
        Tab(text: 'Ripasso'),
      ],
    );
  }
}

class _InternalHeader extends StatelessWidget {
  const _InternalHeader({required this.textTheme});

  final TextTheme textTheme;

  static const Color _primaryTint = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryTint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppVisual.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: _primaryTint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accessi studio — segreteria',
                  style: textTheme.labelLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gestisci gli accessi allo studio per l’allievo selezionato: '
            'schede lezione, quiz esame e ripasso errori.',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentPickerSection extends StatelessWidget {
  const _StudentPickerSection({
    super.key,
    required this.textTheme,
    required this.searchCtrl,
    required this.listLoading,
    required this.listError,
    required this.profiles,
    required this.allProfilesEmpty,
    required this.selectedProfile,
    required this.selectedStudentId,
    required this.sidebarMode,
    required this.onRetryList,
    required this.onSelect,
    required this.onClearSelection,
  });

  final TextTheme textTheme;
  final TextEditingController searchCtrl;
  final bool listLoading;
  final Object? listError;
  final List<StudentProfile> profiles;
  final bool allProfilesEmpty;
  final StudentProfile? selectedProfile;
  final StudentId? selectedStudentId;
  final bool sidebarMode;
  final VoidCallback onRetryList;
  final ValueChanged<StudentId> onSelect;
  final VoidCallback onClearSelection;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    if (listLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (listError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impossibile caricare l’elenco allievi: $listError',
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFFC62828),
              ),
            ),
            TextButton(onPressed: onRetryList, child: const Text('Riprova')),
          ],
        ),
      );
    }

    // Mobile / narrow: card selezionata + "Cambia allievo" (lista nascosta).
    if (!sidebarMode && selectedProfile != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _StudentAccessCard(
          profile: selectedProfile!,
          textTheme: textTheme,
          selected: true,
          trailing: TextButton(
            onPressed: onClearSelection,
            child: const Text('Cambia allievo'),
          ),
        ),
      );
    }

    final listBody = profiles.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              allProfilesEmpty
                  ? 'Nessun allievo disponibile'
                  : 'Nessun allievo corrisponde alla ricerca.',
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.75),
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: !sidebarMode,
            padding: EdgeInsets.zero,
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = profiles[index];
              return _StudentAccessCard(
                profile: p,
                textTheme: textTheme,
                selected: p.id == selectedStudentId,
                onTap: () => onSelect(p.id),
              );
            },
          );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Cerca per nome, telefono o email',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: _cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppVisual.border.withValues(alpha: 0.72),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppVisual.border.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${profiles.length} allievi',
          style: textTheme.labelMedium?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.68),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (sidebarMode)
          Expanded(child: listBody)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: listBody,
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, sidebarMode ? 12 : 0),
      child: column,
    );
  }
}

class _StudentAccessCard extends StatelessWidget {
  const _StudentAccessCard({
    required this.profile,
    required this.textTheme,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final StudentProfile profile;
  final TextTheme textTheme;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;

  @override
  Widget build(BuildContext context) {
    final contactParts = <String>[
      if (profile.phone != null && profile.phone!.trim().isNotEmpty)
        InternationalPhoneRules.formatForDisplay(
          profile.phone,
          phoneCountryIso2: profile.phoneCountryIso2,
        ),
      if (profile.email != null && profile.email!.trim().isNotEmpty)
        profile.email!.trim(),
    ];
    final pathLabel = BackofficeFormatters.enrollmentCoursePath(
      profile.enrolledCoursePath,
    );
    final categoryLabel = BackofficeFormatters.categoryName(
      profile.enrolledLicenseCategory,
    );

    final borderColor = selected
        ? _primaryColor.withValues(alpha: 0.55)
        : AppVisual.border.withValues(alpha: 0.72);
    final backgroundColor = selected
        ? _primaryColor.withValues(alpha: 0.07)
        : _cardColor;

    return Material(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: _primaryColor.withValues(alpha: 0.06),
        splashColor: _primaryColor.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _primaryColor.withValues(alpha: 0.12),
                foregroundColor: _primaryColor,
                child: Text(
                  _initials(profile.displayName),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _textPrimaryColor,
                        height: 1.2,
                      ),
                    ),
                    if (contactParts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        contactParts.join(' · '),
                        style: textTheme.bodyMedium?.copyWith(
                          color: _textPrimaryColor.withValues(alpha: 0.78),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          label: pathLabel,
                          accent: _primaryColor,
                          textTheme: textTheme,
                        ),
                        _InfoChip(
                          label: categoryLabel,
                          accent: const Color(0xFF2E9E5B),
                          textTheme: textTheme,
                        ),
                        if (profile.practiceDossierType != null)
                          _InfoChip(
                            label:
                                BackofficeFormatters.studentListPracticeBadge(
                                  profile,
                                ),
                            accent: const Color(0xFFC27C1C),
                            textTheme: textTheme,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _textPrimaryColor.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.accent,
    required this.textTheme,
  });

  final String label;
  final Color accent;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          color: AppVisual.ink.withValues(alpha: 0.88),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.value, required this.onChanged});

  final LicenseCategoryId value;
  final void Function(LicenseCategoryId?) onChanged;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppVisual.border.withValues(alpha: 0.72)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LicenseCategoryId>(
          isExpanded: true,
          value: value,
          items: LicenseCatalog.all
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    c.name,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _VelaAdminBlockedPanel extends StatelessWidget {
  const _VelaAdminBlockedPanel({
    required this.textTheme,
    required this.detailLine,
  });

  final TextTheme textTheme;
  final String detailLine;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppVisual.border.withValues(alpha: 0.72)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sailing_rounded,
                    color: _primaryColor.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Contenuti vela in preparazione',
                      style: textTheme.titleSmall?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Disponibile prossimamente. Non è possibile assegnare schede o abilitare '
                'flussi finché il catalogo vela non è pubblicato.',
                style: textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.82),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detailLine,
                style: textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.72),
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonSheetsTab extends StatelessWidget {
  const _LessonSheetsTab({
    required this.view,
    required this.categoryId,
    required this.textTheme,
    required this.busyLessonNumbers,
    required this.optimisticLessonUnlock,
    required this.onApplyWholeLesson,
  });

  final StudentAdmin360View view;
  final LicenseCategoryId categoryId;
  final TextTheme textTheme;
  final Set<int> busyLessonNumbers;
  final Map<int, bool> optimisticLessonUnlock;
  final Future<void> Function({
    required int lessonNumber,
    required int quizSheets,
    required bool unlocked,
  })
  onApplyWholeLesson;

  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final category = LicenseCatalog.byId(categoryId);

    if (!category.isAvailable || category.lessons.isEmpty) {
      if (categoryId == LicenseCategoryId.vela) {
        return _VelaAdminBlockedPanel(
          textTheme: textTheme,
          detailLine:
              'Scheda “Schede”: nessuna lezione da sbloccare finché il programma vela non è operativo.',
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessuna lezione nel catalogo per questa categoria.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: _textPrimaryColor),
          ),
        ),
      );
    }

    final lessons = category.lessons
        .where((l) => l.quizSheets > 0)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Text(
          'Verde = lezione sbloccata · Rosso = bloccata · Arancione = stato parziale. '
          'Un tap aggiorna tutte le schede della lezione.',
          style: textTheme.bodySmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.75),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        LessonStudyAccessSummaryPills(
          sheetUnlocks: view.studyProgress.sheetUnlocks,
          categoryId: categoryId,
        ),
        const SizedBox(height: 12),
        ...lessons.map((lesson) {
          final saving = busyLessonNumbers.contains(lesson.number);
          final optimistic = optimisticLessonUnlock[lesson.number];
          final status = resolveLessonSheetAccessStatus(
            sheetUnlocks: view.studyProgress.sheetUnlocks,
            categoryId: categoryId,
            lessonNumber: lesson.number,
            quizSheets: lesson.quizSheets,
            optimisticUnlocked: saving ? optimistic : null,
          );
          final targetUnlock = !status.isUnlockedForAction;

          return LessonStudyAccessLessonCard(
            lessonTitle: lesson.title,
            status: status,
            saving: saving,
            onPrimaryAction: () => onApplyWholeLesson(
              lessonNumber: lesson.number,
              quizSheets: lesson.quizSheets,
              unlocked: targetUnlock,
            ),
          );
        }),
      ],
    );
  }
}

class _ExamTab extends StatelessWidget {
  const _ExamTab({
    required this.view,
    required this.categoryId,
    required this.textTheme,
    required this.actionBusy,
    required this.onSetExamUnlocked,
  });

  final StudentAdmin360View view;
  final LicenseCategoryId categoryId;
  final TextTheme textTheme;
  final bool actionBusy;
  final Future<void> Function(bool unlocked) onSetExamUnlocked;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final category = LicenseCatalog.byId(categoryId);

    if (categoryId == LicenseCategoryId.vela) {
      return _VelaAdminBlockedPanel(
        textTheme: textTheme,
        detailLine:
            'Scheda “Esame”: il quiz esame vela non può essere abilitato finché i contenuti non sono pronti.',
      );
    }

    final list = view.studyProgress.examAccessByCategory;
    final ix = list.indexWhere((e) => e.categoryId == categoryId);
    final unlocked = ix >= 0 ? list[ix].examUnlocked : false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: unlocked
                ? _successColor.withValues(alpha: 0.12)
                : AppVisual.chipFill.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppVisual.border.withValues(alpha: 0.72)),
          ),
          child: Text(
            unlocked
                ? 'Stato: quiz esame attivo per ${category.name}'
                : 'Stato: quiz esame disattivato — assegna quando lo studente è pronto',
            style: textTheme.labelMedium?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppVisual.border.withValues(alpha: 0.65)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz esame — ${category.name}',
                  style: textTheme.titleSmall?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'La simulazione esame non è mai “automatica”: solo la scuola può abilitarla.',
                  style: textTheme.bodySmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.78),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    unlocked ? 'Sbloccato per lo studente' : 'Bloccato',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    unlocked
                        ? 'Quiz esame disponibile (stato: attivo).'
                        : 'Quiz esame disponibile solo dopo assegnazione scuola.',
                    style: textTheme.bodySmall,
                  ),
                  value: unlocked,
                  activeTrackColor: _successColor.withValues(alpha: 0.55),
                  onChanged: actionBusy ? null : onSetExamUnlocked,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorReviewTab extends StatelessWidget {
  const _ErrorReviewTab({
    required this.view,
    required this.categoryId,
    required this.textTheme,
    required this.actionBusy,
    required this.onSetTopic,
    required this.onOpenDialog,
  });

  final StudentAdmin360View view;
  final LicenseCategoryId categoryId;
  final TextTheme textTheme;
  final bool actionBusy;
  final Future<void> Function({
    required int lessonNumber,
    required bool topicUnlocked,
    String? didacticNote,
  })
  onSetTopic;
  final VoidCallback onOpenDialog;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final category = LicenseCatalog.byId(categoryId);

    if (categoryId == LicenseCategoryId.vela) {
      return _VelaAdminBlockedPanel(
        textTheme: textTheme,
        detailLine:
            'Scheda “Ripasso”: nessun argomento da gestire finché non ci sono dati quiz vela.',
      );
    }

    if (!category.isAvailable || category.lessons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessuna lezione nel catalogo per questa categoria.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: _textPrimaryColor),
          ),
        ),
      );
    }

    final assignments = view.studyProgress.errorReviewAssignments
        .where((e) => e.categoryId == categoryId)
        .toList(growable: false);
    var unlockedCount = 0;
    for (final a in assignments) {
      if (a.topicUnlocked) unlockedCount++;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _SummaryChips(
          textTheme: textTheme,
          chips: [
            ('Ripasso sbloccato', unlockedCount, _successColor),
            (
              'In attesa',
              assignments.length - unlockedCount,
              _textPrimaryColor,
            ),
            ('Assegnazioni', assignments.length, _primaryColor),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Gestisci il ripasso errori per lezione in base alle assegnazioni salvate '
          'per questo allievo. Le statistiche quiz reali arriveranno in una fase successiva.',
          style: textTheme.bodySmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.75),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onOpenDialog,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Apri gestione ripasso (come Scheda 360)'),
          ),
        ),
        const SizedBox(height: 12),
        ...category.lessons.map((lesson) {
          ErrorReviewTopicAssignment? row;
          for (final e in assignments) {
            if (e.lessonNumber == lesson.number) {
              row = e;
              break;
            }
          }
          final open = row?.topicUnlocked ?? false;
          final hasRow = row != null;

          return Card(
            color: _cardColor,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppVisual.border.withValues(alpha: 0.65)),
            ),
            child: SwitchListTile.adaptive(
              title: Text(
                'Lezione ${lesson.number}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    lesson.title,
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    open
                        ? 'Materiale ripasso disponibile per lo studente'
                        : hasRow
                        ? 'Assegnazione presente ma ripasso disattivato'
                        : 'Nessuna assegnazione — attiva per abilitare il ripasso',
                    style: textTheme.bodySmall?.copyWith(
                      color: open ? _successColor : _primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              value: open,
              activeTrackColor: _successColor.withValues(alpha: 0.55),
              onChanged: actionBusy
                  ? null
                  : (v) => onSetTopic(
                      lessonNumber: lesson.number,
                      topicUnlocked: v,
                      didacticNote: row?.didacticNote,
                    ),
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({required this.textTheme, required this.chips});

  final TextTheme textTheme;
  final List<(String label, int count, Color accent)> chips;

  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.$3.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppVisual.border.withValues(alpha: 0.72),
                ),
              ),
              child: Text(
                '${c.$1}: ${c.$2}',
                style: textTheme.labelMedium?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
