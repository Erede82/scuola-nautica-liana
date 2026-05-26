import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_registry.dart';
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
  });

  final bool embedded;
  final ValueChanged<StudentId> onOpenStudent360;

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
          repository: backofficeRepository,
          onSaved: _load,
        );
    }
  }

  Future<void> _editGuide(GuidanceListItem item) async {
    try {
      final profiles = await backofficeRepository.listStudentProfiles();
      if (!mounted) return;
      await showEditAgendaSeaPracticeDialog(
        context,
        item: item,
        students: profiles,
        repository: backofficeRepository,
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

  Future<void> _openNewSeaLesson() async {
    try {
      final profiles = await backofficeRepository.listStudentProfiles();
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
      await showAgendaSeaPracticeDialog(
        context,
        repository: backofficeRepository,
        students: profiles,
        onSaved: _load,
      );
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
      final list = await backofficeRepository.listGuidanceAppointments();
      if (!mounted) return;
      setState(() {
        _items = list;
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
    return filtered.where((i) {
      final day = DateTime(
        i.lessonDate.year,
        i.lessonDate.month,
        i.lessonDate.day,
      );
      return !day.isBefore(_weekMonday) && day.isBefore(weekEnd);
    }).toList(growable: false);
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
                  'Guide / Agenda',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Cerca allievo, istruttore, note…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _openNewSeaLesson,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Nuova guida'),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Aggiorna agenda',
                ),
              ],
            ),
          ),
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

    if (weekItems.isEmpty) {
      return Center(
        child: Text(
          filtered.isEmpty
              ? 'Nessuna guida pratica in mare in elenco.'
              : 'Nessuna guida in questa settimana (prova ad avanzare o reimpostare i filtri).',
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }

    return _WeekAgendaGrid(
      weekMonday: _weekMonday,
      items: weekItems,
      startHour: _agendaStartHour,
      endHour: _agendaEndHour,
      hourHeight: _hourHeight,
      onBlockTap: _onAgendaBlockTap,
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
  });

  final DateTime weekMonday;
  final List<GuidanceListItem> items;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final ValueChanged<GuidanceListItem> onBlockTap;

  static const double _timeColWidth = 48;
  static const double _minDayColWidth = 108;
  static const double _dayHeaderHeight = 36;

  DateTime _effectiveStart(GuidanceListItem i) {
    if (i.startTime != null) return i.startTime!.toLocal();
    return DateTime(
      i.lessonDate.year,
      i.lessonDate.month,
      i.lessonDate.day,
      9,
    );
  }

  DateTime _effectiveEnd(GuidanceListItem i) {
    if (i.endTime != null) return i.endTime!.toLocal();
    return _effectiveStart(i).add(const Duration(hours: 1));
  }

  List<GuidanceListItem> _forDay(DateTime day) {
    final day0 = DateTime(day.year, day.month, day.day);
    return items.where((i) {
      final d = DateTime(i.lessonDate.year, i.lessonDate.month, i.lessonDate.day);
      return d == day0;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalHours = endHour - startHour;
    final gridHeight = totalHours * hourHeight;
    final days = List.generate(
      7,
      (i) => weekMonday.add(Duration(days: i)),
    );
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, c) {
        final dayColWidth = (c.maxWidth - _timeColWidth - 32) / 7;
        final colW = dayColWidth < _minDayColWidth ? _minDayColWidth : dayColWidth;
        final scrollWide = colW * 7 + _timeColWidth + 16 > c.maxWidth;

        final gridWidth = scrollWide
            ? _timeColWidth + colW * 7
            : c.maxWidth - 16;

        final grid = DecoratedBox(
          decoration: BoxDecoration(
            color: AppVisual.surface,
            border: Border.all(
              color: AppVisual.border.withValues(alpha: 0.78),
            ),
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

    return sorted.map((item) {
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
    }).toList(growable: false);
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
    final height = ((heightMinutes / 60) * hourHeight).clamp(22.0, double.infinity);

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
    final blockLeft =
        blockInsetH + placement.lane * laneWidth + laneGap / 2;

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
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
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
  final Widget Function(BuildContext context, _DayAppointmentPlacement placement)
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
            right: BorderSide(
              color: AppVisual.border.withValues(alpha: 0.72),
            ),
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
  });

  final double hourHeight;
  final int hourIndex;
  final bool isLastHour;
  final bool showRightBorder;
  final double rightBorderWidth;
  final Color? columnTint;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final hourBand = hourIndex.isEven
        ? Colors.transparent
        : AppVisual.border.withValues(alpha: 0.06);
    final base = columnTint ?? AppVisual.surface;
    return Container(
      height: hourHeight,
      decoration: BoxDecoration(
        color: Color.alphaBlend(hourBand, base),
        border: Border(
          top: BorderSide(
            color: AppVisual.border.withValues(alpha: 0.78),
          ),
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
