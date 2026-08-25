import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/app_auth_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Route stale `#/forgot-password`: normalizzata in web/index.html prima di Flutter.
  // Vedi [web_startup_route_guard.dart] per la logica testabile e i limiti recovery.
  await SupabaseConfig.initialize();
  if (kDebugMode) {
    debugPrint(
      '[ScuolaNauticaLiana] SupabaseConfig.isConfigured='
      '${SupabaseConfig.isConfigured}',
    );
  }
  await bootstrapAppAuth();
  runApp(const ScuolaNauticaLianaApp());
}
