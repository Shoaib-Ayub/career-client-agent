import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/widgets/opportunity_card.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/client_leads/data/dto/client_lead_dto.dart';
import 'package:career_client_agent/features/client_leads/data/mapper/client_lead_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps new backend client lead fields safely', () {
    final dto = ClientLeadDto.fromJson({
      'title': 'Flutter AI mobile application',
      'organization': 'Marketplace Client',
      'location': 'Remote',
      'source_link': 'https://example.com/project/42',
      'posted_date': '2026-06-24',
      'deadline': '',
      'required_skills': ['Flutter', 'TFLite'],
      'lead_category': 'Mobile AI Project',
      'budget': r'$500',
      'budget_type': 'Fixed',
      'platform': 'Freelancer.com',
      'proposal_url': 'https://example.com/project/42',
      'lead_score': 95,
      'why_good_lead': ['Matches Flutter and mobile AI skills.'],
      'suggested_message': 'Normal proposal',
      'short_message': 'Short proposal',
      'manual_action': '',
      'expected_lead_type': 'Mobile AI Project',
      'search_keyword': 'Flutter AI Integration',
      'platform_project_id': '42',
    });

    final model = ClientLeadMapper.toModel(dto);
    final restored = ClientLeadModel.fromMap(model.toMap());

    expect(restored.leadCategory, 'Mobile AI Project');
    expect(restored.budget, r'$500');
    expect(restored.platform, 'Freelancer.com');
    expect(restored.leadScore, 95);
    expect(restored.shortMessage, 'Short proposal');
    expect(restored.expectedLeadType, 'Mobile AI Project');
    expect(restored.searchKeyword, 'Flutter AI Integration');
    expect(restored.platformProjectId, '42');
  });

  testWidgets('real lead card expands to show proposals and project details', (
    tester,
  ) async {
    final lead = _lead(
      leadCategory: 'Flutter Client Project',
      leadScore: 100,
      suggestedMessage: 'Normal Flutter proposal message.',
      shortMessage: 'Short Flutter proposal.',
      platformProjectId: '40535417',
    );

    await _pumpCard(tester, lead);

    expect(find.text('Flutter Client Project'), findsOneWidget);
    expect(
      find.text(
        AppStrings.labeledValue(AppStrings.leadPlatformLabel, 'Freelancer.com'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.labeledValue(AppStrings.leadBudgetLabel, r'$500')),
      findsOneWidget,
    );
    expect(find.text('Normal Flutter proposal message.'), findsNothing);
    expect(find.text('Short Flutter proposal.'), findsNothing);
    expect(find.text(AppStrings.manualActionLabel), findsNothing);
    expect(find.byTooltip(AppStrings.copyProposal), findsNothing);
    expect(find.text(AppStrings.openProposal), findsNothing);
    expect(find.text(AppStrings.showDetails), findsOneWidget);

    await tester.tap(find.text(AppStrings.showDetails));
    await tester.pumpAndSettle();

    expect(find.text('Normal Flutter proposal message.'), findsOneWidget);
    expect(find.text('Short Flutter proposal.'), findsOneWidget);
    expect(find.byTooltip(AppStrings.copyProposal), findsNWidgets(2));
    expect(find.text(AppStrings.openProposal), findsOneWidget);
    expect(find.text(AppStrings.hideDetails), findsOneWidget);
  });

  testWidgets('fallback card expands to show guidance without proposals', (
    tester,
  ) async {
    final lead = _lead(
      title: 'Fallback Board Link - Workana - TensorFlow Lite',
      leadCategory: AppStrings.fallbackBoardCategory,
      leadScore: 45,
      suggestedMessage: '',
      shortMessage: '',
      manualAction:
          'Open this board, filter latest projects, and apply selectively.',
      expectedLeadType: 'TFLite / YOLO Project',
      searchKeyword: 'TensorFlow Lite',
      platformProjectId: '',
    );

    await _pumpCard(tester, lead);

    expect(find.text(AppStrings.fallbackBoardCategory), findsOneWidget);
    expect(find.textContaining('TFLite / YOLO Project'), findsNothing);
    expect(
      find.text(
        'Open this board, filter latest projects, and apply selectively.',
      ),
      findsNothing,
    );
    expect(find.text(AppStrings.suggestedMessageLabel), findsNothing);
    expect(find.text(AppStrings.shortMessageLabel), findsNothing);
    expect(find.byTooltip(AppStrings.copyProposal), findsNothing);
    expect(find.text(AppStrings.openBoard), findsNothing);

    await tester.tap(find.text(AppStrings.showDetails));
    await tester.pumpAndSettle();

    expect(find.textContaining('TensorFlow Lite'), findsWidgets);
    expect(find.textContaining('TFLite / YOLO Project'), findsOneWidget);
    expect(
      find.text(
        'Open this board, filter latest projects, and apply selectively.',
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.suggestedMessageLabel), findsNothing);
    expect(find.text(AppStrings.shortMessageLabel), findsNothing);
    expect(find.byTooltip(AppStrings.copyProposal), findsNothing);
    expect(find.text(AppStrings.openBoard), findsOneWidget);
  });
}

ClientLeadModel _lead({
  String title = 'Flutter AI mobile application',
  required String leadCategory,
  required int leadScore,
  required String suggestedMessage,
  required String shortMessage,
  String manualAction = '',
  String expectedLeadType = '',
  String searchKeyword = '',
  required String platformProjectId,
}) {
  final now = DateTime(2026, 6, 24);
  return ClientLeadModel(
    id: 'lead-1',
    title: title,
    organization: 'Marketplace Client',
    location: 'Remote',
    sourceLink: 'https://example.com/project/42',
    postedDate: now,
    deadline: now.add(const Duration(days: 7)),
    requiredSkills: const ['Flutter', 'Firebase'],
    matchScore: 90,
    fresherFriendly: false,
    visaSponsorship: false,
    trainingProvided: false,
    whyMatch: const [],
    cvSuggestions: const [],
    leadCategory: leadCategory,
    budget: r'$500',
    budgetType: 'Fixed',
    country: 'Remote',
    platform: 'Freelancer.com',
    proposalUrl: 'https://example.com/project/42',
    leadScore: leadScore,
    whyGoodLead: const ['Matches the configured skills.'],
    suggestedMessage: suggestedMessage,
    shortMessage: shortMessage,
    manualAction: manualAction,
    expectedLeadType: expectedLeadType,
    searchKeyword: searchKeyword,
    platformProjectId: platformProjectId,
  );
}

Future<void> _pumpCard(WidgetTester tester, ClientLeadModel lead) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OpportunityCard(
              opportunity: lead,
              applicationType: ApplicationType.clientLead,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
