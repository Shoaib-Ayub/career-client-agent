import 'dart:convert';
import 'dart:io';

import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/widgets/opportunity_card.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/government_jobs/data/dto/government_job_dto.dart';
import 'package:career_client_agent/features/government_jobs/data/mapper/government_job_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every item in the latest generated government JSON', () {
    final files =
        Directory('backend_agent/data/government_jobs')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort(
            (first, second) =>
                first.lastModifiedSync().compareTo(second.lastModifiedSync()),
          );
    expect(files, isNotEmpty);

    final payload = jsonDecode(files.last.readAsStringSync()) as List<dynamic>;
    final models = payload
        .map(
          (item) => GovernmentJobMapper.toModel(
            GovernmentJobDto.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        )
        .toList();

    expect(models, isNotEmpty);
    expect(
      models,
      everyElement(
        isA<GovernmentJobModel>()
            .having((job) => job.title, 'title', isNotEmpty)
            .having((job) => job.sourceLink, 'apply link', startsWith('http'))
            .having(
              (job) => job.qualificationRequired,
              'qualification',
              isNotEmpty,
            )
            .having(
              (job) => job.eligibilityReason,
              'eligibility reason',
              isNotEmpty,
            ),
      ),
    );
  });

  test('maps government backend aliases and optional fields safely', () {
    final model = GovernmentJobMapper.toModel(
      GovernmentJobDto.fromJson({
        'title': 'Assistant Director Administration',
        'department': 'Services Department',
        'province_city': 'Punjab, Pakistan',
        'apply_url': 'https://www.ppsc.gop.pk/Jobs.aspx#assistant-director',
        'posted_date': '2026-06-24',
        'application_deadline': '2026-07-08',
        'required_skills': <String>[],
        'source': 'PPSC',
        'qualification_required': 'Bachelor degree in any discipline',
        'domicile_required': 'Punjab domicile',
        'province_eligibility': 'Yes',
        'eligibility_reason':
            'Punjab residents with a bachelor degree qualify.',
        'advertisement_number': '08/2026',
        'post_count': 2,
        'job_scale': 'BS-17',
        'force_category': '',
      }),
    );

    expect(model.organization, 'Services Department');
    expect(model.sourceName, 'PPSC');
    expect(model.sourceLink, contains('ppsc.gop.pk'));
    expect(model.qualificationRequired, contains('Bachelor'));
    expect(model.domicileRequired, 'Punjab domicile');
    expect(model.provinceEligibility, 'Yes');
    expect(model.advertisementNumber, '08/2026');
    expect(model.postCount, 2);
    expect(model.jobScale, 'BS-17');
    expect(model.whyMatch, contains(model.eligibilityReason));
  });

  testWidgets(
    'government card displays available details and tolerates missing ones',
    (tester) async {
      final job = GovernmentJobModel(
        id: 'government-1',
        title: 'Inspector',
        organization: 'Federal Investigation Agency',
        location: 'Pakistan',
        sourceLink: 'https://online.fpsc.gov.pk/#inspector',
        postedDate: DateTime(2026, 6, 24),
        deadline: DateTime(2026, 7, 10),
        requiredSkills: const [],
        matchScore: 80,
        fresherFriendly: false,
        visaSponsorship: false,
        trainingProvided: false,
        whyMatch: const [],
        cvSuggestions: const [],
        sourceName: 'FPSC',
        qualificationRequired: 'Graduation or equivalent qualification',
        domicileRequired: 'Open merit',
        provinceEligibility: 'Yes',
        eligibilityReason: 'Punjab residents may apply through open merit.',
        postCount: 4,
        jobScale: 'BS-16',
        forceCategory: 'Federal Investigation',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OpportunityCard(
                  opportunity: job,
                  applicationType: ApplicationType.govtJob,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Graduation or equivalent'), findsOneWidget);
      expect(find.textContaining('Open merit'), findsOneWidget);
      expect(find.textContaining('BS-16'), findsOneWidget);
      expect(find.textContaining('FPSC'), findsOneWidget);
      expect(find.text(AppStrings.viewSource), findsOneWidget);
    },
  );
}
