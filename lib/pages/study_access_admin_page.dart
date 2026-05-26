import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../data/license_catalog.dart';
import '../models/lesson_quiz_performance_snapshot.dart';
import '../models/license_models.dart';
import '../repositories/study_access_repository.dart';
import '../services/error_review_provider.dart';
import '../theme/app_visual_tokens.dart';

/// Schermata segreteria per le **assegnazioni manuali** degli sblocchi studio (preview / allineamento UI).
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
  LicenseCategoryId _categoryId = LicenseCategoryId.motore;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
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
                  bottom: _buildTabBar(),
                ),
          body: Column(
            children: [
              if (widget.embedded)
                Material(
                  color: StudyAccessAdminPage._primaryColor,
                  child: _buildTabBar(),
                ),
              _InternalHeader(textTheme: textTheme),
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
                      categoryId: _categoryId,
                      textTheme: textTheme,
                    ),
                    _ExamTab(categoryId: _categoryId, textTheme: textTheme),
                    _ErrorReviewTab(
                      categoryId: _categoryId,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: !SupabaseConfig.isConfigured
                    ? OutlinedButton.icon(
                        onPressed: () {
                          studyAccessWritableRepository.resetDemoAssignments();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Anteprima locale: sblocchi in memoria ripristinati al seed demo '
                                '(nessun effetto su Supabase o sugli allievi reali).',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('Ripristina anteprima demo (solo locale)'),
                      )
                    : Text(
                        'Gli sblocchi effettivi si gestiscono dalla Scheda allievo (Supabase). '
                        'Questa pagina resta un’anteprima sul dispositivo corrente.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.ink.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
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

  static const Color _warnColor = Color(0xFFC27C1C);
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warnColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppVisual.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: _warnColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gestione sblocchi lezioni e quiz — strumento per la segreteria',
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
            'Le modifiche qui aggiornano il repository condiviso con l’anteprima allievo '
            '(stesso comportamento che il percorso reale riceve dopo sincronizzazione).',
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

/// Pannello informativo per categoria Vela: contenuti non erogati, niente liste vuote “rotte”.
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
  const _LessonSheetsTab({required this.categoryId, required this.textTheme});

  final LicenseCategoryId categoryId;
  final TextTheme textTheme;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final category = LicenseCatalog.byId(categoryId);
    final read = studyAccessRepository;

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
        if (read.effectiveLessonSheetUnlocked(categoryId, lesson.number, s)) {
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

          final write = studyAccessWritableRepository;
          var explicitTrue = 0;
          var explicitFalse = 0;
          var unset = 0;
          for (var s = 1; s <= lesson.quizSheets; s++) {
            final raw = write.storedLessonSheetUnlocked(
              categoryId: categoryId,
              lessonNumber: lesson.number,
              sheetNumber: s,
            );
            if (raw == true) {
              explicitTrue++;
            } else if (raw == false) {
              explicitFalse++;
            } else {
              unset++;
            }
          }
          final storedMixed = explicitTrue > 0 && explicitFalse > 0;
          final studentSeesLesson = read.effectiveLessonSheetUnlocked(
            categoryId,
            lesson.number,
            1,
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

          void applyWholeLesson(bool unlocked) {
            for (var s = 1; s <= lesson.quizSheets; s++) {
              write.applyLessonQuizSheetUnlock(
                categoryId: categoryId,
                lessonNumber: lesson.number,
                sheetNumber: s,
                unlocked: unlocked,
              );
            }
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
                  if (explicitTrue > 0 || explicitFalse > 0 || unset > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Righe impostate: $explicitTrue sì · $explicitFalse no · '
                      '$unset senza override (vale solo seed anteprima)',
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
                        onPressed: () => applyWholeLesson(true),
                        icon: const Icon(Icons.lock_open_rounded, size: 20),
                        label: const Text('Sblocca tutta la lezione'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimaryColor,
                        ),
                        onPressed: () => applyWholeLesson(false),
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
  const _ExamTab({required this.categoryId, required this.textTheme});

  final LicenseCategoryId categoryId;
  final TextTheme textTheme;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final read = studyAccessRepository;
    final unlocked = read.effectiveExamUnlocked(categoryId);
    final category = LicenseCatalog.byId(categoryId);

    if (categoryId == LicenseCategoryId.vela) {
      return _VelaAdminBlockedPanel(
        textTheme: textTheme,
        detailLine:
            'Scheda “Esame”: il quiz esame vela non può essere abilitato finché i contenuti non sono pronti.',
      );
    }

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
                  onChanged: (v) {
                    studyAccessWritableRepository.applyExamQuizUnlock(
                      categoryId: categoryId,
                      unlocked: v,
                    );
                  },
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
  const _ErrorReviewTab({required this.categoryId, required this.textTheme});

  final LicenseCategoryId categoryId;
  final TextTheme textTheme;

  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final read = studyAccessRepository;
    final weak = ErrorReviewProvider.weakSnapshotsForCategory(categoryId);
    var u = 0;
    for (final s in weak) {
      if (read.effectiveErrorTopicUnlocked(categoryId, s.lessonNumber)) u++;
    }

    if (weak.isEmpty) {
      if (categoryId == LicenseCategoryId.vela) {
        return _VelaAdminBlockedPanel(
          textTheme: textTheme,
          detailLine:
              'Scheda “Ripasso”: nessun argomento da gestire finché non ci sono dati quiz vela.',
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessun argomento in evidenza per questa categoria con i dati attuali. '
            'Il Ripasso errori userà le statistiche reali dell’allievo in una fase successiva; '
            'per ora restano solo esempi interni di anteprima.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: _textPrimaryColor),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _SummaryChips(
          textTheme: textTheme,
          chips: [
            ('Ripasso sbloccato', u, _successColor),
            ('In attesa', weak.length - u, _textPrimaryColor),
            ('Topics', weak.length, _primaryColor),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Argomenti consigliati (anteprima: non ancora calcolati sulle statistiche reali). '
          'Il collegamento ai quiz effettivi dell’allievo è in roadmap. '
          'Abilita o disabilita il ripasso per ciascun argomento elencato.',
          style: textTheme.bodySmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.75),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ...weak.map((LessonQuizPerformanceSnapshot s) {
          final open = read.effectiveErrorTopicUnlocked(
            categoryId,
            s.lessonNumber,
          );
          return Card(
            color: _cardColor,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppVisual.border.withValues(alpha: 0.65)),
            ),
            child: SwitchListTile.adaptive(
              title: Text(
                s.lessonTitle,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Errori medi ~${s.averageErrorPercentage.round()}% · esempio argomento in evidenza',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    open
                        ? 'Materiale ripasso disponibile per lo studente'
                        : 'Consigliato ma in attesa di abilitazione',
                    style: textTheme.bodySmall?.copyWith(
                      color: open ? _successColor : _primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              value: open,
              activeTrackColor: _successColor.withValues(alpha: 0.55),
              onChanged: (v) {
                studyAccessWritableRepository.applyErrorReviewTopicUnlock(
                  categoryId: categoryId,
                  lessonNumber: s.lessonNumber,
                  unlocked: v,
                );
              },
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
