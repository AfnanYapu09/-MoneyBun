import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_date.dart';
import '../../domain/entities/parsed_slip.dart';
import '../../domain/enums/enums.dart';
import '../local/database.dart';

class SlipRepository {
  SlipRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Persist a parsed slip and return its id (to link onto a transaction).
  Future<String> save(ParsedSlip slip) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db.upsertSlip(
      SlipsCompanion.insert(
        id: id,
        source: slip.source,
        imagePath: Value(slip.imagePath),
        bankCode: Value(slip.bankCode),
        transRef: Value(slip.transRef),
        qrPayload: Value(slip.qrPayload),
        amountCents: Value(slip.amountCents),
        occurredAt: Value(
          slip.occurredAt == null ? null : AppDate.toMillis(slip.occurredAt!),
        ),
        senderName: Value(slip.senderName),
        senderBank: Value(slip.senderBank),
        receiverName: Value(slip.receiverName),
        receiverBank: Value(slip.receiverBank),
        rawOcrText: Value(slip.rawOcrText),
        confidence: Value(slip.confidence),
        verified: Value(slip.verified),
        createdAt: now,
        updatedAt: now,
        syncStatus: const Value(SyncStatus.pendingCreate),
      ),
    );
    return id;
  }
}
