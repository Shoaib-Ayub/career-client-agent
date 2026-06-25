import 'dart:io';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/features/profile/model/cv_document.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef CvFilePicker = Future<FilePickerResult?> Function();

class CvStorageService {
  CvStorageService({
    CvFilePicker? filePicker,
    SharedPreferencesAsync? preferences,
  }) : _filePicker = filePicker ?? _pickCv,
       _preferences = preferences ?? SharedPreferencesAsync();

  final CvFilePicker _filePicker;
  final SharedPreferencesAsync _preferences;

  Future<CvDocument?> load() async {
    final path = await _preferences.getString(AppConstants.cvPathPreferenceKey);
    final name = await _preferences.getString(AppConstants.cvNamePreferenceKey);

    if (path == null || name == null || !await File(path).exists()) {
      return null;
    }

    return CvDocument(fileName: name, localPath: path);
  }

  Future<CvDocument?> pickAndStore() async {
    final result = await _filePicker();

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final selectedFile = result.files.single;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final cvDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}'
      '${AppConstants.cvStorageDirectory}',
    );
    await cvDirectory.create(recursive: true);

    final storedPath =
        '${cvDirectory.path}${Platform.pathSeparator}${selectedFile.name}';
    final previousDocument = await load();

    if (previousDocument != null && previousDocument.localPath != storedPath) {
      await _deleteFile(previousDocument.localPath);
    }

    await File(selectedFile.path!).copy(storedPath);
    await _preferences.setString(AppConstants.cvPathPreferenceKey, storedPath);
    await _preferences.setString(
      AppConstants.cvNamePreferenceKey,
      selectedFile.name,
    );

    return CvDocument(fileName: selectedFile.name, localPath: storedPath);
  }

  static Future<FilePickerResult?> _pickCv() {
    return FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.cvAllowedExtensions,
    );
  }

  Future<void> delete(CvDocument document) async {
    await _deleteFile(document.localPath);
    await _preferences.remove(AppConstants.cvPathPreferenceKey);
    await _preferences.remove(AppConstants.cvNamePreferenceKey);
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
