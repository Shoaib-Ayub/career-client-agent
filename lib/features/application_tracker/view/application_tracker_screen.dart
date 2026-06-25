import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/app_date_formatter.dart';
import 'package:career_client_agent/core/widgets/empty_state_widget.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/core/widgets/recommendation_card.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/core/widgets/source_link_button.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/application_tracker/view_model/application_tracker_view_model.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApplicationTrackerScreen extends ConsumerWidget {
  const ApplicationTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(applicationTrackerViewModelProvider)
        .when(
          loading: LoadingWidget.new,
          error: (error, stackTrace) => ErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(applicationTrackerViewModelProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyStateWidget(
                  title: AppStrings.noTrackedApplicationsTitle,
                  message: AppStrings.noTrackedApplicationsMessage,
                )
              : _TrackerList(items: items),
        );
  }
}

class _TrackerList extends StatelessWidget {
  const _TrackerList({required this.items});

  final List<ApplicationTrackerItem> items;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.opportunityCardMaxWidth,
        ),
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.all(AppSizes.spaceLg),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: AppStrings.applicationTrackerTitle,
                  subtitle: AppStrings.applicationTrackerDescription,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spaceLg,
                AppSizes.zero,
                AppSizes.spaceLg,
                AppSizes.spaceLg,
              ),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSizes.spaceMd),
                itemBuilder: (context, index) =>
                    _TrackerCard(item: items[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerCard extends ConsumerWidget {
  const _TrackerCard({required this.item});

  final ApplicationTrackerItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final assistant = ref
        .read(applicationTrackerViewModelProvider.notifier)
        .assistantFor(item);

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        item.organization,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        item.type.label,
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spaceMd),
                DropdownButton<ApplicationStatus>(
                  value: item.status,
                  onChanged: (status) {
                    if (status != null) {
                      ref
                          .read(applicationTrackerViewModelProvider.notifier)
                          .updateStatus(item, status);
                    }
                  },
                  items: ApplicationStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Wrap(
              spacing: AppSizes.spaceLg,
              runSpacing: AppSizes.spaceXs,
              children: [
                _DateValue(
                  label: AppStrings.deadlineLabel,
                  date: item.deadline,
                ),
                _OptionalDateValue(
                  label: AppStrings.appliedDate,
                  date: item.appliedDate,
                ),
                _OptionalDateValue(
                  label: AppStrings.followUpDate,
                  date: item.followUpDate,
                ),
              ],
            ),
            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spaceMd),
              Text(
                AppStrings.notesLabel,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.spaceXs),
              Text(item.notes),
            ],
            const SizedBox(height: AppSizes.spaceLg),
            Wrap(
              spacing: AppSizes.spaceSm,
              runSpacing: AppSizes.spaceSm,
              children: [
                OutlinedButton.icon(
                  onPressed: item.status == ApplicationStatus.applied
                      ? null
                      : () => ref
                            .read(applicationTrackerViewModelProvider.notifier)
                            .markApplied(item),
                  icon: const Icon(AppIcons.applied),
                  label: const Text(AppStrings.markAsApplied),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editNotes(context, ref),
                  icon: const Icon(AppIcons.notes),
                  label: const Text(AppStrings.addNotes),
                ),
                OutlinedButton.icon(
                  onPressed: () => _selectFollowUp(context, ref),
                  icon: const Icon(AppIcons.followUp),
                  label: const Text(AppStrings.setFollowUp),
                ),
                SourceLinkButton(
                  sourceLink: item.sourceLink,
                  label: AppStrings.openApplyLink,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(
                AppIcons.applicationTracker,
                color: AppColors.trackerAccent,
              ),
              title: const Text(AppStrings.applyAssistantTitle),
              children: [
                RecommendationCard(
                  title: AppStrings.cvChangesNeeded,
                  items: assistant.cvChanges,
                ),
                const SizedBox(height: AppSizes.spaceMd),
                _DraftCard(
                  title: AppStrings.coverLetterDraft,
                  text: assistant.coverLetterDraft,
                  icon: AppIcons.coverLetter,
                ),
                const SizedBox(height: AppSizes.spaceMd),
                _DraftCard(
                  title: AppStrings.outreachMessageDraft,
                  text: assistant.outreachMessageDraft,
                  icon: AppIcons.outreach,
                ),
                const SizedBox(height: AppSizes.spaceMd),
                RecommendationCard(
                  title: AppStrings.requiredDocumentsChecklist,
                  items: assistant.requiredDocuments,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.notes);
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.addNotes),
        content: TextField(
          controller: controller,
          minLines: AppSizes.formFieldMinLines,
          maxLines: AppSizes.formFieldMaxLines,
          decoration: const InputDecoration(
            labelText: AppStrings.notesLabel,
            hintText: AppStrings.notesHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(AppStrings.saveNotes),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes != null) {
      await ref
          .read(applicationTrackerViewModelProvider.notifier)
          .updateNotes(item, notes);
    }
  }

  Future<void> _selectFollowUp(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final lastDate = item.deadline.isAfter(now) ? item.deadline : now;
    final preferredDate = item.followUpDate ?? now;
    final initialDate = preferredDate.isAfter(lastDate)
        ? lastDate
        : preferredDate.isBefore(now)
        ? now
        : preferredDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: lastDate,
    );
    if (date != null) {
      await ref
          .read(applicationTrackerViewModelProvider.notifier)
          .updateFollowUp(item, date);
    }
  }
}

class _DateValue extends StatelessWidget {
  const _DateValue({required this.label, required this.date});

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.labeledValue(label, AppDateFormatter.compact(date)),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _OptionalDateValue extends StatelessWidget {
  const _OptionalDateValue({required this.label, required this.date});

  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.labeledValue(
        label,
        date == null
            ? AppStrings.noDateSelected
            : AppDateFormatter.compact(date!),
      ),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.title,
    required this.text,
    required this.icon,
  });

  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.neutralBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.trackerAccent),
              const SizedBox(width: AppSizes.spaceXs),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSm),
          SelectableText(text),
        ],
      ),
    );
  }
}
