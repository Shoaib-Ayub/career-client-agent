import 'package:career_client_agent/app/routes/app_routes.dart';
import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/app_date_formatter.dart';
import 'package:career_client_agent/core/widgets/empty_state_widget.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/core/widgets/skill_chip.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';
import 'package:career_client_agent/features/search_tasks/view_model/search_tasks_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchTasksScreen extends ConsumerWidget {
  const SearchTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(searchTasksViewModelProvider);

    return tasksState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => EmptyStateWidget(
        title: AppStrings.emptyStateTitle,
        message: error.toString(),
      ),
      data: (tasks) => _TaskList(tasks: tasks),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks});

  final List<SearchTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: SectionHeader(
                        title: AppStrings.searchTasksTitle,
                        subtitle: AppStrings.searchTasksSubtitle,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceMd),
                    FilledButton.icon(
                      onPressed: () =>
                          context.pushNamed(AppRoutes.addSearchTaskName),
                      icon: const Icon(AppIcons.add),
                      label: const Text(AppStrings.addTask),
                    ),
                  ],
                ),
              ),
            ),
            if (tasks.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  title: AppStrings.noTasksTitle,
                  message: AppStrings.noTasksMessage,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spaceLg,
                  AppSizes.zero,
                  AppSizes.spaceLg,
                  AppSizes.spaceLg,
                ),
                sliver: SliverList.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSizes.spaceMd),
                  itemBuilder: (context, index) {
                    return _TaskCard(task: tasks[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final SearchTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

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
                Icon(
                  _iconForType(task.taskType),
                  size: AppSizes.taskCardIconSize,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        task.taskType.label,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: task.isActive,
                  onChanged: (value) => ref
                      .read(searchTasksViewModelProvider.notifier)
                      .toggleStatus(task),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Wrap(
              spacing: AppSizes.spaceXs,
              runSpacing: AppSizes.spaceXs,
              children: task.keywords
                  .map((keyword) => SkillChip(label: keyword))
                  .toList(),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Row(
              children: [
                const Icon(AppIcons.location, color: AppColors.textSecondary),
                const SizedBox(width: AppSizes.spaceXs),
                Expanded(child: Text(task.location)),
                const Icon(
                  AppIcons.resultLimit,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.spaceXs),
                Text(AppStrings.dailyResults(task.dailyLimit)),
              ],
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Wrap(
              spacing: AppSizes.spaceLg,
              runSpacing: AppSizes.spaceXs,
              children: [
                Text(
                  AppStrings.taskLevel(task.level),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  AppStrings.taskCreated(
                    AppDateFormatter.compact(task.createdAt),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  AppStrings.taskLastRun(
                    task.lastRunAt == null
                        ? AppStrings.neverRun
                        : AppDateFormatter.compact(task.lastRunAt!),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Row(
              children: [
                Chip(
                  label: Text(
                    task.isActive
                        ? AppStrings.activeStatus
                        : AppStrings.pausedStatus,
                  ),
                  backgroundColor: task.isActive
                      ? AppColors.successBackground
                      : AppColors.navigationIndicator,
                  side: BorderSide.none,
                ),
                const Spacer(),
                IconButton(
                  tooltip: AppStrings.editTask,
                  onPressed: () => context.pushNamed(
                    AppRoutes.editSearchTaskName,
                    pathParameters: {AppRoutes.taskIdParameter: task.id},
                  ),
                  icon: const Icon(AppIcons.edit),
                ),
                IconButton(
                  tooltip: AppStrings.deleteTask,
                  onPressed: () => _deleteTask(context, ref),
                  icon: const Icon(AppIcons.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteTask),
        content: const Text(AppStrings.confirmDeleteTask),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await ref.read(searchTasksViewModelProvider.notifier).deleteTask(task.id);
    }
  }

  IconData _iconForType(SearchTaskType type) => switch (type) {
    SearchTaskType.job => AppIcons.jobs,
    SearchTaskType.scholarship => AppIcons.scholarships,
    SearchTaskType.governmentJob => AppIcons.governmentJobs,
    SearchTaskType.clientLead => AppIcons.clientLeads,
  };
}
