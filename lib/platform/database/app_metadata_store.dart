import 'package:drift/drift.dart' as drift;

import 'app_database.dart';

class AppMetadataStore {
  AppMetadataStore({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<String?> read(String key) async {
    final query = _database.select(_database.appMetadataEntries)
      ..where((table) => table.key.equals(key))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String? value) {
    return _database.into(_database.appMetadataEntries).insertOnConflictUpdate(
      AppMetadataEntriesCompanion(
        key: drift.Value(key),
        value: drift.Value(value),
      ),
    );
  }
}
