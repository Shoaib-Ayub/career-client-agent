import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/platform_links_model.dart';
import 'package:career_client_agent/features/profile_optimizer/model/platform_links.dart';

class ProfileOptimizerRepository extends HiveRepository<PlatformLinksModel> {
  ProfileOptimizerRepository(LocalStorageService storage)
    : super(
        boxName: AppConstants.profileOptimizerBoxName,
        decoder: PlatformLinksModel.fromMap,
        storage: storage,
      );

  Future<PlatformLinks> getLinks() async {
    return (await getById(AppConstants.platformLinksRecordId))?.toDomain() ??
        const PlatformLinks();
  }

  Future<void> saveLinks(PlatformLinks links) {
    return update(PlatformLinksModel.fromDomain(links));
  }
}
