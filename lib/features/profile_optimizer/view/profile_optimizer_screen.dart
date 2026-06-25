import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/core/widgets/profile_card.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/features/profile_optimizer/model/platform_links.dart';
import 'package:career_client_agent/features/profile_optimizer/model/profile_optimization.dart';
import 'package:career_client_agent/features/profile_optimizer/view_model/profile_optimizer_view_model.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileOptimizerScreen extends ConsumerWidget {
  const ProfileOptimizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(profileOptimizerViewModelProvider)
        .when(
          loading: LoadingWidget.new,
          error: (error, stackTrace) => ErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(profileOptimizerViewModelProvider),
          ),
          data: (state) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.profileSectionMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.spaceLg),
                children: [
                  const SectionHeader(
                    title: AppStrings.profileOptimizerTitle,
                    subtitle: AppStrings.profileOptimizerDescription,
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.spaceMd),
                    decoration: BoxDecoration(
                      color: AppColors.navigationIndicator,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.profileOptimizer,
                          color: AppColors.optimizerAccent,
                        ),
                        SizedBox(width: AppSizes.spaceSm),
                        Expanded(
                          child: Text(AppStrings.optimizerPrivacyNotice),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                  _PlatformLinksForm(links: state.links),
                  const SizedBox(height: AppSizes.spaceLg),
                  _OptimizationSuggestions(optimization: state.optimization),
                ],
              ),
            ),
          ),
        );
  }
}

class _PlatformLinksForm extends ConsumerStatefulWidget {
  const _PlatformLinksForm({required this.links});

  final PlatformLinks links;

  @override
  ConsumerState<_PlatformLinksForm> createState() => _PlatformLinksFormState();
}

class _PlatformLinksFormState extends ConsumerState<_PlatformLinksForm> {
  late final TextEditingController _linkedInController;
  late final TextEditingController _githubController;
  late final TextEditingController _portfolioController;
  late final TextEditingController _kaggleController;

  @override
  void initState() {
    super.initState();
    _linkedInController = TextEditingController(text: widget.links.linkedIn);
    _githubController = TextEditingController(text: widget.links.github);
    _portfolioController = TextEditingController(text: widget.links.portfolio);
    _kaggleController = TextEditingController(text: widget.links.kaggle);
  }

  @override
  void didUpdateWidget(covariant _PlatformLinksForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.links != widget.links) {
      _linkedInController.text = widget.links.linkedIn;
      _githubController.text = widget.links.github;
      _portfolioController.text = widget.links.portfolio;
      _kaggleController.text = widget.links.kaggle;
    }
  }

  @override
  void dispose() {
    _linkedInController.dispose();
    _githubController.dispose();
    _portfolioController.dispose();
    _kaggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      title: AppStrings.platformLinksTitle,
      subtitle: AppStrings.platformLinksSubtitle,
      child: Column(
        children: [
          _LinkField(
            controller: _linkedInController,
            label: AppStrings.linkedInLabel,
            icon: AppIcons.linkedIn,
          ),
          _LinkField(
            controller: _githubController,
            label: AppStrings.githubLabel,
            icon: AppIcons.github,
          ),
          _LinkField(
            controller: _portfolioController,
            label: AppStrings.portfolioLabel,
            icon: AppIcons.portfolio,
          ),
          _LinkField(
            controller: _kaggleController,
            label: AppStrings.kaggleLabel,
            icon: AppIcons.kaggle,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(AppIcons.saveOpportunity),
              label: const Text(AppStrings.savePlatformLinks),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await ref
        .read(profileOptimizerViewModelProvider.notifier)
        .saveLinks(
          linkedIn: _linkedInController.text,
          github: _githubController.text,
          portfolio: _portfolioController.text,
          kaggle: _kaggleController.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.platformLinksSaved)),
        );
    }
  }
}

class _LinkField extends StatelessWidget {
  const _LinkField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: AppStrings.platformLinkHint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _OptimizationSuggestions extends StatelessWidget {
  const _OptimizationSuggestions({required this.optimization});

  final ProfileOptimization optimization;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CopySuggestionCard(
          title: AppStrings.linkedInHeadline,
          content: optimization.linkedInHeadline,
        ),
        _CopySuggestionCard(
          title: AppStrings.aboutSectionDraft,
          content: optimization.aboutSectionDraft,
        ),
        _CopySuggestionCard(
          title: AppStrings.skillsToAdd,
          items: optimization.skillsToAdd,
        ),
        _CopySuggestionCard(
          title: AppStrings.featuredProjectsOrder,
          items: optimization.featuredProjectsOrder,
        ),
        _CopySuggestionCard(
          title: AppStrings.projectDescriptions,
          items: optimization.projectDescriptions,
        ),
        _CopySuggestionCard(
          title: AppStrings.recruiterMessageTemplate,
          content: optimization.recruiterMessageTemplate,
        ),
        _CopySuggestionCard(
          title: AppStrings.githubReadmeSuggestions,
          items: optimization.githubReadmeSuggestions,
        ),
        _CopySuggestionCard(
          title: AppStrings.portfolioHeroSection,
          content: optimization.portfolioHeroSection,
        ),
      ],
    );
  }
}

class _CopySuggestionCard extends StatelessWidget {
  const _CopySuggestionCard({
    required this.title,
    this.content,
    this.items = const [],
  });

  final String title;
  final String? content;
  final List<String> items;

  String get copyText => content ?? items.join('\n');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
      child: Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(AppIcons.copy),
                    label: const Text(AppStrings.copySuggestion),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceSm),
              if (content != null)
                SelectableText(content!)
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          AppIcons.recommendation,
                          color: AppColors.optimizerAccent,
                          size: AppSizes.recommendationIconSize,
                        ),
                        const SizedBox(width: AppSizes.spaceSm),
                        Expanded(child: SelectableText(item)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: copyText));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.suggestionCopied)),
        );
    }
  }
}
