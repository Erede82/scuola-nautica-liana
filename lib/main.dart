import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/app_auth_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
