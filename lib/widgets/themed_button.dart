import 'package:flutter/material.dart';

import '../theme/app_assets.dart';

/// Drop-in replacement for [ElevatedButton] using the gold-gradient asset as
/// its background, for primary/confirming actions (save, play, submit).
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return Opacity(
      opacity: disabled && !isLoading ? 0.5 : 1,
      child: SizedBox(
        height: height,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppAssets.btnPrimaryGold),
                fit: BoxFit.fill,
              ),
            ),
            child: InkWell(
              onTap: disabled ? null : onPressed,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF241A05),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Drop-in replacement for [OutlinedButton] using the dark glass asset as its
/// background, for secondary actions.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return Opacity(
      opacity: disabled && !isLoading ? 0.5 : 1,
      child: SizedBox(
        height: height,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppAssets.btnSecondaryGlass),
                fit: BoxFit.fill,
              ),
            ),
            child: InkWell(
              onTap: disabled ? null : onPressed,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
