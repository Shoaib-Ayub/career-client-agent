import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_list_state.dart';
import 'package:career_client_agent/features/opportunities/view_model/opportunity_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clientLeadsViewModelProvider =
    AsyncNotifierProvider<
      ClientLeadsViewModel,
      OpportunityListState<ClientLeadModel>
    >(ClientLeadsViewModel.new);

class ClientLeadsViewModel
    extends AsyncNotifier<OpportunityListState<ClientLeadModel>> {
  List<ClientLeadModel> _allItems = const [];

  @override
  Future<OpportunityListState<ClientLeadModel>> build() async {
    _allItems = await ref.read(clientLeadsRepositoryProvider).getAll();
    return _stateFor(OpportunityFilter.latest);
  }

  void selectFilter(OpportunityFilter filter) {
    state = AsyncData(_stateFor(filter));
  }

  Future<bool> refresh() async {
    final current = state.value;
    if (current == null || current.isRefreshing) {
      return false;
    }

    final filter = current.selectedFilter;
    state = AsyncData(current.copyWith(isRefreshing: true));
    try {
      _allItems = await ref.read(clientLeadsRepositoryProvider).fetchLatest();
      state = AsyncData(_stateFor(filter));
      return true;
    } on Exception {
      state = AsyncData(current.copyWith(isRefreshing: false));
      return false;
    }
  }

  OpportunityListState<ClientLeadModel> _stateFor(OpportunityFilter filter) {
    final items = ref
        .read(opportunityFilterServiceProvider)
        .apply(_allItems, filter);
    return OpportunityListState(items: items, selectedFilter: filter);
  }
}
