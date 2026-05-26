import 'package:flutter/foundation.dart';

/// Log mirati flusso Quiz (solo [kDebugMode]).
void qfLog(String message, [Object? error, StackTrace? stack]) {
  if (!kDebugMode) return;
  debugPrint('[QUIZ_FLOW] $message');
  if (error != null) {
    debugPrint('[QUIZ_FLOW] error: $error');
  }
  if (stack != null) {
    debugPrint('[QUIZ_FLOW] stack: $stack');
  }
}
