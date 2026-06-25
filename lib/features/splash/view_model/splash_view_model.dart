import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/local_database_service.dart';
import 'package:career_client_agent/core/utils/async_guard.dart';
import 'package:career_client_agent/features/settings/service/notification_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final splashViewModelProvider = Provider<SplashViewModel>((ref) {
  return SplashViewModel(
    databaseService: const LocalDatabaseService(),
    notificationInitializer: () =>
        ref.read(notificationCoordinatorProvider).synchronize(),
  );
});

class SplashViewModel {
  const SplashViewModel({
    this.duration = AppConstants.splashDuration,
    this.databaseService,
    this.notificationInitializer,
  });

  final Duration duration;
  final LocalDatabaseService? databaseService;
  final Future<void> Function()? notificationInitializer;

  Future<void> initialize() async {
    await Future.wait([
      AsyncGuard.wait(duration),
      if (databaseService != null) databaseService!.seedInitialData(),
    ]);
    await notificationInitializer?.call();
  }
}
