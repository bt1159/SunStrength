import 'dart:core';
import 'dart:math';
import 'package:color_map/color_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class AzimuthWidget extends StatelessWidget {
  const AzimuthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrbitAndSolarValuesListNotifier, DayIndexNotifier>(
      builder:
          (context, orbitAndSolarValuesListNotifier, dayIndexNotifier, child) {
            final OrbitAndSolarValues orbitAndSolarValues =
                orbitAndSolarValuesListNotifier.value[dayIndexNotifier.value];
            return Selector<SavedSettingsNotifier, Colormap?>(
              selector: (_, savedAppSettingsNotifier) =>
                  savedAppSettingsNotifier.value?.colorScheme.$2,
              builder: (context, colormap, child) {
                return AzimuthRenderObjectWidget(
                  child: FutureBuilderAzimuthChart(
                    orbitAndSolarValues: orbitAndSolarValues,
                    colormap: colormap,
                  ),
                );
              },
            );
          },
    );
  }
}

class FutureBuilderAzimuthChart extends StatefulWidget {
  const FutureBuilderAzimuthChart({
    super.key,
    required this.orbitAndSolarValues,
    this.colormap,
  });

  final OrbitAndSolarValues orbitAndSolarValues;
  final Colormap? colormap;
  @override
  State<FutureBuilderAzimuthChart> createState() =>
      _FutureBuilderAzimuthChartState();
}

class _FutureBuilderAzimuthChartState extends State<FutureBuilderAzimuthChart> {
  late Future<ChartImageContainer> futureAzimuthImage;

  Future<ChartImageContainer> createAzimuthImage() {}

  @override
  void initState() {
    super.initState();
    futureAzimuthImage = createAzimuthImage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChartImageContainer>(
      future: futureAzimuthImage,
      builder: (context, AsyncSnapshot<ChartImageContainer> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Snapshot Error: ${snapshot.error}'));
        }
        if (snapshot.hasData) {
          return CustomPaint(painter: ImagePainter(snapshot.data!.image));
        }
        if (snapshot.data == null) {
          return const Center(child: Text('No location selected'));
        } else {
          return const Center(child: Text('No Image'));
        }
      },
    );
  }
}

class AzimuthRenderObjectWidget extends SingleChildRenderObjectWidget {
  const AzimuthRenderObjectWidget({super.key, super.child});

  @override
  AzimuthRenderObject createRenderObject(BuildContext context) {
    return AzimuthRenderObject();
  }
}

class AzimuthRenderObject extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>, DebugOverflowIndicatorMixin {
  AzimuthRenderObject();

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
