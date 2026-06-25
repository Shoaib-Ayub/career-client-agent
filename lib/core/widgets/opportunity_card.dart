import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/core/utils/app_date_formatter.dart';
import 'package:career_client_agent/core/widgets/match_score_badge.dart';
import 'package:career_client_agent/core/widgets/recommendation_card.dart';
import 'package:career_client_agent/core/widgets/skill_list.dart';
import 'package:career_client_agent/core/widgets/source_link_button.dart';
import 'package:career_client_agent/core/widgets/status_badge.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/application_tracker/view_model/application_tracker_view_model.dart';
import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OpportunityCard extends ConsumerStatefulWidget {
  const OpportunityCard({
    required this.opportunity,
    required this.applicationType,
    super.key,
  });

  final OpportunityResult opportunity;
  final ApplicationType applicationType;

  @override
  ConsumerState<OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends ConsumerState<OpportunityCard> {
  bool _showClientLeadDetails = false;

  @override
  Widget build(BuildContext context) {
    final opportunity = widget.opportunity;
    final textTheme = Theme.of(context).textTheme;
    final isClientLead = opportunity is ClientLeadModel;
    final clientLead = opportunity is ClientLeadModel ? opportunity : null;
    final governmentJob = opportunity is GovernmentJobModel
        ? opportunity
        : null;

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
                        opportunity.title,
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        opportunity.organization,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                MatchScoreBadge(score: opportunity.matchScore),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Row(
              children: [
                const Icon(AppIcons.location, color: AppColors.textSecondary),
                const SizedBox(width: AppSizes.spaceXs),
                Expanded(child: Text(opportunity.location)),
              ],
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Wrap(
              spacing: AppSizes.spaceLg,
              runSpacing: AppSizes.spaceXs,
              children: [
                _DateLabel(
                  label: AppStrings.postedLabel,
                  date: opportunity.postedDate,
                ),
                _DateLabel(
                  label: AppStrings.deadlineLabel,
                  date: opportunity.deadline,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            SkillList(skills: opportunity.requiredSkills),
            const SizedBox(height: AppSizes.spaceMd),
            if (governmentJob != null) ...[
              _GovernmentJobDetails(job: governmentJob),
              const SizedBox(height: AppSizes.spaceMd),
            ],
            if (opportunity is ClientLeadModel) ...[
              _ClientLeadDetails(
                lead: opportunity,
                isExpanded: _showClientLeadDetails,
              ),
              const SizedBox(height: AppSizes.spaceSm),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showClientLeadDetails = !_showClientLeadDetails;
                  });
                },
                icon: Icon(
                  _showClientLeadDetails ? AppIcons.collapse : AppIcons.expand,
                ),
                label: Text(
                  _showClientLeadDetails
                      ? AppStrings.hideDetails
                      : AppStrings.showDetails,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMd),
            ],
            if (!isClientLead) ...[
              Wrap(
                spacing: AppSizes.spaceXs,
                runSpacing: AppSizes.spaceXs,
                children: [
                  StatusBadge(
                    label: AppStrings.statusValue(
                      AppStrings.fresherFriendlyLabel,
                      opportunity.fresherFriendly,
                    ),
                    isPositive: opportunity.fresherFriendly,
                  ),
                  StatusBadge(
                    label: AppStrings.statusValue(
                      AppStrings.visaSponsorshipLabel,
                      opportunity.visaSponsorship,
                    ),
                    isPositive: opportunity.visaSponsorship,
                  ),
                  StatusBadge(
                    label: AppStrings.statusValue(
                      AppStrings.trainingProvidedLabel,
                      opportunity.trainingProvided,
                    ),
                    isPositive: opportunity.trainingProvided,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceLg),
              if (governmentJob == null ||
                  governmentJob.eligibilityReason.isEmpty)
                RecommendationCard(
                  title: AppStrings.whyMatchLabel,
                  items: opportunity.whyMatch,
                ),
              const SizedBox(height: AppSizes.spaceMd),
              RecommendationCard(
                title: AppStrings.cvSuggestionsLabel,
                items: opportunity.cvSuggestions,
              ),
              const SizedBox(height: AppSizes.spaceMd),
            ],
            Wrap(
              spacing: AppSizes.spaceSm,
              runSpacing: AppSizes.spaceSm,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final saved = await ref
                        .read(applicationTrackerViewModelProvider.notifier)
                        .saveOpportunity(
                          opportunity: opportunity,
                          type: widget.applicationType,
                        );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            saved
                                ? AppStrings.opportunitySaved
                                : AppStrings.opportunityAlreadySaved,
                          ),
                        ),
                      );
                  },
                  icon: const Icon(AppIcons.saveOpportunity),
                  label: const Text(AppStrings.saveOpportunity),
                ),
                if (!isClientLead && opportunity.sourceLink.isNotEmpty)
                  SourceLinkButton(sourceLink: opportunity.sourceLink),
                if (clientLead != null &&
                    _showClientLeadDetails &&
                    clientLead.proposalUrl.isNotEmpty)
                  SourceLinkButton(
                    sourceLink: clientLead.proposalUrl,
                    label:
                        clientLead.leadCategory ==
                            AppStrings.fallbackBoardCategory
                        ? AppStrings.openBoard
                        : AppStrings.openProposal,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GovernmentJobDetails extends StatelessWidget {
  const _GovernmentJobDetails({required this.job});

  final GovernmentJobModel job;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LeadInfoRow(
          label: AppStrings.governmentQualificationLabel,
          value: job.qualificationRequired,
        ),
        _LeadInfoRow(
          label: AppStrings.governmentDomicileLabel,
          value: job.domicileRequired,
        ),
        _LeadInfoRow(
          label: AppStrings.governmentEligibilityLabel,
          value: job.provinceEligibility,
        ),
        _LeadInfoRow(
          label: AppStrings.governmentScaleLabel,
          value: job.jobScale,
        ),
        if (job.postCount != null)
          _LeadInfoRow(
            label: AppStrings.governmentPostCountLabel,
            value: job.postCount.toString(),
          ),
        _LeadInfoRow(
          label: AppStrings.governmentAdvertisementLabel,
          value: job.advertisementNumber,
        ),
        _LeadInfoRow(
          label: AppStrings.governmentForceCategoryLabel,
          value: job.forceCategory,
        ),
        _LeadInfoRow(
          label: AppStrings.governmentSourceLabel,
          value: job.sourceName,
        ),
        if (job.eligibilityReason.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spaceSm),
          RecommendationCard(
            title: AppStrings.governmentEligibilityReasonLabel,
            items: [job.eligibilityReason],
          ),
        ],
      ],
    );
  }
}

class _ClientLeadDetails extends StatelessWidget {
  const _ClientLeadDetails({required this.lead, required this.isExpanded});

  final ClientLeadModel lead;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final isFallback = lead.leadCategory == AppStrings.fallbackBoardCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSizes.spaceXs,
          runSpacing: AppSizes.spaceXs,
          children: [
            StatusBadge(
              label: AppStrings.labeledValue(
                AppStrings.leadScoreLabel,
                AppStrings.scoreValue(lead.leadScore),
              ),
              isPositive: lead.leadScore >= AppConstants.positiveMatchThreshold,
            ),
            if (lead.leadCategory.isNotEmpty)
              StatusBadge(label: lead.leadCategory, isPositive: true),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMd),
        _LeadInfoRow(label: AppStrings.leadPlatformLabel, value: lead.platform),
        _LeadInfoRow(
          label: AppStrings.leadBudgetLabel,
          value: lead.budget.isEmpty ? AppStrings.unknownBudget : lead.budget,
        ),
        _LeadInfoRow(
          label: AppStrings.leadBudgetTypeLabel,
          value: lead.budgetType,
        ),
        if (isExpanded) ...[
          _LeadInfoRow(label: AppStrings.leadCountryLabel, value: lead.country),
          if (lead.platformProjectId.isNotEmpty)
            _LeadInfoRow(
              label: AppStrings.platformProjectIdLabel,
              value: lead.platformProjectId,
            ),
          if (isFallback) ...[
            _LeadInfoRow(
              label: AppStrings.searchKeywordLabel,
              value: lead.searchKeyword,
            ),
            _LeadInfoRow(
              label: AppStrings.expectedLeadTypeLabel,
              value: lead.expectedLeadType,
            ),
          ],
          const SizedBox(height: AppSizes.spaceMd),
          if (lead.whyGoodLead.isNotEmpty)
            RecommendationCard(
              title: AppStrings.whyGoodLeadLabel,
              items: lead.whyGoodLead,
            ),
          if (isFallback && lead.manualAction.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceMd),
            _LeadMessagePanel(
              title: AppStrings.manualActionLabel,
              message: lead.manualAction,
              showCopyAction: false,
            ),
          ],
          if (!isFallback && lead.suggestedMessage.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceMd),
            _LeadMessagePanel(
              title: AppStrings.suggestedMessageLabel,
              message: lead.suggestedMessage,
            ),
          ],
          if (!isFallback && lead.shortMessage.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceMd),
            _LeadMessagePanel(
              title: AppStrings.shortMessageLabel,
              message: lead.shortMessage,
            ),
          ],
        ],
      ],
    );
  }
}

class _LeadMessagePanel extends StatelessWidget {
  const _LeadMessagePanel({
    required this.title,
    required this.message,
    this.showCopyAction = true,
  });

  final String title;
  final String message;
  final bool showCopyAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(
          color: AppColors.border,
          width: AppSizes.borderWidth,
        ),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (showCopyAction)
                IconButton(
                  tooltip: AppStrings.copyProposal,
                  onPressed: () => _copy(context),
                  icon: const Icon(AppIcons.copy),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceXs),
          SelectableText(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(AppStrings.proposalCopied)));
  }
}

class _LeadInfoRow extends StatelessWidget {
  const _LeadInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceXs),
      child: Text(
        AppStrings.labeledValue(label, value),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.label, required this.date});

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          AppIcons.calendar,
          color: AppColors.textSecondary,
          size: AppSizes.recommendationIconSize,
        ),
        const SizedBox(width: AppSizes.spaceXs),
        Text(
          AppStrings.labeledValue(label, AppDateFormatter.compact(date)),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
