import 'dart:core';
// import 'dart:math';
// import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
// import 'package:sun_strength_app/models/saved_settings_notifier.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';

class ColorScaleWidget extends LeafRenderObjectWidget {
  const ColorScaleWidget({super.key});

  @override
  ColorScaleRenderObject createRenderObject(BuildContext context) {
    return ColorScaleRenderObject();
  }
}

class ColorScaleRenderObject extends RenderBox
    with DebugOverflowIndicatorMixin {
  ColorScaleRenderObject({
    this.labelStyle = const TextStyle(fontSize: 12, color: Colors.white),
  });

  final double barHeight = 20;
  final double vertGap = 4;
  final TextStyle labelStyle;
  final List<String> labelValues = [
    '0%',
    '10%',
    '20%',
    '30%',
    '40%',
    '50%',
    '60%',
    '70%',
    '80%',
    '90%',
    '100%',
  ];
  TextPainter labelTextPainter(int index) => TextPainter(
    text: TextSpan(
      text: labelValues[index.clamp(0, labelValues.length - 1)],
      style: labelStyle,
    ),
    textDirection: TextDirection.ltr,
  );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final farLeftTextPainter = labelTextPainter(0)..layout();

    final Size drySize = Size.fromHeight(
      barHeight + vertGap + farLeftTextPainter.height,
    );
    final actualSize = constraints.constrain(drySize);
    return actualSize;
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;

    // Layout the two extremem labels so that I can use half of the widths to get the color bar's width
    final farLeftTextPainter = labelTextPainter(0)..layout();
    final farRightTextPainter = labelTextPainter(labelValues.length - 1)
      ..layout();

    // Define size of colored bar
    final Size rectSize = Size(
      size.width -
          (farLeftTextPainter.width / 2 + farRightTextPainter.width / 2),
      barHeight,
    );
    final Offset rectOffset = offset + Offset(farLeftTextPainter.width / 2, 0);
    final Rect rect = rectOffset & rectSize;

    // Define painting (i.e, gradient) for colored bar
    final Paint gradientPainter = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Color(0xFF000000),
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFFFFFFFF),
        ],
        stops: <double>[0.0, 1 / 3, 2 / 3, 1.0],
      ).createShader(rect);

    // Draw the rectangle onto the canvas
    canvas.drawRect(rect, gradientPainter);

    // Define style for vertical lines in bar
    final Paint gridPaint = Paint()
      // ..color = Colors.black.withValues(alpha: 0.25)
      ..color = Colors.blue.withValues(alpha: 0.25)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final double labelSpacing = (rectSize.width / (labelValues.length - 1));

    // Draw vertical lines in bar
    for (int i = 1; i < labelValues.length - 1; i++) {
      final double x = rectOffset.dx + labelSpacing * i;
      context.canvas.drawLine(
        Offset(x, offset.dy),
        Offset(x, offset.dy + barHeight),
        gridPaint,
      );
    }

    // Draw labels
    for (int i = 0; i < labelValues.length; i++) {
      final TextPainter textPainter = labelTextPainter(i)..layout();
      final double xPos = offset.dx + labelSpacing * i;
      final double yPos = offset.dy + barHeight + vertGap; // 4px gap below bar

      final double clampedX = xPos.clamp(
        offset.dx,
        offset.dx + size.width - textPainter.width,
      );

      textPainter.paint(canvas, Offset(clampedX, yPos));
    }
  }
}
