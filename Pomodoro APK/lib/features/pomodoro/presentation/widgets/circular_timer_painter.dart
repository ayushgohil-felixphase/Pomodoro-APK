import 'dart:math';
import 'package:flutter/material.dart';

class CircularTimerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;
  final double strokeWidth;
  final bool isRunning;

  CircularTimerPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
    this.strokeWidth = 14.0,
    this.isRunning = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // 1. Background Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    // 2. Active Progress Arc with Gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * pi * progress;
    final startAngle = -pi / 2; // Start from top 12 o'clock

    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * pi,
      colors: [primaryColor, secondaryColor, primaryColor],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(-pi / 2),
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

    // 3. Glowing Indicator Head at current progress
    if (progress > 0.01 && progress < 0.99 && isRunning) {
      final headAngle = startAngle + sweepAngle;
      final headX = center.dx + radius * cos(headAngle);
      final headY = center.dy + radius * sin(headAngle);

      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(headX, headY), strokeWidth * 0.7, glowPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(headX, headY), strokeWidth * 0.35, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.isRunning != isRunning;
  }
}
