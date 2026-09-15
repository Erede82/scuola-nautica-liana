import 'app_update_coordinator.dart';

/// Mutation protetta: evita reload durante save/write critici.
Future<T> runUpdateProtectedMutation<T>(Future<T> Function() operation) async {
  final coordinator = AppUpdateCoordinator.instance;
  coordinator.beginMutation();
  try {
    return await operation();
  } finally {
    coordinator.endMutation();
  }
}
