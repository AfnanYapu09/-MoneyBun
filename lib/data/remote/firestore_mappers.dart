import 'package:drift/drift.dart';

import '../../domain/enums/enums.dart';
import '../local/database.dart';

/// Converts Drift rows <-> Firestore maps. Enums are stored by index and money
/// as int cents. Local-only bookkeeping (syncStatus) is never written remotely;
/// the Firestore doc id IS the row id, so [remoteId] mirrors it on pull.
class FirestoreMappers {
  const FirestoreMappers._();

  // ---- Accounts ----
  static Map<String, dynamic> accountToMap(AccountRow r) => {
        'name': r.name,
        'type': r.type.index,
        'bankCode': r.bankCode,
        'iconKey': r.iconKey,
        'colorHex': r.colorHex,
        'openingBalanceCents': r.openingBalanceCents,
        'currency': r.currency,
        'sortOrder': r.sortOrder,
        'archived': r.archived,
        'watchedForSlips': r.watchedForSlips,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      };

  static AccountsCompanion accountFromMap(String id, Map<String, dynamic> m) =>
      AccountsCompanion(
        id: Value(id),
        name: Value(m['name'] as String? ?? ''),
        type: Value(_enum(AccountType.values, m['type'])),
        bankCode: Value(m['bankCode'] as String?),
        iconKey: Value(m['iconKey'] as String?),
        colorHex: Value(m['colorHex'] as String?),
        openingBalanceCents: Value(
          (m['openingBalanceCents'] as num?)?.toInt() ?? 0,
        ),
        currency: Value(m['currency'] as String? ?? 'THB'),
        sortOrder: Value((m['sortOrder'] as num?)?.toInt() ?? 0),
        archived: Value(m['archived'] == true),
        watchedForSlips: Value(m['watchedForSlips'] != false),
        createdAt: Value((m['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: Value((m['updatedAt'] as num?)?.toInt() ?? 0),
        deleted: Value(m['deleted'] == true),
        remoteId: Value(id),
        syncStatus: const Value(SyncStatus.synced),
      );

  // ---- Categories ----
  static Map<String, dynamic> categoryToMap(CategoryRow r) => {
        'name': r.name,
        'nameEn': r.nameEn,
        'type': r.type.index,
        'iconKey': r.iconKey,
        'colorHex': r.colorHex,
        'parentId': r.parentId,
        'isSystem': r.isSystem,
        'sortOrder': r.sortOrder,
        'archived': r.archived,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      };

  static CategoriesCompanion categoryFromMap(
    String id,
    Map<String, dynamic> m,
  ) =>
      CategoriesCompanion(
        id: Value(id),
        name: Value(m['name'] as String? ?? ''),
        nameEn: Value(m['nameEn'] as String?),
        type: Value(_enum(CategoryType.values, m['type'])),
        iconKey: Value(m['iconKey'] as String? ?? 'other'),
        colorHex: Value(m['colorHex'] as String? ?? 'FF7A736B'),
        parentId: Value(m['parentId'] as String?),
        isSystem: Value(m['isSystem'] == true),
        sortOrder: Value((m['sortOrder'] as num?)?.toInt() ?? 0),
        archived: Value(m['archived'] == true),
        createdAt: Value((m['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: Value((m['updatedAt'] as num?)?.toInt() ?? 0),
        deleted: Value(m['deleted'] == true),
        remoteId: Value(id),
        syncStatus: const Value(SyncStatus.synced),
      );

  // ---- Transactions ----
  static Map<String, dynamic> transactionToMap(TransactionRow r) => {
        'type': r.type.index,
        'amountCents': r.amountCents,
        'currency': r.currency,
        'accountId': r.accountId,
        'toAccountId': r.toAccountId,
        'categoryId': r.categoryId,
        'note': r.note,
        'occurredAt': r.occurredAt,
        'slipId': r.slipId,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      };

  static TransactionsCompanion transactionFromMap(
    String id,
    Map<String, dynamic> m,
  ) =>
      TransactionsCompanion(
        id: Value(id),
        type: Value(_enum(TxnType.values, m['type'])),
        amountCents: Value((m['amountCents'] as num?)?.toInt() ?? 0),
        currency: Value(m['currency'] as String? ?? 'THB'),
        accountId: Value(m['accountId'] as String? ?? ''),
        toAccountId: Value(m['toAccountId'] as String?),
        categoryId: Value(m['categoryId'] as String?),
        note: Value(m['note'] as String?),
        occurredAt: Value((m['occurredAt'] as num?)?.toInt() ?? 0),
        slipId: Value(m['slipId'] as String?),
        createdAt: Value((m['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: Value((m['updatedAt'] as num?)?.toInt() ?? 0),
        deleted: Value(m['deleted'] == true),
        remoteId: Value(id),
        syncStatus: const Value(SyncStatus.synced),
      );

  // ---- Slips ----
  // Note: imagePath is intentionally NOT synced (it is a device-local file
  // path). assetId IS synced so gallery dedup survives a cloud restore on the
  // same device.
  static Map<String, dynamic> slipToMap(SlipRow r) => {
        'source': r.source.index,
        'assetId': r.assetId,
        'photoTakenAt': r.photoTakenAt,
        'bankCode': r.bankCode,
        'transRef': r.transRef,
        'qrPayload': r.qrPayload,
        'amountCents': r.amountCents,
        'occurredAt': r.occurredAt,
        'senderName': r.senderName,
        'senderBank': r.senderBank,
        'receiverName': r.receiverName,
        'receiverBank': r.receiverBank,
        'confidence': r.confidence,
        'verified': r.verified,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      };

  static SlipsCompanion slipFromMap(String id, Map<String, dynamic> m) =>
      SlipsCompanion(
        id: Value(id),
        source: Value(_enum(SlipSource.values, m['source'])),
        assetId: Value(m['assetId'] as String?),
        photoTakenAt: Value((m['photoTakenAt'] as num?)?.toInt()),
        bankCode: Value(m['bankCode'] as String?),
        transRef: Value(m['transRef'] as String?),
        qrPayload: Value(m['qrPayload'] as String?),
        amountCents: Value((m['amountCents'] as num?)?.toInt()),
        occurredAt: Value((m['occurredAt'] as num?)?.toInt()),
        senderName: Value(m['senderName'] as String?),
        senderBank: Value(m['senderBank'] as String?),
        receiverName: Value(m['receiverName'] as String?),
        receiverBank: Value(m['receiverBank'] as String?),
        confidence: Value((m['confidence'] as num?)?.toDouble() ?? 0),
        verified: Value(m['verified'] == true),
        createdAt: Value((m['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: Value((m['updatedAt'] as num?)?.toInt() ?? 0),
        deleted: Value(m['deleted'] == true),
        remoteId: Value(id),
        syncStatus: const Value(SyncStatus.synced),
      );

  // ---- Budgets ----
  static Map<String, dynamic> budgetToMap(BudgetRow r) => {
        'categoryId': r.categoryId,
        'period': r.period.index,
        'amountCents': r.amountCents,
        'startDate': r.startDate,
        'endDate': r.endDate,
        'rollover': r.rollover,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      };

  static BudgetsCompanion budgetFromMap(String id, Map<String, dynamic> m) =>
      BudgetsCompanion(
        id: Value(id),
        categoryId: Value(m['categoryId'] as String?),
        period: Value(_enum(BudgetPeriod.values, m['period'])),
        amountCents: Value((m['amountCents'] as num?)?.toInt() ?? 0),
        startDate: Value((m['startDate'] as num?)?.toInt() ?? 0),
        endDate: Value((m['endDate'] as num?)?.toInt()),
        rollover: Value(m['rollover'] == true),
        createdAt: Value((m['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: Value((m['updatedAt'] as num?)?.toInt() ?? 0),
        deleted: Value(m['deleted'] == true),
        remoteId: Value(id),
        syncStatus: const Value(SyncStatus.synced),
      );

  // ---- Recurring rules ----
  static Map<String, dynamic> recurringRuleToMap(RecurringRuleRow r) => {
        'type': r.type.index,
        'amountCents': r.amountCents,
        'categoryId': r.categoryId,
        'accountId': r.accountId,
        'note': r.note,
        'freq': r.freq.index,
        'nextRunAt': r.nextRunAt,
        'lastRunAt': r.lastRunAt,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      };

  static RecurringRulesCompanion recurringRuleFromMap(
    String id,
    Map<String, dynamic> m,
  ) =>
      RecurringRulesCompanion(
        id: Value(id),
        type: Value(_enum(TxnType.values, m['type'])),
        amountCents: Value((m['amountCents'] as num?)?.toInt() ?? 0),
        categoryId: Value(m['categoryId'] as String?),
        accountId: Value(m['accountId'] as String?),
        note: Value(m['note'] as String?),
        freq: Value(_enum(RecurFreq.values, m['freq'])),
        nextRunAt: Value((m['nextRunAt'] as num?)?.toInt() ?? 0),
        lastRunAt: Value((m['lastRunAt'] as num?)?.toInt()),
        createdAt: Value((m['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: Value((m['updatedAt'] as num?)?.toInt() ?? 0),
        deleted: Value(m['deleted'] == true),
        remoteId: Value(id),
        syncStatus: const Value(SyncStatus.synced),
      );

  // ---- Tags ----
  static Map<String, dynamic> tagToMap(TagRow r) => {
        'name': r.name,
        'colorHex': r.colorHex,
        'sortOrder': r.sortOrder,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      };

  static TagsCompanion tagFromMap(String id, Map<String, dynamic> m) =>
      TagsCompanion(
        id: Value(id),
        name: Value(m['name'] as String? ?? ''),
        colorHex: Value(m['colorHex'] as String?),
        sortOrder: Value((m['sortOrder'] as num?)?.toInt() ?? 0),
        createdAt: Value((m['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: Value((m['updatedAt'] as num?)?.toInt() ?? 0),
        deleted: Value(m['deleted'] == true),
        remoteId: Value(id),
        syncStatus: const Value(SyncStatus.synced),
      );

  static T _enum<T>(List<T> values, Object? raw) {
    final i = (raw as num?)?.toInt() ?? 0;
    return (i >= 0 && i < values.length) ? values[i] : values.first;
  }
}
