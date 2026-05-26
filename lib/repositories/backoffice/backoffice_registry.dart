import '../../config/supabase_config.dart';
import 'backoffice_repository.dart';
import 'backoffice_repository_mock.dart';
import 'backoffice_repository_supabase.dart';

BackofficeRepositoryMock? _mockBackofficeSingleton;

/// Implementazione backoffice: **Supabase** (lettura) se configurato, altrimenti **mock** locale.
///
/// Le scritture verso Supabase non sono ancora attive: in modalità Supabase le mutazioni
/// passano comunque al mock (vedi [BackofficeRepositorySupabase]).
BackofficeRepository get backofficeRepository {
  if (SupabaseConfig.isConfigured) {
    return BackofficeRepositorySupabase.instance;
  }
  return _mockBackofficeSingleton ??= BackofficeRepositoryMock();
}
