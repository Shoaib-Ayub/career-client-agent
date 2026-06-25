import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/widgets/cv_upload_card.dart';
import 'package:career_client_agent/core/widgets/match_score_badge.dart';
import 'package:career_client_agent/core/widgets/profile_card.dart';
import 'package:career_client_agent/core/widgets/recommendation_card.dart';
import 'package:career_client_agent/core/widgets/skill_chip.dart';
import 'package:career_client_agent/features/jobs/model/match_result.dart';
import 'package:career_client_agent/features/jobs/view_model/jobs_view_model.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:career_client_agent/features/profile/view_model/cv_upload_view_model.dart';
import 'package:career_client_agent/features/profile/view_model/profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _educationController;
  late final TextEditingController _cgpaController;
  late final TextEditingController _skillsController;
  late final TextEditingController _locationController;
  late final TextEditingController _careerGoalsController;
  late final TextEditingController _countriesController;
  late final TextEditingController _jobTypesController;
  late final TextEditingController _experienceController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileViewModelProvider);
    _nameController = TextEditingController(text: profile.name);
    _educationController = TextEditingController(text: profile.education);
    _cgpaController = TextEditingController(text: profile.cgpa.toString());
    _skillsController = TextEditingController(
      text: profile.skills.join(AppConstants.listDisplaySeparator),
    );
    _locationController = TextEditingController(text: profile.location);
    _careerGoalsController = TextEditingController(text: profile.careerGoals);
    _countriesController = TextEditingController(
      text: profile.preferredCountries.join(AppConstants.listDisplaySeparator),
    );
    _jobTypesController = TextEditingController(
      text: profile.preferredJobTypes.join(AppConstants.listDisplaySeparator),
    );
    _experienceController = TextEditingController(
      text: profile.experienceYears.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _educationController.dispose();
    _cgpaController.dispose();
    _skillsController.dispose();
    _locationController.dispose();
    _careerGoalsController.dispose();
    _countriesController.dispose();
    _jobTypesController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileViewModelProvider);
    final cvState = ref.watch(cvUploadViewModelProvider);
    final job = ref.watch(featuredJobProvider);
    final match = ref.watch(featuredMatchProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.profileSectionMaxWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          children: [
            _ProfileSummary(profile: profile),
            const SizedBox(height: AppSizes.spaceLg),
            _buildProfileForm(context),
            const SizedBox(height: AppSizes.spaceLg),
            CvUploadCard(
              document: cvState.value,
              isLoading: cvState.isLoading,
              onUpload: _uploadCv,
              onDelete: _deleteCv,
            ),
            const SizedBox(height: AppSizes.spaceLg),
            _MatchAnalysisCard(
              jobTitle: job.title,
              company: job.company,
              result: match,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm(BuildContext context) {
    return ProfileCard(
      title: AppStrings.profileDetailsTitle,
      subtitle: AppStrings.profileDetailsSubtitle,
      child: Column(
        children: [
          _ProfileTextField(
            controller: _nameController,
            label: AppStrings.nameLabel,
            icon: AppIcons.profile,
          ),
          _ProfileTextField(
            controller: _educationController,
            label: AppStrings.educationLabel,
            icon: AppIcons.education,
          ),
          _ProfileTextField(
            controller: _cgpaController,
            label: AppStrings.cgpaLabel,
            icon: AppIcons.education,
            keyboardType: TextInputType.number,
          ),
          _ProfileTextField(
            controller: _skillsController,
            label: AppStrings.skillsLabel,
            icon: AppIcons.match,
            helperText: AppStrings.commaSeparatedHint,
          ),
          _ProfileTextField(
            controller: _locationController,
            label: AppStrings.locationLabel,
            icon: AppIcons.location,
          ),
          _ProfileTextField(
            controller: _careerGoalsController,
            label: AppStrings.careerGoalsLabel,
            icon: AppIcons.careerGoals,
            maxLines: AppSizes.formFieldMaxLines,
          ),
          _ProfileTextField(
            controller: _countriesController,
            label: AppStrings.preferredCountriesLabel,
            icon: AppIcons.country,
            helperText: AppStrings.commaSeparatedHint,
          ),
          _ProfileTextField(
            controller: _jobTypesController,
            label: AppStrings.preferredJobTypesLabel,
            icon: AppIcons.jobType,
            helperText: AppStrings.commaSeparatedHint,
          ),
          _ProfileTextField(
            controller: _experienceController,
            label: AppStrings.experienceYearsLabel,
            icon: AppIcons.experience,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSizes.spaceSm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saveProfile,
              child: const Text(AppStrings.saveProfile),
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile() {
    ref
        .read(profileViewModelProvider.notifier)
        .saveFromInput(
          name: _nameController.text,
          education: _educationController.text,
          cgpa: _cgpaController.text,
          skills: _skillsController.text,
          location: _locationController.text,
          careerGoals: _careerGoalsController.text,
          preferredCountries: _countriesController.text,
          preferredJobTypes: _jobTypesController.text,
          experienceYears: _experienceController.text,
        );
    _showMessage(AppStrings.profileSaved);
  }

  Future<void> _uploadCv() async {
    final uploaded = await ref
        .read(cvUploadViewModelProvider.notifier)
        .upload();
    if (mounted) {
      _showMessage(
        uploaded ? AppStrings.cvUploaded : AppStrings.cvUploadFailed,
      );
    }
  }

  Future<void> _deleteCv() async {
    await ref.read(cvUploadViewModelProvider.notifier).delete();
    if (mounted) {
      _showMessage(AppStrings.cvDeleted);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      title: profile.name,
      subtitle: profile.careerGoals,
      trailing: const CircleAvatar(
        radius: AppSizes.profileAvatarRadius,
        backgroundColor: AppColors.navigationIndicator,
        child: Icon(
          AppIcons.profile,
          color: AppColors.primary,
          size: AppSizes.dashboardIconSize,
        ),
      ),
      child: Wrap(
        spacing: AppSizes.spaceXs,
        runSpacing: AppSizes.spaceXs,
        children: profile.skills
            .map((skill) => SkillChip(label: skill))
            .toList(),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.helperText,
    this.keyboardType,
    this.maxLines = AppSizes.formFieldMinLines,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? helperText;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _MatchAnalysisCard extends StatelessWidget {
  const _MatchAnalysisCard({
    required this.jobTitle,
    required this.company,
    required this.result,
  });

  final String jobTitle;
  final String company;
  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      title: AppStrings.matchAnalysisTitle,
      subtitle: AppStrings.matchAnalysisSubtitle,
      trailing: MatchScoreBadge(score: result.overallScore),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            jobTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.spaceXs),
          Text(
            company,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.spaceLg),
          _MatchMetric(label: AppStrings.skillMatch, score: result.skillScore),
          _MatchMetric(
            label: AppStrings.educationMatch,
            score: result.educationScore,
          ),
          _MatchMetric(
            label: AppStrings.experienceMatch,
            score: result.experienceScore,
          ),
          _MatchMetric(
            label: AppStrings.locationMatch,
            score: result.locationScore,
          ),
          _MatchMetric(
            label: AppStrings.visaPreferenceMatch,
            score: result.visaPreferenceScore,
          ),
          const SizedBox(height: AppSizes.spaceMd),
          Text(
            AppStrings.missingSkills,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.spaceSm),
          Wrap(
            spacing: AppSizes.spaceXs,
            runSpacing: AppSizes.spaceXs,
            children: result.missingSkills.isEmpty
                ? const [SkillChip(label: AppStrings.noMissingSkills)]
                : result.missingSkills
                      .map((skill) => SkillChip(label: skill))
                      .toList(),
          ),
          const SizedBox(height: AppSizes.spaceLg),
          RecommendationCard(
            title: AppStrings.whyMatch,
            items: result.whyMatch,
          ),
          if (result.suggestedImprovements.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceMd),
            RecommendationCard(
              title: AppStrings.suggestedImprovements,
              items: result.suggestedImprovements,
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchMetric extends StatelessWidget {
  const _MatchMetric({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(AppStrings.scoreValue(score)),
            ],
          ),
          const SizedBox(height: AppSizes.spaceXs),
          LinearProgressIndicator(
            value: score / AppConstants.maximumMatchScore,
            minHeight: AppSizes.matchProgressHeight,
            color: AppColors.primary,
            backgroundColor: AppColors.navigationIndicator,
            borderRadius: BorderRadius.circular(AppSizes.badgeRadius),
          ),
        ],
      ),
    );
  }
}
