import '../../config/supabase_config.dart';
import 'management_repository.dart';
import 'management_repository_mock.dart';
import 'management_repository_supabase.dart';

ManagementRepositoryMock? _mockManagementRepository;

ManagementRepository get managementRepository {
  if (SupabaseConfig.isConfigured) {
    return ManagementRepositorySupabase.instance;
  }
  return _mockManagementRepository ??= ManagementRepositoryMock();
}
