import 'package:flutter/widgets.dart';

import '../../domain/enums/enums.dart';
import 'app_icons.dart';

/// Maps stored string keys to Lucide [IconData] so categories/accounts stay
/// serialisable and DB-driven. Keys are unchanged from the original seed data.
class CategoryIcons {
  const CategoryIcons._();

  static const Map<String, IconData> _byKey = {
    'food': AppIcons.utensils,
    'shopping': AppIcons.shoppingBag,
    'education': AppIcons.graduationCap,
    'home': AppIcons.house,
    'transport': AppIcons.bus,
    'health': AppIcons.heartPulse,
    'entertainment': AppIcons.clapperboard,
    'lend': AppIcons.gift,
    'transfer': AppIcons.arrowLeftRight,
    'salary': AppIcons.banknote,
    'bonus': AppIcons.gift,
    'family': AppIcons.pawPrint,
    'travel': AppIcons.palmtree,
    'work': AppIcons.briefcase,
    'package': AppIcons.package,
    'health_fitness': AppIcons.dumbbell,
    'other': AppIcons.ellipsis,
    // Account / bank icon keys (Accounts sheet, account pickers).
    'cash': AppIcons.banknote,
    'wallet': AppIcons.wallet,
    'sprout': AppIcons.sprout,
    'landmark': AppIcons.landmark,
    'gem': AppIcons.gem,
    'droplet': AppIcons.droplet,
    'building2': AppIcons.building2,
    'store': AppIcons.store,
  };

  static IconData forKey(String? key) => _byKey[key] ?? AppIcons.ellipsis;

  static IconData forAccount(AccountType type) => switch (type) {
        AccountType.cash => AppIcons.banknote,
        AccountType.bank => AppIcons.landmark,
        AccountType.ewallet => AppIcons.wallet,
        AccountType.savings => AppIcons.sprout,
        AccountType.credit => AppIcons.creditCard,
      };
}
