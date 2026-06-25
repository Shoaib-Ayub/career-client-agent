import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/profile/view_model/profile_view_model.dart';
import 'package:career_client_agent/features/profile_optimizer/model/platform_links.dart';
import 'package:career_client_agent/features/profile_optimizer/model/profile_optimizer_state.dart';
import 'package:career_client_agent/features/profile_optimizer/service/profile_optimizer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileOptimizerServiceProvider = Provider<ProfileOptimizerService>((
  ref,
) {
  return const ProfileOptimizerService();
});

final profileOptimizerViewModelProvider =
    AsyncNotifierProvider<ProfileOptimizerViewModel, ProfileOptimizerState>(
      ProfileOptimizerViewModel.new,
    );

class ProfileOptimizerViewModel extends AsyncNotifier<ProfileOptimizerState> {
  @override
  Future<ProfileOptimizerState> build() async {
    final profile = ref.watch(profileViewModelProvider);
    final links = await ref.read(profileOptimizerRepositoryProvider).getLinks();
    return ProfileOptimizerState(
      links: links,
      optimization: ref.read(profileOptimizerServiceProvider).generate(profile),
    );
  }

  Future<void> saveLinks({
    required String linkedIn,
    required String github,
    required String portfolio,
    required String kaggle,
  }) async {
    final links = PlatformLinks(
      linkedIn: linkedIn.trim(),
      github: github.trim(),
      portfolio: portfolio.trim(),
      kaggle: kaggle.trim(),
    );
    await ref.read(profileOptimizerRepositoryProvider).saveLinks(links);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(links: links));
    }
  }
}
