import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';

class OpportunityFilterService {
  const OpportunityFilterService();

  List<T> apply<T extends OpportunityResult>(
    List<T> items,
    OpportunityFilter filter,
  ) {
    final results = [...items];

    switch (filter) {
      case OpportunityFilter.today:
        return _sortByFreshness(
          results
              .where(
                (item) => item.freshnessStatus == OpportunityFreshness.today,
              )
              .toList(),
        );
      case OpportunityFilter.last24Hours:
        return _sortByFreshness(
          results
              .where(
                (item) =>
                    item.freshnessStatus == OpportunityFreshness.today ||
                    item.freshnessStatus == OpportunityFreshness.last24Hours,
              )
              .toList(),
        );
      case OpportunityFilter.last7Days:
        return _sortByFreshness(
          results
              .where(
                (item) =>
                    item.freshnessStatus == OpportunityFreshness.today ||
                    item.freshnessStatus == OpportunityFreshness.last24Hours ||
                    item.freshnessStatus == OpportunityFreshness.last7Days,
              )
              .toList(),
        );
      case OpportunityFilter.all:
        return _sortByFreshness(results);
      case OpportunityFilter.latest:
        return _sortByFreshness(
          results
              .where(
                (item) => item.freshnessStatus != OpportunityFreshness.older,
              )
              .toList(),
        );
      case OpportunityFilter.highestMatch:
        results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      case OpportunityFilter.visaYes:
        return results.where((item) => item.visaSponsorship).toList();
      case OpportunityFilter.fresherFriendly:
        return results.where((item) => item.fresherFriendly).toList();
      case OpportunityFilter.deadlineSoon:
        final now = DateTime.now();
        final threshold = now.add(
          const Duration(days: AppConstants.deadlineSoonDays),
        );
        return results
            .where(
              (item) =>
                  !item.deadline.isBefore(now) &&
                  !item.deadline.isAfter(threshold),
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    }

    return results;
  }

  List<T> _sortByFreshness<T extends OpportunityResult>(List<T> results) {
    results.sort((a, b) {
      final freshness = a.freshnessStatus.priority.compareTo(
        b.freshnessStatus.priority,
      );
      return freshness != 0 ? freshness : b.postedDate.compareTo(a.postedDate);
    });
    return results;
  }
}
