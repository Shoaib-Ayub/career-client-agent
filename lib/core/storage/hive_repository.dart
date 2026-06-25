import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';

typedef ModelDecoder<T> = T Function(Map<dynamic, dynamic> map);

class HiveRepository<T extends LocalModel> {
  const HiveRepository({
    required this.boxName,
    required this.decoder,
    required this.storage,
  });

  final String boxName;
  final ModelDecoder<T> decoder;
  final LocalStorageService storage;

  Future<List<T>> getAll() async {
    final values = await storage.getAll(boxName);
    return values.map(decoder).toList();
  }

  Future<T?> getById(String id) async {
    final value = await storage.get(boxName, id);
    return value == null ? null : decoder(value);
  }

  Future<void> create(T model) => storage.put(boxName, model.id, model.toMap());

  Future<void> update(T model) => storage.put(boxName, model.id, model.toMap());

  Future<void> delete(String id) => storage.delete(boxName, id);

  Future<void> createAll(List<T> models) {
    return storage.putAll(boxName, {
      for (final model in models) model.id: model.toMap(),
    });
  }

  Future<void> replaceAll(List<T> models) {
    return storage.replaceAll(boxName, {
      for (final model in models) model.id: model.toMap(),
    });
  }

  Future<bool> get isEmpty => storage.isEmpty(boxName);
}
