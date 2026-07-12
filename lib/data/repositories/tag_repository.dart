import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums/enums.dart';
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
    final existing = id == null ? null : await _db.getTag(id);
    var order = sortOrder;
    if (order == null) {
      // Renaming: keep the tag's position — otherwise upsert would reset
      // sortOrder to 0 and the chip would jump to the front of the row.
      order = existing?.sortOrder;
      // A brand-new tag goes to the end, so chips keep a stable left-to-right
      // sequence in the order they were added.
      if (order == null) {
        var maxOrder = -1;
        for (final t in await _db.getTags()) {
          if (t.sortOrder > maxOrder) maxOrder = t.sortOrder;
        }
        order = maxOrder + 1;
      }
    }
    await _db.upsertTag(
      TagsCompanion.insert(
        id: tagId,
        name: name,
        colorHex: Value(colorHex),
        sortOrder: Value(order),
        // Renames keep the original creation time.
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        // upsertTag only writes columns present on the companion, so a rename
        // of an already-synced tag must flag itself for push here — otherwise
        // the row stays `synced` and the new name never uploads.
        syncStatus: Value(
          existing == null || existing.syncStatus == SyncStatus.pendingCreate
              ? SyncStatus.pendingCreate
              : SyncStatus.pendingUpdate,
        ),
      ),
    );
    return tagId;
  }

  /// Persist a new full chip order (tag ids, first to last) after a drag.
  Future<void> reorder(List<String> idsInOrder) async {
    final byId = {for (final t in await _db.getTags()) t.id: t};
    for (var i = 0; i < idsInOrder.length; i++) {
      final t = byId[idsInOrder[i]];
      if (t == null || t.sortOrder == i) continue;
      await save(id: t.id, name: t.name, colorHex: t.colorHex, sortOrder: i);
    }
  }

  Future<void> delete(String id) => _db.deleteTagCascade(id);
}
