import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/application_tracker_model.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';

class ApplicationTrackerRepository
    extends HiveRepository<ApplicationTrackerModel> {
  ApplicationTrackerRepository(LocalStorageService storage)
    : super(
        boxName: AppConstants.applicationTrackerBoxName,
        decoder: ApplicationTrackerModel.fromMap,
        storage: storage,
      );

  Future<List<ApplicationTrackerItem>> getItems() async {
    final items = (await getAll()).map((model) => model.toDomain()).toList();
    items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }

  Future<void> saveItem(ApplicationTrackerItem item) {
    return update(ApplicationTrackerModel.fromDomain(item));
  }

  Future<bool> containsOpportunity(String opportunityId) async {
    final items = await getAll();
    return items.any((item) => item.opportunityId == opportunityId);
  }
}
