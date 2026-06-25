import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/notification_settings_model.dart';
import 'package:career_client_agent/features/settings/model/notification_settings.dart';

class NotificationSettingsRepository
    extends HiveRepository<NotificationSettingsModel> {
  NotificationSettingsRepository(LocalStorageService storage)
    : super(
        boxName: AppConstants.notificationSettingsBoxName,
        decoder: NotificationSettingsModel.fromMap,
        storage: storage,
      );

  Future<NotificationSettings> getSettings() async {
    return (await getById(
          AppConstants.notificationSettingsRecordId,
        ))?.toDomain() ??
        const NotificationSettings();
  }

  Future<void> saveSettings(NotificationSettings settings) {
    return update(NotificationSettingsModel.fromDomain(settings));
  }
}
