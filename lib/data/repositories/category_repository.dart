import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums/enums.dart';
import '../local/database.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<CategoryRow>> watchCategories() => _db.watchCategories();

  Future<List<CategoryRow>> getCategories() => _db.getCategories();

  Future<String> save({
    String? id,
    required String name,
    String? nameEn,
    required CategoryType type,
    String iconKey = 'other',
    String colorHex = 'FF7A736B',
    int? sortOrder,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final catId = id ?? _uuid.v4();
    await _db.upsertCategory(
      CategoriesCompanion.insert(
        id: catId,
        name: name,
        type: type,
        nameEn: Value(nameEn),
        iconKey: Value(iconKey),
        colorHex: Value(colorHex),
        sortOrder: Value(sortOrder ?? 0),
        createdAt: now,
        updatedAt: now,
        syncStatus: const Value(SyncStatus.pendingCreate),
      ),
    );
    return catId;
  }
}
