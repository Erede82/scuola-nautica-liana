/// Riga catalogo `quiz_sets` per schede lezione (progresso statistiche).
class QuizSheetCatalogRow {
  const QuizSheetCatalogRow({
    required this.id,
    required this.kind,
    required this.licenseCategory,
    required this.lessonNumber,
    required this.sheetNumber,
  });

  final String id;
  final String kind;
  final String licenseCategory;
  final int lessonNumber;
  final int sheetNumber;

  factory QuizSheetCatalogRow.fromJson(Map<String, dynamic> json) {
    return QuizSheetCatalogRow(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      licenseCategory: json['license_category']?.toString() ?? '',
      lessonNumber: (json['lesson_number'] as num?)?.toInt() ?? 0,
      sheetNumber: (json['sheet_number'] as num?)?.toInt() ?? 0,
    );
  }
}
