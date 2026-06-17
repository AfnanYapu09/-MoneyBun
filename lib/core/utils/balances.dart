import '../../data/local/database.dart';
import '../../domain/enums/enums.dart';

/// Pure function: compute the current balance (in cents) of every account from
/// its opening balance plus the effect of all active transactions. Kept pure so
/// it is trivially unit-testable and reactive (recomputed whenever either
/// stream emits).
Map<String, int> computeBalances(
  List<AccountRow> accounts,
  List<TransactionRow> transactions,
) {
  final balances = <String, int>{
    for (final a in accounts) a.id: a.openingBalanceCents,
  };

  for (final t in transactions) {
    if (t.deleted) continue;
    switch (t.type) {
      case TxnType.income:
        balances.update(t.accountId, (v) => v + t.amountCents,
            ifAbsent: () => t.amountCents);
      case TxnType.expense:
        balances.update(t.accountId, (v) => v - t.amountCents,
            ifAbsent: () => -t.amountCents);
      case TxnType.transfer:
        balances.update(t.accountId, (v) => v - t.amountCents,
            ifAbsent: () => -t.amountCents);
        final to = t.toAccountId;
        if (to != null) {
          balances.update(to, (v) => v + t.amountCents,
              ifAbsent: () => t.amountCents);
        }
    }
  }
  return balances;
}
