import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/settings/model/notification_settings.dart';
import 'package:career_client_agent/features/settings/service/notification_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, NotificationSettings>(
      SettingsViewModel.new,
    );

class SettingsViewModel extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() {
    return ref.read(notificationSettingsRepositoryProvider).getSettings();
  }

  Future<bool> setEnabled(bool isEnabled) async {
    final current = state.value ?? const NotificationSettings();
    var updated = current.copyWith(isEnabled: isEnabled);
    if (isEnabled) {
      final granted = await ref
          .read(notificationCoordinatorProvider)
          .enable(updated);
      if (!granted) {
        updated = updated.copyWith(isEnabled: false);
        await _save(updated, synchronize: false);
        return false;
      }
    }
    await _save(updated);
    return true;
  }

  Future<void> setDailyReportTime({required int hour, required int minute}) {
    final current = state.value ?? const NotificationSettings();
    return _save(
      current.copyWith(dailyReportHour: hour, dailyReportMinute: minute),
    );
  }

  Future<void> setDeadlineReminderDays(int days) {
    final current = state.value ?? const NotificationSettings();
    return _save(current.copyWith(deadlineReminderDays: days));
  }

  Future<void> setHighMatchThreshold(int threshold) {
    final current = state.value ?? const NotificationSettings();
    return _save(current.copyWith(highMatchThreshold: threshold));
  }

  Future<void> _save(
    NotificationSettings settings, {
    bool synchronize = true,
  }) async {
    await ref
        .read(notificationSettingsRepositoryProvider)
        .saveSettings(settings);
    state = AsyncData(settings);
    if (synchronize) {
      await ref.read(notificationCoordinatorProvider).synchronize(settings);
    }
  }
}
