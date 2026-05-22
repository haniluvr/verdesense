import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomNotificationModal {
  /// Full-screen blocking dialog with a DISMISS button. Auto-dismisses after 2.5s.
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    required bool isSuccess,
    bool isDestructive = false,
    Color? customColor,
    IconData? customIcon,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Auto-dismiss after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final Color surfaceColor = isDark ? const Color(0xFF1E2433) : Colors.white;
        final Color primaryColor = customColor ??
            (isDestructive
                ? AppColors.statusDanger
                : (isSuccess ? AppColors.statusSafe : AppColors.statusDanger));
        final IconData primaryIcon = customIcon ??
            (isDestructive
                ? Icons.delete_outline_rounded
                : (isSuccess ? Icons.check_circle_rounded : Icons.error_rounded));

        return Dialog(
          backgroundColor: surfaceColor,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: primaryColor.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(primaryIcon, color: primaryColor, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isSuccess ? "VERIFIED SUCCESS" : "VERIFICATION FAILED",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 8,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "DISMISS",
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Non-blocking toast banner that slides in from the top and auto-dismisses.
  /// No button press required — just appears and fades away after [durationMs].
  static void showToast({
    required BuildContext context,
    required String title,
    required String message,
    Color? color,
    IconData? icon,
    int durationMs = 3000,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color toastColor = color ?? AppColors.statusSafe;
    final IconData toastIcon = icon ?? Icons.check_circle_rounded;

    final animController = ValueNotifier<double>(0.0);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 40,
        left: 24,
        right: 24,
        child: ValueListenableBuilder<double>(
          valueListenable: animController,
          builder: (_, val, __) => AnimatedOpacity(
            opacity: val,
            duration: const Duration(milliseconds: 300),
            child: AnimatedSlide(
              offset: Offset(0, val == 0 ? -0.3 : 0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2433) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: toastColor.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: toastColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.4 : 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: toastColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(toastIcon, color: toastColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color:
                                    isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Trigger slide-in AFTER first frame so the animation plays (0 → 1)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      animController.value = 1.0;
    });

    // Auto-dismiss after duration
    Future.delayed(Duration(milliseconds: durationMs), () {
      animController.value = 0.0;
      Future.delayed(const Duration(milliseconds: 350), () {
        if (entry.mounted) entry.remove();
        animController.dispose();
      });
    });
  }

  /// Like showToast but accepts a pre-captured OverlayState and isDark value.
  /// Use this when the BuildContext may no longer be valid (e.g. after a dialog pop).
  static void showToastDirect({
    required OverlayState overlay,
    required bool isDark,
    required String title,
    required String message,
    Color? color,
    IconData? icon,
    int durationMs = 3000,
  }) {
    final Color toastColor = color ?? AppColors.statusSafe;
    final IconData toastIcon = icon ?? Icons.check_circle_rounded;

    final animController = ValueNotifier<double>(0.0);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 40,
        left: 24,
        right: 24,
        child: ValueListenableBuilder<double>(
          valueListenable: animController,
          builder: (_, val, __) => AnimatedOpacity(
            opacity: val,
            duration: const Duration(milliseconds: 300),
            child: AnimatedSlide(
              offset: Offset(0, val == 0 ? -0.3 : 0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2433) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: toastColor.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: toastColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: toastColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(toastIcon, color: toastColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      animController.value = 1.0;
    });

    Future.delayed(Duration(milliseconds: durationMs), () {
      animController.value = 0.0;
      Future.delayed(const Duration(milliseconds: 350), () {
        if (entry.mounted) entry.remove();
        animController.dispose();
      });
    });
  }
}
