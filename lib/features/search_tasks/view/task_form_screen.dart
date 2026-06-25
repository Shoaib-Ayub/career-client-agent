import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/widgets/app_scaffold.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';
import 'package:career_client_agent/features/search_tasks/view_model/search_tasks_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({this.taskId, super.key});

  final String? taskId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _locationController = TextEditingController();
  final _levelController = TextEditingController();
  final _filtersController = TextEditingController();
  final _dailyLimitController = TextEditingController(
    text: AppConstants.defaultTaskDailyLimit.toString(),
  );

  SearchTaskType _selectedType = SearchTaskType.job;
  bool _isActive = true;
  bool _initialized = false;
  SearchTask? _editingTask;

  bool get _isEditing => widget.taskId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _keywordsController.dispose();
    _locationController.dispose();
    _levelController.dispose();
    _filtersController.dispose();
    _dailyLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(searchTasksViewModelProvider);

    return AppScaffold(
      title: _isEditing ? AppStrings.editTask : AppStrings.addTask,
      body: tasksState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (tasks) {
          _initializeForm(tasks);

          if (_isEditing && !_initialized) {
            return const Center(child: Text(AppStrings.taskNotFound));
          }

          return _buildForm();
        },
      ),
    );
  }

  void _initializeForm(List<SearchTask> tasks) {
    if (_initialized || !_isEditing) {
      _initialized = true;
      return;
    }

    final task = _findTask(tasks);
    if (task == null) {
      return;
    }

    _titleController.text = task.title;
    _keywordsController.text = task.keywords.join(
      AppConstants.listDisplaySeparator,
    );
    _locationController.text = task.location;
    _levelController.text = task.level;
    _filtersController.text = task.filters.join(
      AppConstants.listDisplaySeparator,
    );
    _dailyLimitController.text = task.dailyLimit.toString();
    _selectedType = task.taskType;
    _isActive = task.isActive;
    _editingTask = task;
    _initialized = true;
  }

  SearchTask? _findTask(List<SearchTask> tasks) {
    for (final task in tasks) {
      if (task.id == widget.taskId) {
        return task;
      }
    }
    return null;
  }

  Widget _buildForm() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.taskFormMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<SearchTaskType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: AppStrings.taskTypeLabel,
                    prefixIcon: Icon(AppIcons.searchTasks),
                    border: OutlineInputBorder(),
                  ),
                  items: SearchTaskType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.spaceMd),
                _TaskTextField(
                  controller: _titleController,
                  label: AppStrings.taskTitleLabel,
                  icon: AppIcons.edit,
                ),
                _TaskTextField(
                  controller: _keywordsController,
                  label: AppStrings.keywordsLabel,
                  icon: AppIcons.keyword,
                  helperText: AppStrings.keywordInputHint,
                ),
                _TaskTextField(
                  controller: _locationController,
                  label: AppStrings.taskLocationLabel,
                  icon: AppIcons.country,
                ),
                _TaskTextField(
                  controller: _levelController,
                  label: AppStrings.taskLevelLabel,
                  icon: AppIcons.experience,
                ),
                _TaskTextField(
                  controller: _filtersController,
                  label: AppStrings.filtersLabel,
                  icon: AppIcons.filter,
                  helperText: AppStrings.filterInputHint,
                ),
                _TaskTextField(
                  controller: _dailyLimitController,
                  label: AppStrings.dailyResultLimitLabel,
                  icon: AppIcons.resultLimit,
                  keyboardType: TextInputType.number,
                  validator: _validateDailyLimit,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(AppStrings.taskStatusLabel),
                  subtitle: Text(
                    _isActive
                        ? AppStrings.activeStatus
                        : AppStrings.pausedStatus,
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: AppSizes.spaceMd),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(
                      _isEditing ? AppStrings.updateTask : AppStrings.saveTask,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateDailyLimit(String? value) {
    final limit = int.tryParse(value ?? AppStrings.emptyValue);
    if (limit == null ||
        limit < AppConstants.minimumTaskDailyLimit ||
        limit > AppConstants.maximumTaskDailyLimit) {
      return AppStrings.invalidDailyLimit;
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final viewModel = ref.read(searchTasksViewModelProvider.notifier);
    final task = viewModel.createTask(
      id: widget.taskId,
      type: _selectedType,
      title: _titleController.text,
      keywords: _keywordsController.text,
      location: _locationController.text,
      level: _levelController.text,
      filters: _filtersController.text,
      dailyLimit: _dailyLimitController.text,
      isActive: _isActive,
      createdAt: _editingTask?.createdAt,
      lastRunAt: _editingTask?.lastRunAt,
    );
    await viewModel.saveTask(task);

    if (mounted) {
      context.pop();
    }
  }
}

class _TaskTextField extends StatelessWidget {
  const _TaskTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.helperText,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? helperText;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator ?? _requiredValidator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty
        ? AppStrings.requiredField
        : null;
  }
}
