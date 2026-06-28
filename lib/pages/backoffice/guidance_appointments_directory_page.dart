import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_registry.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import '../../utils/guidance_appointment_validation.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';
import '../../widgets/backoffice/backoffice_ui_tokens.dart';
import '../../widgets/backoffice/student_backoffice_dialogs.dart';
import '../../theme/app_visual_tokens.dart';

/// Agenda guide pratiche in mare — vista settimanale + Scheda 360.
class GuidanceAppointmentsDirectoryPage extends StatefulWidget {
  const GuidanceAppointmentsDirectoryPage({
    super.key,
    this.embedded = false,
    required this.onOpenStudent360,
    this.repository,
  });

  final bool embedded;
  final ValueChanged<StudentId> onOpenStudent360;
  final BackofficeRepository? repository;

  @override
  State<GuidanceAppointmentsDirectoryPage> createState() =>
      _GuidanceAppointmentsDirectoryPageState();
}

class _GuidanceAppointmentsDirectoryPageState
    extends State<GuidanceAppointmentsDirectoryPage> {
  final _searchCtrl = TextEditingController();

  List<GuidanceListItem>? _items;
  Object? _error;
  bool _loading = true;

  bool _onlyFuture = false;
  bool _onlyPast = false;

  /// Lunedì della settimana visualizzata (solo data locale).
  late DateTime _weekMonday = _mondayOf(DateTime.now());

  static DateTime _mondayOf(DateTime ref) {
    final d = DateTime(ref.year, ref.month, ref.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static const int _agendaStartHour = 8;
  static const int _agendaEndHour = 20;
  static const double _hourHeight = 48;
  static const double _compactToolbarBreakpoint = 600;
  static const double _sidePanelBreakpoint = 900;
  static const double _sidePanelWidth = 400;
  static const double _fabBottomClearance = 76;

  BackofficeRepository get _repository =>
      widget.repository ?? backofficeRepository;

  /// Cache locale allievi — precaricata con l’agenda per aprire il form subito.
  List<StudentProfile>? _studentProfiles;

  bool _newGuidePanelOpen = false;
  bool _newGuideSheetOpen = false;
  bool _savingNewGuide = false;
  AgendaSeaPracticeSlotSeed? _newGuideSlot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _onlyFuture = false;
      _onlyPast = false;
    });
  }

  void _goToday() {
    setState(() => _weekMonday = _mondayOf(DateTime.now()));
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _weekMonday = _weekMonday.add(Duration(days: 7 * deltaWeeks));
    });
  }

  Future<void> _onAgendaBlockTap(GuidanceListItem item) async {
    final action = await showAgendaGuidanceBlockActions(context, item: item);
    if (!mounted || action == null) return;
    switch (action) {
      case AgendaGuidanceBlockAction.open360:
        widget.onOpenStudent360(item.studentId);
      case AgendaGuidanceBlockAction.edit:
        await _editGuide(item);
      case AgendaGuidanceBlockAction.delete:
        await showDeleteGuidanceAppointmentDialog(
          context,
          item: item,
          repository: _repository,
          onSaved: _load,
        );
    }
  }

  Future<List<StudentProfile>> _studentProfilesForDialog() async {
    final cached = _studentProfiles;
    if (cached != null) return cached;
    final profiles = await _repository.listStudentProfiles();
    if (mounted) {
      setState(() => _studentProfiles = profiles);
    }
    return profiles;
  }

  Future<void> _editGuide(GuidanceListItem item) async {
    if (_newGuidePanelOpen) {
      setState(() => _newGuidePanelOpen = false);
    }
    try {
      final profiles = await _studentProfilesForDialog();
      if (!mounted) return;
      await showEditAgendaSeaPracticeDialog(
        context,
        item: item,
        students: profiles,
        repository: _repository,
        onSaved: _load,
      );
    } catch (e, st) {
      debugPrint('_editGuide: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire la modifica: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _useSidePanel(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= _sidePanelBreakpoint;
  }

  void _closeNewGuidePanel() {
    if (_newGuidePanelOpen || _newGuideSlot != null) {
      setState(() {
        _newGuidePanelOpen = false;
        _newGuideSlot = null;
      });
    }
  }

  Key _newGuideFormKey() {
    final slot = _newGuideSlot;
    if (slot == null) return const ValueKey('new-guide-no-slot');
    return ValueKey(
      'new-guide-${slot.day.year}-${slot.day.month}-${slot.day.day}-${slot.startHour}',
    );
  }

  Future<void> _openNewGuideAtSlot(DateTime day, int hour) async {
    if (_loading) return;
    try {
      final profiles = await _studentProfilesForDialog();
      if (!mounted) return;
      if (profiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun allievo registrato.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final seed = (
        day: DateTime(day.year, day.month, day.day),
        startHour: hour,
      );

      if (_useSidePanel(context)) {
        setState(() {
          _newGuideSlot = seed;
          _newGuidePanelOpen = true;
        });
        return;
      }

      await _openNewGuideBottomSheet(profiles, initialSlot: seed);
    } catch (e, st) {
      debugPrint('_openNewGuideAtSlot: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire il modulo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleNewGuideSave(AgendaSeaPracticeResult result) async {
    setState(() => _savingNewGuide = true);
    final outcome = await persistNewAgendaSeaPractice(
      context: context,
      repository: _repository,
      result: result,
      onSaved: _load,
    );
    if (!mounted) return;
    setState(() => _savingNewGuide = false);
    if (outcome == AgendaSeaPracticePersistOutcome.success) {
      _closeNewGuidePanel();
    }
  }

  Future<void> _openNewGuideBottomSheet(
    List<StudentProfile> profiles, {
    AgendaSeaPracticeSlotSeed? initialSlot,
  }) async {
    setState(() {
      _newGuideSheetOpen = true;
      _newGuideSlot = initialSlot;
    });
    final sorted = sortAgendaSeaPracticeStudents(profiles);
    final formKey = initialSlot == null
        ? const ValueKey('new-guide-sheet-no-slot')
        : ValueKey(
            'new-guide-sheet-${initialSlot.day.year}-'
            '${initialSlot.day.month}-${initialSlot.day.day}-'
            '${initialSlot.startHour}',
          );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.62,
              minChildSize: 0.38,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return AgendaSeaPracticeFormPanel(
                  key: formKey,
                  students: sorted,
                  initialSlot: initialSlot,
                  scrollController: scrollController,
                  isSaving: saving,
                  onCancel: () => Navigator.pop(sheetContext),
                  onSave: (result) async {
                    setSheetState(() => saving = true);
                    final outcome = await persistNewAgendaSeaPractice(
                      context: context,
                      repository: _repository,
                      result: result,
                      onSaved: _load,
                    );
                    if (!context.mounted) return;
                    setSheetState(() => saving = false);
                    if (outcome == AgendaSeaPracticePersistOutcome.success &&
                        sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        _newGuideSheetOpen = false;
        _newGuideSlot = null;
      });
    }
  }

  Future<void> _openNewSeaLesson() async {
    try {
      final profiles = await _studentProfilesForDialog();
      if (!mounted) return;
      if (profiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun allievo registrato.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_useSidePanel(context)) {
        setState(() {
          if (_newGuidePanelOpen) {
            _newGuidePanelOpen = false;
            _newGuideSlot = null;
          } else {
            _newGuidePanelOpen = true;
            _newGuideSlot = null;
          }
        });
        return;
      }

      await _openNewGuideBottomSheet(profiles);
    } catch (e, st) {
      debugPrint('_openNewSeaLesson: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire il modulo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appointmentsFuture = _repository.listGuidanceAppointments();
      final profilesFuture = Future<List<StudentProfile>>.sync(
            _repository.listStudentProfiles,
          )
          .then<List<StudentProfile>?>((profiles) => profiles)
          .catchError((Object e, StackTrace st) {
            debugPrint(
              'GuidanceAppointmentsDirectoryPage student preload: $e\n$st',
            );
            return null;
          });
      final appointments = await appointmentsFuture;
      final profiles = await profilesFuture;
      if (!mounted) return;
      setState(() {
        _items = appointments;
        if (profiles != null) {
          _studentProfiles = profiles;
        }
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('GuidanceAppointmentsDirectoryPage load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _items = null;
      });
    }
  }

  Iterable<GuidanceListItem> _filtered(List<GuidanceListItem> raw) sync* {
    final q = _searchCtrl.text.trim().toLowerCase();
    for (final i in raw) {
      if (i.lessonType != GuidanceLessonType.practiceSea) continue;
      if (_onlyFuture && !i.isLessonInFuture) continue;
      if (_onlyPast && !i.isLessonInPast) continue;
      if (q.isNotEmpty) {
        final note = i.notes?.toLowerCase() ?? '';
        final match =
            i.studentFullName.toLowerCase().contains(q) ||
            (i.studentEmail?.toLowerCase().contains(q) ?? false) ||
            (i.studentPhone?.toLowerCase().contains(q) ?? false) ||
            (i.instructorName?.toLowerCase().contains(q) ?? false) ||
            note.contains(q);
        if (!match) continue;
      }
      yield i;
    }
  }

  List<GuidanceListItem> _itemsInWeek(List<GuidanceListItem> filtered) {
    final weekEnd = _weekMonday.add(const Duration(days: 7));
    return filtered
        .where((i) {
          final day = DateTime(
            i.lessonDate.year,
            i.lessonDate.month,
            i.lessonDate.day,
          );
          return !day.isBefore(_weekMonday) && day.isBefore(weekEnd);
        })
        .toList(growable: false);
  }

  String _weekRangeLabel() {
    final sunday = _weekMonday.add(const Duration(days: 6));
    final sameMonth = _weekMonday.month == sunday.month;
    if (sameMonth) {
      return '${_weekMonday.day}–${sunday.day} '
          '${_monthShort(_weekMonday.month)} ${_weekMonday.year}';
    }
    return '${_weekMonday.day} ${_monthShort(_weekMonday.month)} – '
        '${sunday.day} ${_monthShort(sunday.month)} ${_weekMonday.year}';
  }

  static String _monthShort(int m) {
    const names = [
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];
    return names[m - 1];
  }

  static String _weekdayShort(int weekday) {
    const names = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    return names[weekday - 1];
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      decoration: const InputDecoration(
        hintText: 'Cerca allievo, istruttore, note…',
        border: OutlineInputBorder(),
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton.filledTonal(
      onPressed: _loading ? null : _load,
      icon: const Icon(Icons.refresh_rounded),
      tooltip: 'Aggiorna agenda',
    );
  }

  Widget _buildNewGuideButton({required bool panelOpen}) {
    return FilledButton.icon(
      onPressed: _loading ? null : _openNewSeaLesson,
      icon: Icon(
        panelOpen ? Icons.close_rounded : Icons.add_circle_outline,
        size: 20,
      ),
      label: Text(panelOpen ? 'Chiudi' : 'Nuova guida'),
    );
  }

  Widget _buildSearchToolbar({required bool compact, required bool panelOpen}) {
    final padding = const EdgeInsets.fromLTRB(16, 10, 16, 6);
    if (compact) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: _buildSearchField()),
            const SizedBox(width: 8),
            _buildRefreshButton(),
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 8),
          _buildNewGuideButton(panelOpen: panelOpen),
          const SizedBox(width: 6),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildNewGuideFab() {
    return FloatingActionButton.extended(
      onPressed: _loading ? null : _openNewSeaLesson,
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('Nuova guida'),
      backgroundColor: AppVisual.logoBlue,
      foregroundColor: Colors.white,
      elevation: 3,
    );
  }

  Widget _buildNewGuideSidePanel(List<StudentProfile> profiles) {
    return Material(
      color: AppVisual.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppVisual.border.withValues(alpha: 0.78)),
          ),
        ),
        child: SizedBox(
          width: _sidePanelWidth,
          child: AgendaSeaPracticeFormPanel(
            key: _newGuideFormKey(),
            students: sortAgendaSeaPracticeStudents(profiles),
            initialSlot: _newGuideSlot,
            isSaving: _savingNewGuide,
            onCancel: _closeNewGuidePanel,
            onSave: _handleNewGuideSave,
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaArea(TextTheme textTheme, {required bool showFab}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(bottom: showFab ? _fabBottomClearance : 0),
            child: _buildBody(textTheme),
          ),
        ),
        if (showFab)
          Positioned(
            right: 16,
            bottom: 12,
            child: SafeArea(top: false, child: _buildNewGuideFab()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < _compactToolbarBreakpoint;
    final useSidePanel = width >= _sidePanelBreakpoint;
    final showSidePanel = useSidePanel && _newGuidePanelOpen;
    final showFab = compact && !_newGuideSheetOpen && !_newGuidePanelOpen;
    final profiles = _studentProfiles ?? const <StudentProfile>[];

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
                  'Guide / Agenda',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          _buildSearchToolbar(compact: compact, panelOpen: showSidePanel),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Settimana precedente',
                ),
                Text(
                  _weekRangeLabel(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Settimana successiva',
                ),
                TextButton(onPressed: _goToday, child: const Text('Oggi')),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Future'),
                  visualDensity: VisualDensity.compact,
                  selected: _onlyFuture,
                  onSelected: (v) => setState(() {
                    _onlyFuture = v;
                    if (v) _onlyPast = false;
                  }),
                ),
                FilterChip(
                  label: const Text('Passate'),
                  visualDensity: VisualDensity.compact,
                  selected: _onlyPast,
                  onSelected: (v) => setState(() {
                    _onlyPast = v;
                    if (v) _onlyFuture = false;
                  }),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Reimposta filtri'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: useSidePanel
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildAgendaArea(textTheme, showFab: false),
                      ),
                      if (showSidePanel && profiles.isNotEmpty)
                        _buildNewGuideSidePanel(profiles),
                    ],
                  )
                : _buildAgendaArea(textTheme, showFab: showFab),
          ),
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
          child: Text(
            'Impossibile caricare gli appuntamenti.\n$_error',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }

    final raw = _items ?? const <GuidanceListItem>[];
    final filtered = _filtered(raw).toList(growable: false);
    final weekItems = _itemsInWeek(filtered);

    final emptyHint = weekItems.isEmpty
        ? (filtered.isEmpty
              ? 'Nessuna guida in elenco — tocca uno slot per registrarne una.'
              : 'Nessuna guida in questa settimana — tocca uno slot o cambia settimana.')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (emptyHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              emptyHint,
              style: textTheme.bodySmall?.copyWith(
                color: AppVisual.inkMuted,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: _WeekAgendaGrid(
            weekMonday: _weekMonday,
            items: weekItems,
            startHour: _agendaStartHour,
            endHour: _agendaEndHour,
            hourHeight: _hourHeight,
            onBlockTap: _onAgendaBlockTap,
            onEmptySlotTap: _openNewGuideAtSlot,
          ),
        ),
      ],
    );
  }
}

class _WeekAgendaGrid extends StatelessWidget {
  const _WeekAgendaGrid({
    required this.weekMonday,
    required this.items,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.onBlockTap,
    this.onEmptySlotTap,
  });

  final DateTime weekMonday;
  final List<GuidanceListItem> items;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final ValueChanged<GuidanceListItem> onBlockTap;
  final void Function(DateTime day, int hour)? onEmptySlotTap;

  static const double _timeColWidth = 48;
  static const double _minDayColWidth = 108;
  static const double _dayHeaderHeight = 36;

  DateTime _effectiveStart(GuidanceListItem i) {
    if (i.startTime != null) return i.startTime!.toLocal();
    return DateTime(i.lessonDate.year, i.lessonDate.month, i.lessonDate.day, 9);
  }

  DateTime _effectiveEnd(GuidanceListItem i) {
    if (i.endTime != null) return i.endTime!.toLocal();
    return _effectiveStart(i).add(const Duration(hours: 1));
  }

  List<GuidanceListItem> _forDay(DateTime day) {
    final day0 = DateTime(day.year, day.month, day.day);
    return items
        .where((i) {
          final d = DateTime(
            i.lessonDate.year,
            i.lessonDate.month,
            i.lessonDate.day,
          );
          return d == day0;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalHours = endHour - startHour;
    final gridHeight = totalHours * hourHeight;
    final days = List.generate(7, (i) => weekMonday.add(Duration(days: i)));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, c) {
        final dayColWidth = (c.maxWidth - _timeColWidth - 32) / 7;
        final colW = dayColWidth < _minDayColWidth
            ? _minDayColWidth
            : dayColWidth;
        final scrollWide = colW * 7 + _timeColWidth + 16 > c.maxWidth;

        final gridWidth = scrollWide
            ? _timeColWidth + colW * 7
            : c.maxWidth - 16;

        final grid = DecoratedBox(
          decoration: BoxDecoration(
            color: AppVisual.surface,
            border: Border.all(color: AppVisual.border.withValues(alpha: 0.78)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: gridWidth,
              height: gridHeight + _dayHeaderHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _timeColWidth,
                    child: Column(
                      children: [
                        Container(
                          height: _dayHeaderHeight,
                          decoration: BoxDecoration(
                            color: AppVisual.canvas.withValues(alpha: 0.65),
                            border: Border(
                              bottom: BorderSide(
                                color: AppVisual.border.withValues(alpha: 0.72),
                              ),
                              right: BorderSide(
                                color: AppVisual.border.withValues(alpha: 0.72),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: gridHeight,
                          child: Column(
                            children: [
                              for (var h = startHour; h < endHour; h++)
                                _HourRowShell(
                                  hourHeight: hourHeight,
                                  hourIndex: h - startHour,
                                  isLastHour: h == endHour - 1,
                                  showRightBorder: true,
                                  rightBorderWidth: 1.5,
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        right: 6,
                                        top: 4,
                                      ),
                                      child: Text(
                                        '${h.toString().padLeft(2, '0')}:00',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: AppVisual.inkMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                    _DayColumn(
                      day: days[dayIndex],
                      dayIndex: dayIndex,
                      width: colW,
                      gridHeight: gridHeight,
                      startHour: startHour,
                      endHour: endHour,
                      hourHeight: hourHeight,
                      isToday:
                          days[dayIndex].year == todayDate.year &&
                          days[dayIndex].month == todayDate.month &&
                          days[dayIndex].day == todayDate.day,
                      items: _forDay(days[dayIndex]),
                      onEmptySlotTap: onEmptySlotTap,
                      positionBlock: (context, placement) => _positionedBlock(
                        context,
                        placement,
                        days[dayIndex],
                        colW,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: SingleChildScrollView(
            child: scrollWide
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: grid,
                  )
                : grid,
          ),
        );
      },
    );
  }

  static List<_DayAppointmentPlacement> _layoutDayAppointments(
    List<GuidanceListItem> items,
  ) {
    if (items.isEmpty) return const [];

    final sorted = List<GuidanceListItem>.from(items);
    sorted.sort((a, b) {
      final sa = guidanceEffectiveStart(a);
      final sb = guidanceEffectiveStart(b);
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
      return guidanceEffectiveEnd(b).compareTo(guidanceEffectiveEnd(a));
    });

    final laneEnds = <DateTime>[];
    final laneByItem = <GuidanceListItem, int>{};

    for (final item in sorted) {
      final start = guidanceEffectiveStart(item);
      final end = guidanceEffectiveEnd(item);
      var lane = 0;
      for (; lane < laneEnds.length; lane++) {
        if (!start.isBefore(laneEnds[lane])) break;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
      laneByItem[item] = lane;
    }

    return sorted
        .map((item) {
          final start = guidanceEffectiveStart(item);
          final end = guidanceEffectiveEnd(item);
          final lane = laneByItem[item]!;
          var laneCount = lane + 1;
          for (final other in sorted) {
            if (identical(other, item)) continue;
            final os = guidanceEffectiveStart(other);
            final oe = guidanceEffectiveEnd(other);
            if (guidanceIntervalsOverlap(start, end, os, oe)) {
              final otherLane = laneByItem[other]! + 1;
              if (otherLane > laneCount) laneCount = otherLane;
            }
          }
          return _DayAppointmentPlacement(
            item: item,
            lane: lane,
            laneCount: laneCount,
          );
        })
        .toList(growable: false);
  }

  Widget _positionedBlock(
    BuildContext context,
    _DayAppointmentPlacement placement,
    DateTime day,
    double columnWidth,
  ) {
    final item = placement.item;
    final start = _effectiveStart(item);
    final end = _effectiveEnd(item);
    final dayStart = DateTime(day.year, day.month, day.day, startHour);
    final dayEnd = DateTime(day.year, day.month, day.day, endHour);

    var blockStart = start.isBefore(dayStart) ? dayStart : start;
    var blockEnd = end.isAfter(dayEnd) ? dayEnd : end;
    if (!blockEnd.isAfter(blockStart)) {
      blockEnd = blockStart.add(const Duration(minutes: 30));
    }

    final topMinutes = blockStart.difference(dayStart).inMinutes.toDouble();
    final heightMinutes = blockEnd.difference(blockStart).inMinutes.toDouble();
    final top = (topMinutes / 60) * hourHeight;
    final height = ((heightMinutes / 60) * hourHeight).clamp(
      22.0,
      double.infinity,
    );

    final accent = switch (item.completionOutcome) {
      AppointmentCompletionOutcome.attended => const Color(0xFF15803D),
      AppointmentCompletionOutcome.absent => const Color(0xFFB45309),
      AppointmentCompletionOutcome.rescheduled => const Color(0xFF6B7280),
      AppointmentCompletionOutcome.pending =>
        item.isLessonInFuture
            ? const Color(0xFF1D4ED8)
            : item.isLessonInPast
            ? const Color(0xFF6B7280)
            : AppVisual.logoBlue,
    };

    final tooltipLines = <String>[
      item.studentFullName,
      if (item.startTime != null)
        '${_hm(start)}–${_hm(end)}'
      else
        BackofficeFormatters.dateUi(item.lessonDate),
      if (item.instructorName != null && item.instructorName!.trim().isNotEmpty)
        'Istruttore: ${item.instructorName!.trim()}',
      if (item.studentPhone != null && item.studentPhone!.trim().isNotEmpty)
        'Tel: ${item.studentPhone!.trim()}',
      if (item.notes != null && item.notes!.trim().isNotEmpty)
        item.notes!.trim(),
      'Esito: ${BackofficeFormatters.appointmentOutcome(item.completionOutcome)}',
    ];

    final showBadge = height >= 34 && placement.laneCount == 1;
    const blockInsetH = 5.0;
    const blockInsetV = 1.0;
    const laneGap = 2.0;
    final usableWidth = columnWidth - blockInsetH * 2;
    final laneWidth = usableWidth / placement.laneCount;
    final blockWidth = (laneWidth - laneGap).clamp(24.0, usableWidth);
    final blockLeft = blockInsetH + placement.lane * laneWidth + laneGap / 2;

    return Positioned(
      top: top + blockInsetV,
      left: blockLeft,
      width: blockWidth,
      height: (height - blockInsetV * 2).clamp(20.0, double.infinity),
      child: Tooltip(
        message: tooltipLines.join('\n'),
        waitDuration: const Duration(milliseconds: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Material(
            color: accent.withValues(alpha: 0.14),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onBlockTap(item),
              splashFactory: NoSplash.splashFactory,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accent.withValues(alpha: 0.62),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: showBadge
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  item.studentFullName,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: BackofficeUiTokens.text,
                                        height: 1,
                                        fontSize: blockWidth < 56 ? 9 : 11,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ),
                            _AgendaOutcomeBadge(
                              outcome: item.completionOutcome,
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.studentFullName,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: BackofficeUiTokens.text,
                                  height: 1,
                                  fontSize: blockWidth < 56 ? 9 : 10,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _hm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _DayAppointmentPlacement {
  const _DayAppointmentPlacement({
    required this.item,
    required this.lane,
    required this.laneCount,
  });

  final GuidanceListItem item;
  final int lane;
  final int laneCount;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.dayIndex,
    required this.width,
    required this.gridHeight,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.isToday,
    required this.items,
    this.onEmptySlotTap,
    required this.positionBlock,
  });

  final DateTime day;
  final int dayIndex;
  final double width;
  final double gridHeight;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final bool isToday;
  final List<GuidanceListItem> items;
  final void Function(DateTime day, int hour)? onEmptySlotTap;
  final Widget Function(
    BuildContext context,
    _DayAppointmentPlacement placement,
  )
  positionBlock;

  Color get _columnTint {
    if (isToday) {
      return AppVisual.logoBlue.withValues(alpha: 0.05);
    }
    return dayIndex.isEven
        ? AppVisual.surface
        : AppVisual.canvas.withValues(alpha: 0.42);
  }

  @override
  Widget build(BuildContext context) {
    final placements = _WeekAgendaGrid._layoutDayAppointments(items);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _columnTint,
          border: Border(
            right: BorderSide(color: AppVisual.border.withValues(alpha: 0.72)),
          ),
        ),
        child: Column(
          children: [
            _DayHeader(
              weekday: _GuidanceAppointmentsDirectoryPageState._weekdayShort(
                day.weekday,
              ),
              dayNum: day.day,
              isToday: isToday,
              backgroundColor: _columnTint,
            ),
            SizedBox(
              height: gridHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Column(
                    children: [
                      for (var h = startHour; h < endHour; h++)
                        _HourRowShell(
                          hourHeight: hourHeight,
                          hourIndex: h - startHour,
                          isLastHour: h == endHour - 1,
                          columnTint: _columnTint,
                          onTap: onEmptySlotTap == null
                              ? null
                              : () => onEmptySlotTap!(day, h),
                        ),
                    ],
                  ),
                  for (final placement in placements)
                    positionBlock(context, placement),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourRowShell extends StatelessWidget {
  const _HourRowShell({
    required this.hourHeight,
    required this.hourIndex,
    this.isLastHour = false,
    this.showRightBorder = false,
    this.rightBorderWidth = 1,
    this.columnTint,
    this.child,
    this.onTap,
  });

  final double hourHeight;
  final int hourIndex;
  final bool isLastHour;
  final bool showRightBorder;
  final double rightBorderWidth;
  final Color? columnTint;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hourBand = hourIndex.isEven
        ? Colors.transparent
        : AppVisual.border.withValues(alpha: 0.06);
    final base = columnTint ?? AppVisual.surface;
    final row = Container(
      height: hourHeight,
      decoration: BoxDecoration(
        color: Color.alphaBlend(hourBand, base),
        border: Border(
          top: BorderSide(color: AppVisual.border.withValues(alpha: 0.78)),
          bottom: isLastHour
              ? BorderSide(color: AppVisual.border.withValues(alpha: 0.55))
              : BorderSide.none,
          right: showRightBorder
              ? BorderSide(
                  color: AppVisual.border.withValues(alpha: 0.72),
                  width: rightBorderWidth,
                )
              : BorderSide.none,
        ),
      ),
      child: child,
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _AgendaOutcomeBadge extends StatelessWidget {
  const _AgendaOutcomeBadge({required this.outcome});

  final AppointmentCompletionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (outcome) {
      AppointmentCompletionOutcome.attended => (
        'Svolta',
        const Color(0xFF15803D),
      ),
      AppointmentCompletionOutcome.absent => (
        'Assente',
        const Color(0xFFB45309),
      ),
      AppointmentCompletionOutcome.rescheduled => (
        'Riprog.',
        const Color(0xFF6B7280),
      ),
      AppointmentCompletionOutcome.pending => (
        'Programmata',
        AppVisual.logoBlue,
      ),
    };

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1,
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.weekday,
    required this.dayNum,
    required this.isToday,
    this.backgroundColor,
  });

  final String weekday;
  final int dayNum;
  final bool isToday;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday
            ? AppVisual.logoBlue.withValues(alpha: 0.14)
            : backgroundColor ?? AppVisual.surface,
        border: Border(
          bottom: BorderSide(color: AppVisual.border.withValues(alpha: 0.78)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekday,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isToday ? AppVisual.logoBlue : AppVisual.inkMuted,
              fontSize: 10,
              height: 1,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 1),
          Text(
            '$dayNum',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: isToday ? AppVisual.logoBlueDeep : BackofficeUiTokens.text,
              height: 1,
              fontSize: 13,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
