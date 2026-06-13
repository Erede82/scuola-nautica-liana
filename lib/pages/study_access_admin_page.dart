import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../data/license_catalog.dart';
import '../domain/backoffice/backoffice.dart';
import '../models/license_models.dart';
import '../repositories/backoffice/backoffice_registry.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/backoffice/backoffice_formatters.dart';
import '../widgets/backoffice/student_backoffice_dialogs.dart';

/// Schermata segreteria per gestire gli accessi studio per allievo (schede, esame, ripasso).
class StudyAccessAdminPage extends StatefulWidget {
  const StudyAccessAdminPage({super.key, this.embedded = false});

  final bool embedded;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

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
  bool _actionBusy = false;

  LicenseCategoryId _categoryId = LicenseCategoryId.motore;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() => setState(() {}));
    _loadProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final list = await backofficeRepository.listStudentProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = list;
        _listLoading = false;
      });
    } catch (e, st) {
      debugPrint('StudyAccessAdminPage._loadProfiles: $e\n$st');
      if (!mounted) return;
      setState(() {
        _listError = e;
        _listLoading = false;
      });
    }
  }

  Future<void> _loadStudentDetail(StudentId studentId) async {
    setState(() {
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final fresh = await backofficeRepository.getStudentAdmin360(studentId);
      if (!mounted) return;
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
      setState(() {
        _detailError = e;
        _view = null;
        _detailLoading = false;
      });
    }
  }

  Future<void> _selectStudent(StudentId id) async {
    setState(() {
      _selectedStudentId = id;
      _view = null;
    });
    await _loadStudentDetail(id);
  }

  void _clearStudentSelection() {
    setState(() {
      _selectedStudentId = null;
      _view = null;
      _detailError = null;
    });
  }

  Future<void> _refreshView() async {
    final id = _selectedStudentId;
    if (id == null) return;
    await _loadStudentDetail(id);
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

  Future<void> _runWrite(Future<void> Function() action, String success) async {
    if (_actionBusy || _selectedStudentId == null) return;
    setState(() => _actionBusy = true);
    try {
      await action();
      await _refreshView();
      if (mounted) _snack(success);
    } catch (e, st) {
      debugPrint('StudyAccessAdminPage write: $e\n$st');
      if (mounted) _snack('Errore: ${_formatWriteError(e)}');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _applyWholeLesson({
    required int lessonNumber,
    required int quizSheets,
    required bool unlocked,
  }) async {
    final view = _view;
    if (view == null) return;
    final studentId = view.profile.id;
    await _runWrite(() async {
      for (var s = 1; s <= quizSheets; s++) {
        await backofficeRepository.setLessonSheetUnlocked(
          studentId: studentId,
          categoryId: _categoryId,
          lessonNumber: lessonNumber,
          sheetNumber: s,
          unlocked: unlocked,
        );
      }
    }, unlocked ? 'Intera lezione sbloccata.' : 'Intera lezione bloccata.');
  }

  Future<void> _setExamUnlocked(bool unlocked) async {
    final view = _view;
    if (view == null) return;
    await _runWrite(
      () => backofficeRepository.setExamQuizAccessForCategory(
        studentId: view.profile.id,
        categoryId: _categoryId,
        examUnlocked: unlocked,
      ),
      'Accesso quiz esame aggiornato.',
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
      () => backofficeRepository.setErrorReviewTopicAssignment(
        studentId: view.profile.id,
        categoryId: _categoryId,
        lessonNumber: lessonNumber,
        topicUnlocked: topicUnlocked,
        didacticNote: didacticNote,
      ),
      'Ripasso errori aggiornato.',
    );
  }

  List<StudentProfile> get _filteredProfiles {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _profiles;
    return _profiles.where((p) {
      if (p.displayName.toLowerCase().contains(q)) return true;
      if (p.phone != null && p.phone!.toLowerCase().contains(q)) return true;
      if (p.email != null && p.email!.toLowerCase().contains(q)) return true;
      return false;
    }).toList(growable: false);
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
              bottom: _selectedStudentId != null && _view != null
                  ? _buildTabBar()
                  : null,
            ),
      body: Column(
        children: [
          if (widget.embedded &&
              _selectedStudentId != null &&
              _view != null)
            Material(
              color: StudyAccessAdminPage._primaryColor,
              child: _buildTabBar(),
            ),
          _InternalHeader(textTheme: textTheme),
          _StudentPickerSection(
            textTheme: textTheme,
            searchCtrl: _searchCtrl,
            listLoading: _listLoading,
            listError: _listError,
            profiles: _filteredProfiles,
            selectedProfile: _selectedProfile,
            selectedStudentId: _selectedStudentId,
            onRetryList: _loadProfiles,
            onSelect: _selectStudent,
            onClearSelection: _clearStudentSelection,
          ),
          if (_detailLoading)
            const LinearProgressIndicator(minHeight: 2),
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
          if (_selectedStudentId == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Seleziona un allievo per gestire lezioni, quiz esame e ripasso errori.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppVisual.ink.withValues(alpha: 0.78),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            )
          else if (_view != null) ...[
            Padding(
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
                    actionBusy: _actionBusy,
                    onApplyWholeLesson: _applyWholeLesson,
                  ),
                  _ExamTab(
                    view: _view!,
                    categoryId: _categoryId,
                    textTheme: textTheme,
                    actionBusy: _actionBusy,
                    onSetExamUnlocked: _setExamUnlocked,
                  ),
                  _ErrorReviewTab(
                    view: _view!,
                    categoryId: _categoryId,
                    textTheme: textTheme,
                    actionBusy: _actionBusy,
                    onSetTopic: _setErrorReviewTopic,
                    onOpenDialog: () => showErrorReviewAssignDialog(
                      context,
                      initialView: _view!,
                      repository: backofficeRepository,
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
          ] else if (!_detailLoading)
            Expanded(
              child: Center(
                child: Text(
                  'Impossibile caricare lo stato studio dell’allievo.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
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
    required this.textTheme,
    required this.searchCtrl,
    required this.listLoading,
    required this.listError,
    required this.profiles,
    required this.selectedProfile,
    required this.selectedStudentId,
    required this.onRetryList,
    required this.onSelect,
    required this.onClearSelection,
  });

  final TextTheme textTheme;
  final TextEditingController searchCtrl;
  final bool listLoading;
  final Object? listError;
  final List<StudentProfile> profiles;
  final StudentProfile? selectedProfile;
  final StudentId? selectedStudentId;
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
              style: textTheme.bodySmall?.copyWith(color: const Color(0xFFC62828)),
            ),
            TextButton(onPressed: onRetryList, child: const Text('Riprova')),
          ],
        ),
      );
    }

    if (selectedProfile != null) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cerca per nome, telefono o email',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: _cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: profiles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nessun allievo corrisponde alla ricerca.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.75),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
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
                  ),
          ),
        ],
      ),
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
        profile.phone!.trim(),
      if (profile.email != null && profile.email!.trim().isNotEmpty)
        profile.email!.trim(),
    ];
    final pathLabel =
        BackofficeFormatters.enrollmentCoursePath(profile.enrolledCoursePath);
    final categoryLabel =
        BackofficeFormatters.categoryName(profile.enrolledLicenseCategory);

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
                            label: BackofficeFormatters.studentListPracticeBadge(
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

bool _lessonUnlockRowsMixedInAggregate(
  StudentAdmin360View agg,
  LicenseCategoryId categoryId,
  int lessonNumber,
  int quizSheets,
) {
  var anyTrue = false;
  var anyFalse = false;
  for (var s = 1; s <= quizSheets; s++) {
    final on = _sheetUnlockedInAggregate(
      agg,
      categoryId,
      lessonNumber,
      s,
    );
    if (on) {
      anyTrue = true;
    } else {
      anyFalse = true;
    }
  }
  return anyTrue && anyFalse;
}

bool _lessonHasAnySheetUnlockedInAggregate(
  StudentAdmin360View agg,
  LicenseCategoryId categoryId,
  int lessonNumber,
  int quizSheets,
) {
  for (var s = 1; s <= quizSheets; s++) {
    if (_sheetUnlockedInAggregate(agg, categoryId, lessonNumber, s)) {
      return true;
    }
  }
  return false;
}

bool _sheetUnlockedInAggregate(
  StudentAdmin360View agg,
  LicenseCategoryId categoryId,
  int lessonNumber,
  int sheetNumber,
) {
  for (final e in agg.studyProgress.sheetUnlocks) {
    if (e.categoryId == categoryId &&
        e.lessonNumber == lessonNumber &&
        e.sheetNumber == sheetNumber) {
      return e.unlocked;
    }
  }
  return false;
}

int _explicitSheetUnlockCounts(
  StudentAdmin360View agg,
  LicenseCategoryId categoryId,
  int lessonNumber,
  int quizSheets,
) {
  var explicitTrue = 0;
  var explicitFalse = 0;
  for (var s = 1; s <= quizSheets; s++) {
    LessonQuizSheetUnlock? row;
    for (final e in agg.studyProgress.sheetUnlocks) {
      if (e.categoryId == categoryId &&
          e.lessonNumber == lessonNumber &&
          e.sheetNumber == s) {
        row = e;
        break;
      }
    }
    if (row != null) {
      if (row.unlocked) {
        explicitTrue++;
      } else {
        explicitFalse++;
      }
    }
  }
  return explicitTrue + explicitFalse;
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
    required this.actionBusy,
    required this.onApplyWholeLesson,
  });

  final StudentAdmin360View view;
  final LicenseCategoryId categoryId;
  final TextTheme textTheme;
  final bool actionBusy;
  final Future<void> Function({
    required int lessonNumber,
    required int quizSheets,
    required bool unlocked,
  }) onApplyWholeLesson;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _successColor = Color(0xFF2E9E5B);

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

    var totalSheets = 0;
    var unlockedSheets = 0;
    for (final lesson in category.lessons) {
      final n = lesson.quizSheets;
      totalSheets += n;
      for (var s = 1; s <= n; s++) {
        if (_sheetUnlockedInAggregate(view, categoryId, lesson.number, s)) {
          unlockedSheets++;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _SummaryChips(
          textTheme: textTheme,
          chips: [
            ('Sbloccate', unlockedSheets, _successColor),
            ('Bloccate', totalSheets - unlockedSheets, _textPrimaryColor),
            ('Totale schede', totalSheets, _primaryColor),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Nell’app allievo basta un sblocco su una scheda della lezione perché risulti '
          'accessibile l’intera lezione (tutte le schede). Qui imposti le lezioni per intero: '
          'ogni azione aggiorna tutte le righe scheda coerenti con il catalogo.',
          style: textTheme.bodySmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.75),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ...category.lessons.map((lesson) {
          if (lesson.quizSheets == 0) return const SizedBox.shrink();

          final storedMixed = _lessonUnlockRowsMixedInAggregate(
            view,
            categoryId,
            lesson.number,
            lesson.quizSheets,
          );
          final studentSeesLesson = _lessonHasAnySheetUnlockedInAggregate(
            view,
            categoryId,
            lesson.number,
            lesson.quizSheets,
          );
          final explicitRows = _explicitSheetUnlockCounts(
            view,
            categoryId,
            lesson.number,
            lesson.quizSheets,
          );

          String statusLine;
          if (storedMixed) {
            statusLine =
                'Anagrafica sblocchi non uniforme tra le schede — uniforma con i pulsanti sotto.';
          } else if (studentSeesLesson) {
            statusLine =
                'Per l’allievo: lezione accessibile (tutte le schede quiz).';
          } else {
            statusLine =
                'Per l’allievo: lezione non accessibile (tutte le schede quiz bloccate).';
          }

          return Card(
            color: _cardColor,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppVisual.border.withValues(alpha: 0.65)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: textTheme.titleSmall?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lesson.quizSheets} schede nel catalogo',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusLine,
                    style: textTheme.bodySmall?.copyWith(
                      color: storedMixed
                          ? const Color(0xFFC27C1C)
                          : _textPrimaryColor.withValues(alpha: 0.82),
                      height: 1.4,
                      fontWeight:
                          storedMixed ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (explicitRows > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Righe impostate in anagrafica: $explicitRows su ${lesson.quizSheets}',
                      style: textTheme.labelSmall?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _successColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: actionBusy
                            ? null
                            : () => onApplyWholeLesson(
                                  lessonNumber: lesson.number,
                                  quizSheets: lesson.quizSheets,
                                  unlocked: true,
                                ),
                        icon: const Icon(Icons.lock_open_rounded, size: 20),
                        label: const Text('Sblocca tutta la lezione'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimaryColor,
                        ),
                        onPressed: actionBusy
                            ? null
                            : () => onApplyWholeLesson(
                                  lessonNumber: lesson.number,
                                  quizSheets: lesson.quizSheets,
                                  unlocked: false,
                                ),
                        icon: const Icon(Icons.lock_rounded, size: 20),
                        label: const Text('Blocca tutta la lezione'),
                      ),
                    ],
                  ),
                ],
              ),
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
  }) onSetTopic;
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
