import 'package:career_client_agent/features/opportunities/service/opportunity_filter_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final opportunityFilterServiceProvider = Provider<OpportunityFilterService>((
  ref,
) {
  return const OpportunityFilterService();
});
