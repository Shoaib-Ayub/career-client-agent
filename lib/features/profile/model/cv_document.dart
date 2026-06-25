import 'package:flutter/foundation.dart';

@immutable
class CvDocument {
  const CvDocument({required this.fileName, required this.localPath});

  final String fileName;
  final String localPath;
}
