// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

class LocalStorage {
  static final Map<String, String> _memoryFallback = {};
  static final Map<String, String> _sessionMemoryFallback = {};

  String? getItem(String key) {
    try {
      return html.window.localStorage[key] ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  void setItem(String key, String value) {
    _memoryFallback[key] = value;
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  void removeItem(String key) {
    _memoryFallback.remove(key);
    try {
      html.window.localStorage.remove(key);
    } catch (_) {}
  }

  // SessionStorage (effacé à la fermeture d'onglet, conservé au rafraîchissement F5)
  String? getSessionItem(String key) {
    try {
      return html.window.sessionStorage[key] ?? _sessionMemoryFallback[key];
    } catch (_) {
      return _sessionMemoryFallback[key];
    }
  }

  void setSessionItem(String key, String value) {
    _sessionMemoryFallback[key] = value;
    try {
      html.window.sessionStorage[key] = value;
    } catch (_) {}
  }

  void removeSessionItem(String key) {
    _sessionMemoryFallback.remove(key);
    try {
      html.window.sessionStorage.remove(key);
    } catch (_) {}
  }

  void clearSession() {
    _sessionMemoryFallback.clear();
    try {
      html.window.sessionStorage.clear();
    } catch (_) {}
  }
}
