import 'package:hive_ce/hive.dart';

class LocalStorageService {
  const LocalStorageService();

  Future<Box<dynamic>> openBox(String boxName) {
    return Hive.openBox<dynamic>(boxName);
  }

  Future<List<Map<dynamic, dynamic>>> getAll(String boxName) async {
    final box = await openBox(boxName);
    return box.values
        .map((value) => Map<dynamic, dynamic>.from(value as Map))
        .toList();
  }

  Future<Map<dynamic, dynamic>?> get(String boxName, String id) async {
    final box = await openBox(boxName);
    final value = box.get(id);
    return value == null ? null : Map<dynamic, dynamic>.from(value as Map);
  }

  Map<dynamic, dynamic>? getSync(String boxName, String id) {
    if (!Hive.isBoxOpen(boxName)) {
      return null;
    }

    final value = Hive.box<dynamic>(boxName).get(id);
    return value == null ? null : Map<dynamic, dynamic>.from(value as Map);
  }

  Future<void> put(String boxName, String id, Map<String, Object> value) async {
    final box = await openBox(boxName);
    await box.put(id, value);
  }

  Future<void> putAll(
    String boxName,
    Map<String, Map<String, Object>> values,
  ) async {
    final box = await openBox(boxName);
    await box.putAll(values);
  }

  Future<void> replaceAll(
    String boxName,
    Map<String, Map<String, Object>> values,
  ) async {
    final box = await openBox(boxName);
    await box.clear();
    await box.putAll(values);
  }

  Future<void> delete(String boxName, String id) async {
    final box = await openBox(boxName);
    await box.delete(id);
  }

  Future<void> clear(String boxName) async {
    final box = await openBox(boxName);
    await box.clear();
  }

  Future<bool> isEmpty(String boxName) async {
    final box = await openBox(boxName);
    return box.isEmpty;
  }
}
