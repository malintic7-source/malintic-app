import 'dart:js_interop';

@JS('malinticActivateTabSession')
external void _activateTabSession();

@JS('malinticDeactivateTabSession')
external void _deactivateTabSession();

class TabSessionLifecycle {
  static void activate() {
    try {
      _activateTabSession();
    } catch (_) {}
  }

  static void deactivate() {
    try {
      _deactivateTabSession();
    } catch (_) {}
  }
}
