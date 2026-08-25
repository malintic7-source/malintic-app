// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:gestion_formations/utils/app_logger.dart';

class LocalStorage {
  static final Map<String, String> _memoryFallback = {};
  static final Map<String, String> _sessionMemoryFallback = {};

  String? getItem(String key) {
    try {
      return html.window.localStorage[key] ?? _memoryFallback[key];
    } catch (e, s) {
      logHandledError('localStorage illisible ($key), repli mémoire', e, s);
      return _memoryFallback[key];
    }
  }

  void setItem(String key, String value) {
    _memoryFallback[key] = value;
    try {
      html.window.localStorage[key] = value;
    } catch (e, s) {
      logHandledError(
        'Écriture localStorage impossible ($key), données en mémoire seulement',
        e,
        s,
      );
    }
  }

  void removeItem(String key) {
    _memoryFallback.remove(key);
    try {
      html.window.localStorage.remove(key);
    } catch (e, s) {
      logHandledError('Suppression localStorage impossible ($key)', e, s);
    }
  }

  // SessionStorage (effacé à la fermeture d'onglet, conservé au rafraîchissement F5)
  String? getSessionItem(String key) {
    try {
      return html.window.sessionStorage[key] ?? _sessionMemoryFallback[key];
    } catch (e, s) {
      logHandledError('sessionStorage illisible ($key), repli mémoire', e, s);
      return _sessionMemoryFallback[key];
    }
  }

  void setSessionItem(String key, String value) {
    _sessionMemoryFallback[key] = value;
    try {
      html.window.sessionStorage[key] = value;
    } catch (e, s) {
      logHandledError(
        'Écriture sessionStorage impossible ($key), données en mémoire seulement',
        e,
        s,
      );
    }
  }

  void removeSessionItem(String key) {
    _sessionMemoryFallback.remove(key);
    try {
      html.window.sessionStorage.remove(key);
    } catch (e, s) {
      logHandledError('Suppression sessionStorage impossible ($key)', e, s);
    }
  }
}
