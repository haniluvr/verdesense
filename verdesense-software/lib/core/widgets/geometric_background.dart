import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GeometricBackground extends StatelessWidget {
  final Widget child;

  const GeometricBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base Gradient — dark maroon to slightly lighter maroon
        Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          ),
        ),

        // Subtle geometric shapes in the maroon palette
        CustomPaint(
          painter: _GeometricPainter(isDark: isDark),
          size: Size.infinite,
        ),

        // Content
        child,
      ],
    );
  }
}

class _GeometricPainter extends CustomPainter {
  final bool isDark;

  _GeometricPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Diagonal rose tint — top right
    final path1 = Path();
    path1.moveTo(size.width * 0.45, 0);
    path1.lineTo(size.width, 0);
    path1.lineTo(size.width, size.height * 0.35);
    path1.lineTo(0, size.height * 0.12);
    path1.close();

    paint.shader = LinearGradient(
      colors: [
        AppColors.primaryRose.withValues(alpha: isDark ? 0.12 : 0.10),
        AppColors.accentRose.withValues(alpha: isDark ? 0.04 : 0.06),
      ],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path1, paint);

    // 2. Bottom-left accent shape
    final path2 = Path();
    path2.moveTo(0, size.height * 0.72);
    path2.lineTo(size.width * 0.38, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    paint.shader = LinearGradient(
      colors: [
        AppColors.borderDark.withValues(alpha: isDark ? 0.35 : 0.20),
        Colors.transparent,
      ],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path2, paint);

    // 3. Soft ambient orbs for depth
    final circlePaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    // Top-right warm rose orb
    circlePaint.color = AppColors.primaryRose.withValues(alpha: isDark ? 0.10 : 0.08);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 70, circlePaint);

    // Bottom-left deep maroon orb
    circlePaint.color = AppColors.borderDark.withValues(alpha: isDark ? 0.25 : 0.15);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.82), 90, circlePaint);

    // 4. Subtle grid / road-map lines to echo the map aesthetic from the design
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.primaryRose.withValues(alpha: isDark ? 0.06 : 0.04);

    // Horizontal lines
    for (int i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    // Vertical lines
    for (int i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _GeometricPainter) return oldDelegate.isDark != isDark;
    return true;
  }
}
