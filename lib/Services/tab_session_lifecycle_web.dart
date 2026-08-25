import 'dart:js_interop';

import 'package:gestion_formations/utils/app_logger.dart';

@JS('malinticActivateTabSession')
external void _activateTabSession();

@JS('malinticDeactivateTabSession')
external void _deactivateTabSession();

class TabSessionLifecycle {
  static void activate() {
    try {
      _activateTabSession();
    } catch (e, s) {
      logHandledError(
        'Activation du cycle de vie de l’onglet impossible',
        e,
        s,
      );
    }
  }

  static void deactivate() {
    try {
      _deactivateTabSession();
    } catch (e, s) {
      logHandledError(
        'Désactivation du cycle de vie de l’onglet impossible',
        e,
        s,
      );
    }
  }
}
