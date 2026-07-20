import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared floating snackbar styled to match the dark navy/gold theme
/// instead of Material's default opaque grey bar, with a red-tinted
/// variant for errors so failures read as distinct from confirmations.
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppColors.red : AppColors.green,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cardTop.withValues(alpha: 0.96),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isError ? AppColors.red.withValues(alpha: 0.5) : AppColors.cardBorder),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  static void showError(BuildContext context, String message) => show(context, message, isError: true);

  static void showSuccess(BuildContext context, String message) => show(context, message, isError: false);

  /// Strips the `Exception: ` prefix Dart adds to rethrown errors, then shows as an error snackbar.
  static void showErrorFromException(BuildContext context, Object error) {
    show(context, error.toString().replaceAll('Exception: ', ''), isError: true);
  }
}
