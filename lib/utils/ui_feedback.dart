import 'package:flutter/material.dart';
import 'package:gestion_formations/config/theme.dart';

/// Provides consistent snackbar feedback without changing caller contexts.
extension SnackBarContext on BuildContext {
  void showSnack(
    String message, {
    Color? background,
    Duration? duration,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  void showSuccessSnack(String message) {
    showSnack(message, background: AppTheme.success);
  }

  void showErrorSnack(String message) {
    showSnack(message, background: AppTheme.error);
  }

  void showInfoSnack(String message) {
    showSnack(message);
  }
}
