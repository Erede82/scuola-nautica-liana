import 'package:flutter/material.dart';

/// Modalità dell'area studente: uso normale o anteprima staff read-only.
enum StudentAreaMode { normal, staffPreview }

/// Sessione anteprima attiva mentre [StudentAreaPreviewPage] è nello stack.
///
/// Le route `Navigator.push` non ereditano [StudentAreaContext]: questo notifier
/// consente di risolvere la modalità preview anche nelle pagine figlie.
final ValueNotifier<StudentAreaMode?> studentAreaPreviewActiveMode =
    ValueNotifier<StudentAreaMode?>(null);

/// Contesto opzionale nell'albero widget per l'area allievo.
///
/// Assenza del widget e assenza di anteprima attiva equivalgono a
/// [StudentAreaMode.normal] con [readOnly] false.
class StudentAreaContext extends InheritedWidget {
  const StudentAreaContext({
    super.key,
    required this.mode,
    required this.readOnly,
    required super.child,
  });

  final StudentAreaMode mode;
  final bool readOnly;

  bool get isStaffPreview => mode == StudentAreaMode.staffPreview;

  static const StudentAreaContext _fallback = StudentAreaContext(
    mode: StudentAreaMode.normal,
    readOnly: false,
    child: SizedBox.shrink(),
  );

  static const StudentAreaContext _previewFallback = StudentAreaContext(
    mode: StudentAreaMode.staffPreview,
    readOnly: true,
    child: SizedBox.shrink(),
  );

  static StudentAreaContext _resolve(BuildContext context) {
    final inherited = maybeOf(context);
    if (inherited != null) return inherited;
    if (studentAreaPreviewActiveMode.value == StudentAreaMode.staffPreview) {
      return _previewFallback;
    }
    return _fallback;
  }

  static StudentAreaContext of(BuildContext context) {
    return _resolve(context);
  }

  static StudentAreaContext? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StudentAreaContext>();
  }

  /// True se le azioni che scrivono progressi o dati personali vanno bloccate.
  static bool blocksWrites(BuildContext context) {
    return of(context).readOnly;
  }

  @override
  bool updateShouldNotify(StudentAreaContext oldWidget) {
    return mode != oldWidget.mode || readOnly != oldWidget.readOnly;
  }
}

/// Testi neutri mostrati in anteprima staff (nessun dato personale).
abstract final class StudentAreaPreviewCopy {
  static const String headerTitle = 'Anteprima area allievo';
  static const String headerSubtitle = 'Modalità controllo staff';
  static const String welcomeTitle =
      'Stai visualizzando l’esperienza dell’app studente';
  static const String welcomeHint =
      'Anteprima generale: non rappresenta il profilo di uno specifico allievo.';
  static const String bannerTitle = 'Anteprima area allievo';
  static const String bannerSubtitle =
      'Modalità di sola lettura: le azioni che modificano dati o progressi sono disabilitate.';
  static const String accountUnavailableTitle = 'Account';
  static const String accountUnavailableMessage =
      'La sezione Account non è disponibile in modalità anteprima.';
  static const String previewAccountName = 'Anteprima allievo';
  static const String previewAccountEmail = 'Dati non disponibili in anteprima';
  static const String previewAccountPathNote =
      'Percorso dimostrativo in anteprima (non rappresenta un allievo reale).';
  static const String quizSaveBlockedMessage =
      'In modalità anteprima i risultati delle schede non vengono salvati.';
  static const String purchasesBlockedMessage =
      'Gli acquisti non sono disponibili in modalità anteprima.';
}
