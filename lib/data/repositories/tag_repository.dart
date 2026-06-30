import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';

/// User-defined tags (local-only). Used by the category picker and Manage Tags.
class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<TagRow>> watchTags() => _db.watchTags();

  Future<List<TagRow>> getTags() => _db.getTags();

  /// Tag id → number of transactions using it.
  Stream<Map<String, int>> watchUsageCounts() =>
      _db.watchAllTransactionTags().map((links) {
        final counts = <String, int>{};
        for (final l in links) {
          counts.update(l.tagId, (v) => v + 1, ifAbsent: () => 1);
        }
        return counts;
      });

  Future<String> save({
    String? id,
    required String name,
    String? colorHex,
    int? sortOrder,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tagId = id ?? _uuid.v4();
    await _db.upsertTag(
      TagsCompanion.insert(
        id: tagId,
        name: name,
        colorHex: Value(colorHex),
        sortOrder: Value(sortOrder ?? 0),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return tagId;
  }

  Future<void> delete(String id) => _db.deleteTagCascade(id);
}
