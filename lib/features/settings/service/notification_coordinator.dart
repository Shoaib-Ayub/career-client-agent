import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/settings/model/notification_settings.dart';
import 'package:career_client_agent/features/settings/service/local_notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationCoordinatorProvider = Provider<NotificationCoordinator>((
  ref,
) {
  return NotificationCoordinator(ref);
});

final notificationBootstrapProvider = FutureProvider<void>((ref) {
  return ref.read(notificationCoordinatorProvider).synchronize();
});

class NotificationCoordinator {
  const NotificationCoordinator(this.ref);

  final Ref ref;

  Future<void> synchronize([NotificationSettings? updatedSettings]) async {
    final settings =
        updatedSettings ??
        await ref.read(notificationSettingsRepositoryProvider).getSettings();
    final applications = await ref
        .read(applicationTrackerRepositoryProvider)
        .getItems();
    await ref
        .read(notificationServiceProvider)
        .applySettings(settings: settings, applications: applications);
  }

  Future<bool> enable(NotificationSettings settings) async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestPermission();
    if (!granted) {
      return false;
    }
    await synchronize(settings);
    return true;
  }

  Future<void> notifyNewOpportunities({
    required int newOpportunityCount,
    required List<OpportunityResult> newJobs,
  }) async {
    if (newOpportunityCount == 0) {
      return;
    }
    final settings = await ref
        .read(notificationSettingsRepositoryProvider)
        .getSettings();
    if (!settings.isEnabled) {
      return;
    }
    final service = ref.read(notificationServiceProvider);
    await service.showDailyReportAvailable();
    await service.showHighMatchJobs(newJobs, settings);
  }
}
