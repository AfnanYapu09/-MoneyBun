import 'package:flutter/foundation.dart';

/// Dispose a dialog-scoped [ChangeNotifier] (usually a TextEditingController)
/// after the route that used it has fully animated out.
///
/// Disposing synchronously right after `await showDialog(...)` races the
/// route's reverse transition: the auto-focused TextField's IME connection
/// closes mid-animation and calls back into the already-disposed controller —
/// "A TextEditingController was used after being disposed" in debug builds.
/// The dialog reverse transition is ~200ms; 400 leaves margin.
void disposeAfterRouteExit(ChangeNotifier controller) {
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
}
