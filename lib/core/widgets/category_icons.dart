import 'package:flutter/material.dart';

import '../../domain/enums/enums.dart';

/// Maps stored string keys to [IconData] so categories/accounts stay
/// serialisable and DB-driven while still rendering crisp icons.
class CategoryIcons {
  const CategoryIcons._();

  static const Map<String, IconData> _byKey = {
    'food': Icons.restaurant,
    'shopping': Icons.shopping_bag,
    'education': Icons.school,
    'home': Icons.home,
    'transport': Icons.directions_bus,
    'health': Icons.favorite,
    'entertainment': Icons.sports_esports,
    'salary': Icons.payments,
    'bonus': Icons.card_giftcard,
    'other': Icons.category,
  };

  static IconData forKey(String? key) => _byKey[key] ?? Icons.category;

  static IconData forAccount(AccountType type) => switch (type) {
        AccountType.cash => Icons.payments,
        AccountType.bank => Icons.account_balance,
        AccountType.ewallet => Icons.account_balance_wallet,
        AccountType.savings => Icons.savings,
        AccountType.credit => Icons.credit_card,
      };
}
