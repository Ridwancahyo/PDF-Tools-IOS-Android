import 'package:material_ui/material_ui.dart';

/// Paints a classic Photoshop-style checkerboard behind transparent PNG images.
class CheckerboardBackground extends StatelessWidget {
  final Widget child;
  final double cellSize;
  final BorderRadius borderRadius;

  const CheckerboardBackground({
    super.key,
    required this.child,
    this.cellSize = 12,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius,
      child: CustomPaint(
        painter: _CheckerPainter(
          cellSize: cellSize,
          lightColor: isDark ? const Color(0xFF283440) : const Color(0xFFF3F4F6),
          darkColor: isDark ? const Color(0xFF1D2731) : const Color(0xFFDDE2E8),
        ),
        child: child,
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  _CheckerPainter({
    required this.cellSize,
    required this.lightColor,
    required this.darkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = lightColor;
    final p2 = Paint()..color = darkColor;
    canvas.drawRect(Offset.zero & size, p1);
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            p2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter oldDelegate) =>
      oldDelegate.lightColor != lightColor ||
      oldDelegate.darkColor != darkColor ||
      oldDelegate.cellSize != cellSize;
}
