import 'package:flutter/foundation.dart';

/// Configuration pour le polling HTTP avec exponential backoff
/// 
/// Permet d'optimiser la charge serveur et de gérer les erreurs de connexion.
/// Utilisation :
/// ```dart
/// final config = PollingConfig(
///   minInterval: Duration(seconds: 2),      // 2 sec en conditions normales
///   maxInterval: Duration(minutes: 1),      // max 60 sec si erreurs répétées
///   backoffMultiplier: 1.5,                 // x1.5 à chaque erreur
/// );
/// ```
class PollingConfig {
  /// Intervalle de polling minimal (en conditions normales)
  /// Par défaut: 2 secondes
  final Duration minInterval;

  /// Intervalle de polling maximal (en cas d'erreurs répétées)
  /// Par défaut: 60 secondes
  final Duration maxInterval;

  /// Multiplicateur pour backoff exponentiel
  /// Chaque erreur : interval = interval * backoffMultiplier
  /// Par défaut: 1.5
  final double backoffMultiplier;

  /// Réinitialiser backoff après combien de succès consécutifs
  /// Par défaut: 3 succès réinitialise à minInterval
  final int successCountBeforeReset;

  /// Timeout pour chaque requête HTTP
  /// Par défaut: 15 secondes
  final Duration requestTimeout;

  /// Enable debug logs
  /// Par défaut: false
  final bool enableDebugLogs;

  PollingConfig({
    this.minInterval = const Duration(seconds: 2),
    this.maxInterval = const Duration(minutes: 1),
    this.backoffMultiplier = 1.5,
    this.successCountBeforeReset = 3,
    this.requestTimeout = const Duration(seconds: 15),
    this.enableDebugLogs = false,
  })  : assert(
          minInterval < maxInterval,
          'minInterval must be < maxInterval',
        ),
        assert(
          backoffMultiplier > 1.0,
          'backoffMultiplier must be > 1.0',
        );

  /// Preset: Production (charge serveur minimale)
  factory PollingConfig.production() => PollingConfig(
        minInterval: const Duration(seconds: 5),    // Plus espacé
        maxInterval: const Duration(minutes: 5),     // Max 5 min
        backoffMultiplier: 2.0,                      // Backoff plus agressif
        successCountBeforeReset: 5,                  // Reset après 5 succès
        requestTimeout: const Duration(seconds: 20),
      );

  /// Preset: Development (temps réel)
  factory PollingConfig.development() => PollingConfig(
        minInterval: const Duration(seconds: 1),
        maxInterval: const Duration(seconds: 10),
        backoffMultiplier: 1.3,
        successCountBeforeReset: 2,
        requestTimeout: const Duration(seconds: 10),
        enableDebugLogs: true,
      );

  /// Preset: HighLatency (réseau lent/instable)
  factory PollingConfig.highLatency() => PollingConfig(
        minInterval: const Duration(seconds: 3),
        maxInterval: const Duration(minutes: 2),
        backoffMultiplier: 1.8,
        successCountBeforeReset: 4,
        requestTimeout: const Duration(seconds: 25),
      );

  @override
  String toString() =>
      'PollingConfig(min: ${minInterval.inSeconds}s, max: ${maxInterval.inSeconds}s, backoff: $backoffMultiplier, reset: $successCountBeforeReset)';
}

/// Contrôleur pour le polling avec exponential backoff
/// 
/// Utilisation :
/// ```dart
/// final controller = PollingController(PollingConfig());
/// 
/// // Notification de succès
/// controller.recordSuccess();  // Interval revient vers min
/// 
/// // Notification d'erreur
/// controller.recordError();   // Interval augmente avec backoff
/// 
/// // Obtenir l'intervalle actuel
/// final interval = controller.getCurrentInterval();
/// ```
class PollingController {
  final PollingConfig config;

  Duration _currentInterval;
  int _consecutiveErrors = 0;
  int _consecutiveSuccesses = 0;

  PollingController(this.config) : _currentInterval = config.minInterval;

  /// Obtenir l'intervalle actuel
  Duration getCurrentInterval() => _currentInterval;

  /// Obtenir nombre d'erreurs consécutives
  int getConsecutiveErrors() => _consecutiveErrors;

  /// Notifier d'un succès (réduit l'intervalle si seuil atteint)
  void recordSuccess() {
    _consecutiveErrors = 0;
    _consecutiveSuccesses++;

    if (_consecutiveSuccesses >= config.successCountBeforeReset) {
      _currentInterval = config.minInterval;
      _consecutiveSuccesses = 0;

      if (config.enableDebugLogs) {
        debugPrint(
          '[PollingController] ✅ Succès ${config.successCountBeforeReset} fois → reset à ${_currentInterval.inSeconds}s',
        );
      }
    }
  }

  /// Notifier d'une erreur (augmente l'intervalle avec backoff)
  void recordError() {
    _consecutiveErrors++;
    _consecutiveSuccesses = 0;

    final newInterval = Duration(
      milliseconds: (
        _currentInterval.inMilliseconds * config.backoffMultiplier
      ).toInt(),
    );

    _currentInterval = newInterval.compareTo(config.maxInterval) > 0
        ? config.maxInterval
        : newInterval;

    if (config.enableDebugLogs) {
      debugPrint(
        '[PollingController] ❌ Erreur #$_consecutiveErrors → backoff à ${_currentInterval.inSeconds}s',
      );
    }
  }

  /// Reset manuel
  void reset() {
    _currentInterval = config.minInterval;
    _consecutiveErrors = 0;
    _consecutiveSuccesses = 0;

    if (config.enableDebugLogs) {
      debugPrint('[PollingController] 🔄 Reset manuel → ${_currentInterval.inSeconds}s');
    }
  }

  /// État actuel pour debug/monitoring
  Map<String, dynamic> getStatus() => {
        'currentInterval': _currentInterval.inSeconds,
        'consecutiveErrors': _consecutiveErrors,
        'consecutiveSuccesses': _consecutiveSuccesses,
        'isAtMaxInterval': _currentInterval == config.maxInterval,
      };
}
