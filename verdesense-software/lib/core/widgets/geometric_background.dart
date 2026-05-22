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
        // Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          ),
        ),
        
        // Geometric Shapes
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
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // 1. Large Diagonal Blue Slice (Top Right)
    final path1 = Path();
    path1.moveTo(size.width * 0.4, 0); // Start 40% across top
    path1.lineTo(size.width, 0);       // Top right corner
    path1.lineTo(size.width, size.height * 0.4); // Down right side
    path1.lineTo(0, size.height * 0.15); // Back to left side but lower
    path1.close();

    // Use a gradient for the shape
    paint.shader = LinearGradient(
      colors: [
        AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.15),
        AppColors.accentBlue.withValues(alpha: isDark ? 0.05 : 0.08),
      ],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path1, paint);

    // 2. Secondary Shape (Bottom Left)
    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.lineTo(size.width * 0.4, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    paint.shader = LinearGradient(
      colors: [
        AppColors.accentCyan.withValues(alpha: isDark ? 0.1 : 0.12),
        Colors.transparent,
      ],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path2, paint);

    // 3. Floating Orbs/circles for "Alive" feel
    final circlePaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    circlePaint.color = AppColors.primaryBlue.withValues(alpha: isDark ? 0.1 : 0.12);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 60, circlePaint);

    circlePaint.color = isDark 
        ? AppColors.statusDanger.withValues(alpha: 0.05) 
        : AppColors.statusWarning.withValues(alpha: 0.08); // Warm glow in light mode
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 80, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _GeometricPainter) {
      return oldDelegate.isDark != isDark;
    }
    return true;
  }
}
