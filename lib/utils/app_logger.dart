import 'package:flutter/foundation.dart';

/// Reports a failure that is recovered from locally instead of being
/// propagated to the caller.
///
/// Every recovered failure stays visible in the logs so that storage quota
/// errors, corrupted caches or refused server writes cannot disappear silently.
void logHandledError(String context, Object error, [StackTrace? stackTrace]) {
  debugPrint('[Malintic] $context: $error');
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace, label: '[Malintic] $context');
  }
}
