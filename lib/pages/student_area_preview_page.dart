import 'package:flutter/material.dart';

import '../services/student_area_context.dart';
import 'home_page.dart';

/// Ingresso staff all'area studente in anteprima read-only (nessun allievo target in D1).
class StudentAreaPreviewPage extends StatefulWidget {
  const StudentAreaPreviewPage({super.key});

  @override
  State<StudentAreaPreviewPage> createState() => _StudentAreaPreviewPageState();
}

class _StudentAreaPreviewPageState extends State<StudentAreaPreviewPage> {
  @override
  void initState() {
    super.initState();
    studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;
  }

  @override
  void dispose() {
    if (studentAreaPreviewActiveMode.value == StudentAreaMode.staffPreview) {
      studentAreaPreviewActiveMode.value = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const StudentAreaContext(
      mode: StudentAreaMode.staffPreview,
      readOnly: true,
      child: HomePage(),
    );
  }
}
