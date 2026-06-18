/// Core enums shared across the data, domain and presentation layers.
///
/// Enum values are persisted by their **index** (via Drift `intEnum`) and by
/// index in Firestore, so the ORDER of values must never change — only append.
library;

/// Kind of a transaction.
enum TxnType {
  income,
  expense,
  transfer,
}

/// Kind of wallet / account.
enum AccountType {
  cash,
  bank,
  ewallet, // e.g. TrueMoney, ShopeePay
  savings,
  credit,
}

/// Sync state of a locally stored row relative to Firestore.
enum SyncStatus {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
}

/// How a slip's data was obtained.
enum SlipSource {
  qrOnly,
  ocr,
  apiVerified,
}

/// Budgeting period (used by the budgets feature).
///
/// NOTE: persisted by index — only append, never reorder.
enum BudgetPeriod {
  monthly,
  weekly,
  yearly,
}

/// Category direction. Transfers never carry a category.
enum CategoryType {
  income,
  expense,
}
