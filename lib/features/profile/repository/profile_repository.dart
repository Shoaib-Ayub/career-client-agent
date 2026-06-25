import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/user_profile_model.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';

class ProfileRepository extends HiveRepository<UserProfileModel> {
  ProfileRepository(LocalStorageService storage)
    : super(
        boxName: AppConstants.profileBoxName,
        decoder: UserProfileModel.fromMap,
        storage: storage,
      );

  Future<UserProfile?> getProfile() async {
    return (await getById(AppConstants.profileRecordId))?.toDomain();
  }

  UserProfile? getProfileSync() {
    final value = storage.getSync(
      AppConstants.profileBoxName,
      AppConstants.profileRecordId,
    );
    return value == null ? null : UserProfileModel.fromMap(value).toDomain();
  }

  Future<void> saveProfile(UserProfile profile) {
    return update(UserProfileModel.fromDomain(profile));
  }
}
