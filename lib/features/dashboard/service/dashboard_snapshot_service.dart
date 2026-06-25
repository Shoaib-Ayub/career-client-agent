import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';

class DashboardSnapshot {
  const DashboardSnapshot({required this.opportunityIds, this.updatedAt});

  final Set<String> opportunityIds;
  final DateTime? updatedAt;
}

abstract interface class DashboardSnapshotStore {
  Future<DashboardSnapshot> read();

  Future<void> save({
    required Set<String> opportunityIds,
    required DateTime updatedAt,
  });
}

class DashboardSnapshotService implements DashboardSnapshotStore {
  const DashboardSnapshotService(this._storage);

  final LocalStorageService _storage;

  @override
  Future<DashboardSnapshot> read() async {
    final value = await _storage.get(
      AppConstants.dashboardMetadataBoxName,
      AppConstants.dashboardSnapshotId,
    );
    if (value == null) {
      return const DashboardSnapshot(opportunityIds: {});
    }

    final ids =
        (value[AppConstants.dashboardOpportunityIdsKey] as List?)
            ?.map((item) => item.toString())
            .toSet() ??
        <String>{};
    final updatedAt = DateTime.tryParse(
      value[AppConstants.dashboardUpdatedAtKey]?.toString() ?? '',
    );
    return DashboardSnapshot(opportunityIds: ids, updatedAt: updatedAt);
  }

  @override
  Future<void> save({
    required Set<String> opportunityIds,
    required DateTime updatedAt,
  }) {
    return _storage.put(
      AppConstants.dashboardMetadataBoxName,
      AppConstants.dashboardSnapshotId,
      {
        AppConstants.dashboardOpportunityIdsKey: opportunityIds.toList(
          growable: false,
        ),
        AppConstants.dashboardUpdatedAtKey: updatedAt.toIso8601String(),
      },
    );
  }
}
