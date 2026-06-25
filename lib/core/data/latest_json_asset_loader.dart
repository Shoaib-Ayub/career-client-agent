import 'dart:convert';

import 'package:flutter/services.dart';

class LatestJsonAssetLoader {
  LatestJsonAssetLoader({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  Future<List<Map<String, dynamic>>> loadLatest(String directory) async {
    final manifest = await AssetManifest.loadFromAssetBundle(_assetBundle);
    final paths =
        manifest
            .listAssets()
            .where(
              (path) => path.startsWith(directory) && path.endsWith('.json'),
            )
            .toList()
          ..sort();

    if (paths.isEmpty) {
      return const [];
    }

    final latestTimestamp = paths
        .map(_timestamp)
        .whereType<String>()
        .fold<String?>(null, (latest, value) {
          if (latest == null || value.compareTo(latest) > 0) {
            return value;
          }
          return latest;
        });
    final latestPaths = latestTimestamp == null
        ? [paths.last]
        : paths.where((path) => _timestamp(path) == latestTimestamp).toList();

    final results = <Map<String, dynamic>>[];
    for (final path in latestPaths) {
      final source = await _assetBundle.loadString(path, cache: false);
      final payload = jsonDecode(source);
      if (payload is! List) {
        throw const FormatException();
      }
      results.addAll(
        payload.map(
          (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
        ),
      );
    }
    return results;
  }

  static String? _timestamp(String path) {
    return RegExp(r'_(\d{8}T\d{6}Z)\.json$').firstMatch(path)?.group(1);
  }
}
