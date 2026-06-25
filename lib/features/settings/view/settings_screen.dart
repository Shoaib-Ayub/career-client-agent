import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/core/widgets/profile_card.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/features/settings/model/notification_settings.dart';
import 'package:career_client_agent/features/settings/view_model/settings_view_model.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notificationSettingsTitle)),
      body: ref
          .watch(settingsViewModelProvider)
          .when(
            loading: LoadingWidget.new,
            error: (error, stackTrace) => ErrorWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(settingsViewModelProvider),
            ),
            data: (settings) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.settingsMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.spaceLg),
                  children: [
                    const SectionHeader(
                      title: AppStrings.notificationSettingsTitle,
                      subtitle: AppStrings.notificationSettingsSubtitle,
                    ),
                    const SizedBox(height: AppSizes.spaceLg),
                    _NotificationSettingsCard(settings: settings),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _NotificationSettingsCard extends ConsumerWidget {
  const _NotificationSettingsCard({required this.settings});

  final NotificationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileCard(
      title: AppStrings.settingsTitle,
      subtitle: AppStrings.settingsDescription,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              settings.isEnabled
                  ? AppIcons.notifications
                  : AppIcons.notificationsOff,
              color: settings.isEnabled
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            title: const Text(AppStrings.enableNotifications),
            subtitle: const Text(AppStrings.enableNotificationsDescription),
            value: settings.isEnabled,
            onChanged: (value) => _toggleNotifications(context, ref, value),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: settings.isEnabled,
            leading: const Icon(AppIcons.reminderTime),
            title: const Text(AppStrings.dailyReportReminderTime),
            trailing: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay(
                  hour: settings.dailyReportHour,
                  minute: settings.dailyReportMinute,
                ),
              ),
            ),
            onTap: () => _selectTime(context, ref),
          ),
          const Divider(),
          _ValueSlider(
            enabled: settings.isEnabled,
            icon: AppIcons.deadlineReminder,
            title: AppStrings.deadlineReminderDays,
            valueLabel: AppStrings.deadlineReminderValue(
              settings.deadlineReminderDays,
            ),
            value: settings.deadlineReminderDays.toDouble(),
            minimum: AppConstants.minimumDeadlineReminderDays.toDouble(),
            maximum: AppConstants.maximumDeadlineReminderDays.toDouble(),
            divisions: AppSizes.deadlineSliderDivisions,
            onChanged: (value) => ref
                .read(settingsViewModelProvider.notifier)
                .setDeadlineReminderDays(value.round()),
          ),
          const Divider(),
          _ValueSlider(
            enabled: settings.isEnabled,
            icon: AppIcons.highMatchNotification,
            title: AppStrings.highMatchThreshold,
            valueLabel: AppStrings.highMatchThresholdValue(
              settings.highMatchThreshold,
            ),
            value: settings.highMatchThreshold.toDouble(),
            minimum: AppConstants.minimumHighMatchThreshold.toDouble(),
            maximum: AppConstants.maximumHighMatchThreshold.toDouble(),
            divisions: AppSizes.settingsSliderDivisions,
            onChanged: (value) => ref
                .read(settingsViewModelProvider.notifier)
                .setHighMatchThreshold(value.round()),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final enabled = await ref
        .read(settingsViewModelProvider.notifier)
        .setEnabled(value);
    if (!context.mounted) {
      return;
    }
    final message = value && !enabled
        ? AppStrings.notificationPermissionDenied
        : value
        ? AppStrings.notificationsEnabled
        : AppStrings.notificationsDisabled;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectTime(BuildContext context, WidgetRef ref) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.dailyReportHour,
        minute: settings.dailyReportMinute,
      ),
    );
    if (selected == null) {
      return;
    }
    await ref
        .read(settingsViewModelProvider.notifier)
        .setDailyReportTime(hour: selected.hour, minute: selected.minute);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.notificationSettingsSaved)),
        );
    }
  }
}

class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    required this.enabled,
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.divisions,
    required this.onChanged,
  });

  final bool enabled;
  final IconData icon;
  final String title;
  final String valueLabel;
  final double value;
  final double minimum;
  final double maximum;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSizes.spaceMd),
              Expanded(child: Text(title)),
              Text(
                valueLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          Slider(
            value: value,
            min: minimum,
            max: maximum,
            divisions: divisions,
            label: valueLabel,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
