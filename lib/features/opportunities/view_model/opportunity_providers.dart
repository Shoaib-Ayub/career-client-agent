import 'package:career_client_agent/features/opportunities/service/opportunity_filter_service.dart';
import 'package:career_client_agent/features/opportunities/service/personalization_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final opportunityFilterServiceProvider = Provider<OpportunityFilterService>((
  ref,
) {
  return const OpportunityFilterService();
});

final personalizationServiceProvider = Provider<PersonalizationService>((ref) {
  return const PersonalizationService();
});
