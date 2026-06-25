import 'package:career_client_agent/features/profile/model/cv_document.dart';
import 'package:career_client_agent/features/profile/service/cv_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cvStorageServiceProvider = Provider<CvStorageService>((ref) {
  return CvStorageService();
});

final cvUploadViewModelProvider =
    AsyncNotifierProvider<CvUploadViewModel, CvDocument?>(
      CvUploadViewModel.new,
    );

class CvUploadViewModel extends AsyncNotifier<CvDocument?> {
  CvStorageService get _service => ref.read(cvStorageServiceProvider);

  @override
  Future<CvDocument?> build() => _service.load();

  Future<bool> upload() async {
    final previousDocument = state.value;
    state = const AsyncLoading();

    try {
      final document = await _service.pickAndStore();
      state = AsyncData(document ?? previousDocument);
      return document != null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> delete() async {
    final document = state.value;
    if (document == null) {
      return;
    }

    state = const AsyncLoading();
    await _service.delete(document);
    state = const AsyncData(null);
  }
}
