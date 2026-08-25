import 'dart:core';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class AzimuthWidget extends LeafRenderObjectWidget {
  const AzimuthWidget({super.key});

  @override
  AzimuthRenderObject createRenderObject(BuildContext context) {
    return AzimuthRenderObject();
  }
}

class AzimuthRenderObject extends RenderBox with DebugOverflowIndicatorMixin {
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final Size drySize = Size(
      min(constraints.maxWidth, constraints.maxHeight),
      min(constraints.maxWidth, constraints.maxHeight),
    );
    return drySize;
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final List<({double hIndex, double azimuth, double elevation})> solarData =
        [
          (
            hIndex: 7 * 4 + 1,
            azimuth: vector.radians(100),
            elevation: vector.radians(15),
          ),
          (
            hIndex: 9 * 4 + 1,
            azimuth: vector.radians(150),
            elevation: vector.radians(60),
          ),
          (
            hIndex: 11 * 4 + 1,
            azimuth: vector.radians(180),
            elevation: vector.radians(65),
          ),
          (
            hIndex: 13 * 4 + 1,
            azimuth: vector.radians(210),
            elevation: vector.radians(60),
          ),
          (
            hIndex: 15 * 4 + 1,
            azimuth: vector.radians(260),
            elevation: vector.radians(15),
          ),
        ];

    final Offset center = offset + Offset(size.width / 2, size.height / 2);
    final int padding = 40;
    final double circleRadius = size.width / 2 - padding;

    final Iterable<({double hIndex, double x, double y})> solarDataPlotted =
        solarData.map(
          (e) => (
            hIndex: e.hIndex / 4,
            x: circleRadius * sin(e.azimuth) * cos(e.elevation) + center.dx,
            y: -circleRadius * cos(e.azimuth) * cos(e.elevation) + center.dy,
          ),
        );

    final Paint circlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final Paint pathPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    Path solarPath = Path();
    for (final (index, solarDataPlottedSingle) in solarDataPlotted.indexed) {
      if (index == 0) {
        solarPath.moveTo(solarDataPlottedSingle.x, solarDataPlottedSingle.y);
      } else {
        solarPath.lineTo(solarDataPlottedSingle.x, solarDataPlottedSingle.y);
      }
    }

    context.canvas.drawCircle(center, circleRadius, circlePaint);
    context.canvas.drawPath(solarPath, pathPaint);
  }
}
