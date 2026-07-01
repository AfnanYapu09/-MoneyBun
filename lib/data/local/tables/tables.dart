import 'package:drift/drift.dart';

import '../../../domain/enums/enums.dart';

// Every table carries the same sync bookkeeping columns so the SyncEngine can
// treat them uniformly: updatedAt (ms), syncStatus, remoteId, and a soft-delete
// flag (rows are never hard-deleted while a delete still needs to be pushed).

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<AccountType>()();
  TextColumn get bankCode => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  TextColumn get colorHex => text().nullable()();
  IntColumn get openingBalanceCents =>
      integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('THB'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Whether MoneyBun auto-reads slips for this account (Accounts sheet toggle).
  BoolColumn get watchedForSlips =>
      boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(
        Constant(SyncStatus.pendingCreate.index),
      )();
  TextColumn get remoteId => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get nameEn => text().nullable()();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get iconKey => text().withDefault(const Constant('other'))();
  TextColumn get colorHex => text().withDefault(const Constant('FF7A736B'))();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(
        Constant(SyncStatus.pendingCreate.index),
      )();
  TextColumn get remoteId => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<TxnType>()();
  IntColumn get amountCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('THB'))();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get occurredAt => integer()();
  TextColumn get slipId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(
        Constant(SyncStatus.pendingCreate.index),
      )();
  TextColumn get remoteId => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SlipRow')
class Slips extends Table {
  TextColumn get id => text()();
  TextColumn get imagePath => text().nullable()();

  /// Source gallery asset id (Android album auto-scan) — used to skip re-imports.
  TextColumn get assetId => text().nullable()();

  /// When the source photo was created in the gallery (epoch ms). Synced, so
  /// the "read slips newer than the latest one" watermark survives a reinstall
  /// or sign-out/in: it is recomputed as the max of this over imported slips.
  IntColumn get photoTakenAt => integer().nullable()();
  IntColumn get source => intEnum<SlipSource>()();
  TextColumn get bankCode => text().nullable()();
  TextColumn get transRef => text().nullable()();
  TextColumn get qrPayload => text().nullable()();
  IntColumn get amountCents => integer().nullable()();
  IntColumn get occurredAt => integer().nullable()();
  TextColumn get senderName => text().nullable()();
  TextColumn get senderBank => text().nullable()();
  TextColumn get receiverName => text().nullable()();
  TextColumn get receiverBank => text().nullable()();
  TextColumn get rawOcrText => text().nullable()();
  RealColumn get confidence => real().withDefault(const Constant(0))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(
        Constant(SyncStatus.pendingCreate.index),
      )();
  TextColumn get remoteId => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-defined tags. Synced per-user (last-write-wins) like the other
/// entities; a transaction's tag ids ride along inside its cloud document.
@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorHex => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(
        Constant(SyncStatus.pendingCreate.index),
      )();
  TextColumn get remoteId => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Many-to-many link between transactions and tags. Synced by embedding the
/// tag ids in each transaction's cloud document (no separate collection).
@DataClassName('TransactionTagRow')
class TransactionTags extends Table {
  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

/// Simple key/value app settings (theme, currency, savings goal, PIN, …).
/// Local-only — never synced.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get period => intEnum<BudgetPeriod>()();
  IntColumn get amountCents => integer()();
  IntColumn get startDate => integer()();
  IntColumn get endDate => integer().nullable()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(
        Constant(SyncStatus.pendingCreate.index),
      )();
  TextColumn get remoteId => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
