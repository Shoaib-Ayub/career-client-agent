import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';

class OpportunityListState<T extends OpportunityResult> {
  const OpportunityListState({
    required this.items,
    required this.selectedFilter,
    this.isRefreshing = false,
  });

  final List<T> items;
  final OpportunityFilter selectedFilter;
  final bool isRefreshing;

  OpportunityListState<T> copyWith({
    List<T>? items,
    OpportunityFilter? selectedFilter,
    bool? isRefreshing,
  }) {
    return OpportunityListState<T>(
      items: items ?? this.items,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
