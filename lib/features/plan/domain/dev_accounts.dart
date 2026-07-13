/// Firebase UIDs that always resolve to Ultra, bypassing `proMonth` /
/// `ultraUntil` entirely — the app owner's own account(s), so development
/// and support never get stuck behind the same limits real users have. Not
/// shown anywhere in the UI; purely a bypass at plan-resolution time in
/// [Plan.resolve].
class DevAccounts {
  const DevAccounts._();

  /// Afnan_YP — the app's developer.
  static const uids = {'Y3Q8o9welfbLLCMr0RdvvDLkaZw1'};

  static bool isDev(String uid) => uids.contains(uid);
}
