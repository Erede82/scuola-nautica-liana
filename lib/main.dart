import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/app_auth_bootstrap.dart';
import 'services/liana_url_strategy.dart';
import 'services/startup_diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FRONT.1: Montserrat + Ovo sono in assets/google_fonts/. Nessun fetch
  // runtime da fonts.gstatic.com (evita swap metrico al cold start).
  GoogleFonts.config.allowRuntimeFetching = false;
  configureLianaUrlStrategy();
  StartupDiagnostics.ensureStarted();
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
