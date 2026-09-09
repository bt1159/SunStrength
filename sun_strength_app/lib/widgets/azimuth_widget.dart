import 'dart:core';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';

class AzimuthWidget extends StatelessWidget {
  const AzimuthWidget({super.key, required this.dayIndex});
  final int dayIndex;

  AzimuthChartData generateLists({
    required List<OrbitAndSolarValues> allValues,
  }) {
    final int startingMasterIndex = 96 * dayIndex;
    final List<OrbitAndSolarValues> osSingleDay = allValues
        .sublist(startingMasterIndex, startingMasterIndex + 96);
        
    final Iterable<({OrbitAndSolarValues osValue, double elapsedHour})> osValuesSingleDayWithHElapsed = osSingleDay.mapIndexed((index, element) => (osValue: element, elapsedHour: index / 4)).toList();
    final Iterable<({OrbitAndSolarValues osValue, double elapsedHour})> visibleSunOnlyData =
        osValuesSingleDayWithHElapsed.where(
          (element) => element.osValue.solarElevationAngle > 0.0001,
        );
    final Iterable<Offset> solarDataOffsets = visibleSunOnlyData
        .map(
          (e) => Offset(
            sin(e.osValue.solarAzimuthAngle) * cos(e.osValue.solarElevationAngle),

            -cos(e.osValue.solarAzimuthAngle) * cos(e.osValue.solarElevationAngle),
          ),
        );
    final Iterable<double> solarDataStrengths = visibleSunOnlyData
        .map((e) => e.osValue.solarStrengthsLocalRelativeToGlobalMax);
        
    final Iterable<double> solarDataHElpased = visibleSunOnlyData
        .map((e) => e.elapsedHour);
        
    return (
      solarDataOffsets: solarDataOffsets,
      solarDataStrengths: solarDataStrengths,
      elapsedHours: solarDataHElpased,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrbitAndSolarValuesListNotifier, KNotifier>(
      builder: (context, orbitAndSolarValuesListNotifier, kNotifier, child) {
        final AzimuthChartData azimuthChartData = generateLists(
          allValues: orbitAndSolarValuesListNotifier.value,
        );

        return Selector<SavedSettingsNotifier, MyColorScheme?>(
          selector: (_, savedAppSettingsNotifier) =>
              savedAppSettingsNotifier.value?.colorScheme,
          shouldRebuild: (previous, next) => previous?.$1 != next?.$1,
          builder: (context, myColorScheme, child) => Padding(
            padding: const EdgeInsets.all(40.0),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: CustomPaint(
                painter: CustomPathRibbonPainter(
                  azimuthChartData: azimuthChartData,
                  colorScheme: myColorScheme ?? constMyColorScheme,
                  appBackgroundColor: Theme.of(context).colorScheme.surface,
                  k: kNotifier.value,
                  h: context.read<CurrentLocationNotifier>().value?.h ?? 0,
                  // We can safely use context.read here because the only time h will change is if the location changes, and that will automatically rebuild the entire thing.
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class CustomPathRibbonPainter extends CustomPainter {
  final Iterable<Offset> points;
  final Iterable<double> positiveStrengths;
  final Iterable<double> elapsedHours;
  final MyColorScheme colorScheme;
  final double strokeWidth;
  final Color appBackgroundColor;
  final double k;
  final double h;

  CustomPathRibbonPainter({
    required AzimuthChartData azimuthChartData,
    required this.colorScheme,
    required this.appBackgroundColor,
    this.strokeWidth = 4.0, required this.k, required this.h,
  }) : points = azimuthChartData.solarDataOffsets,
  positiveStrengths = azimuthChartData.solarDataStrengths,
  elapsedHours = azimuthChartData.elapsedHours;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final double boundingCircleRadius = min(size.width, size.height) / 2;
    final Offset centerOffset = Offset(size.width / 2, size.height / 2);

    /// Ratio of tip radius for cardinal points to circle
    final double a1 = 1.1;

    /// Ratio that compares the width of cardinal points (indirectly) to circle
    final double a2 = 0.25;

    /// Ratio that compares the width of non-cardinal points (indirectly) to circle
    final double a3 = 0.15;

    /// Scaling ratio to make cardinal points "stroke" background image larger than the facets
    final double a4 = 1.1;

    /// Scaling ratio to make non-cardinal points "stroke" background image larger than the facets
    final double a5 = 1.07;
    final double sqrt2 = sqrt(2);

    final nonCardingalPaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.3)!
      ..style = PaintingStyle.fill;
    final cardinalBackPaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.3)!
      ..style = PaintingStyle.fill;
    final cardinalForePaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.5)!
      ..style = PaintingStyle.fill;

    final Paint circlePaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.5)!
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(centerOffset, boundingCircleRadius, circlePaint);

    // Black non-cardinal points
    final nonCardinalPath = Path()
      ..moveTo(
        centerOffset.dx + a5 * boundingCircleRadius / sqrt2,
        centerOffset.dy - a5 * boundingCircleRadius / sqrt2,
      )
      ..lineTo(
        centerOffset.dx + a5 * a3 * boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx + a5 * boundingCircleRadius / sqrt2,
        centerOffset.dy + a5 * boundingCircleRadius / sqrt2,
      )
      ..lineTo(
        centerOffset.dx,
        centerOffset.dy + a5 * a3 * boundingCircleRadius,
      )
      ..lineTo(
        centerOffset.dx - a5 * boundingCircleRadius / sqrt2,
        centerOffset.dy + a5 * boundingCircleRadius / sqrt2,
      )
      ..lineTo(
        centerOffset.dx - a5 * a3 * boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx - a5 * boundingCircleRadius / sqrt2,
        centerOffset.dy - a5 * boundingCircleRadius / sqrt2,
      )
      ..lineTo(
        centerOffset.dx,
        centerOffset.dy - a5 * a3 * boundingCircleRadius,
      )
      ..close();

    canvas.drawPath(nonCardinalPath, nonCardingalPaint);

    // Black cardinal background
    final cardinalPath = Path()
      ..moveTo(
        centerOffset.dx,
        centerOffset.dy - a4 * a1 * boundingCircleRadius,
      )
      ..lineTo(
        centerOffset.dx + a4 * a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy - a4 * a2 * boundingCircleRadius / sqrt2,
      )
      ..lineTo(
        centerOffset.dx + a4 * a1 * boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx + a4 * a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy + a4 * a2 * boundingCircleRadius / sqrt2,
      )
      ..lineTo(centerOffset.dx, centerOffset.dy + a1 * boundingCircleRadius)
      ..lineTo(
        centerOffset.dx - a4 * a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy + a4 * a2 * boundingCircleRadius / sqrt2,
      )
      ..lineTo(
        centerOffset.dx - a4 * a1 * boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx - a4 * a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy - a4 * a2 * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(cardinalPath, cardinalBackPaint);

    // White Facets

    final northWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(centerOffset.dx, centerOffset.dy - a1 * boundingCircleRadius)
      ..lineTo(
        centerOffset.dx - a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy - a2 * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(northWhite, cardinalForePaint);

    final eastWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(centerOffset.dx + a1 * boundingCircleRadius, centerOffset.dy)
      ..lineTo(
        centerOffset.dx + a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy - a2 * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(eastWhite, cardinalForePaint);

    final southWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(centerOffset.dx, centerOffset.dy + a1 * boundingCircleRadius)
      ..lineTo(
        centerOffset.dx + a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy + a2 * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(southWhite, cardinalForePaint);

    final westWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(centerOffset.dx - a1 * boundingCircleRadius, centerOffset.dy)
      ..lineTo(
        centerOffset.dx - a2 * boundingCircleRadius / sqrt2,
        centerOffset.dy + a2 * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(westWhite, cardinalForePaint);

    final List<Offset> correctedPoints = points
        .map((e) => (e) * boundingCircleRadius + centerOffset)
        .toList();

    final Path ribbonPath = Path();

    ribbonPath.moveTo(correctedPoints[0].dx, correctedPoints[0].dy);

    if (correctedPoints.length == 2) {
      ribbonPath.lineTo(correctedPoints[1].dx, correctedPoints[1].dy);
    } else {
      // Tension factor (0.0 = sharp linear, 0.5 = natural Catmull-Rom curve)
      const double tension = 0.5;

      for (int i = 0; i < correctedPoints.length - 1; i++) {
        final Offset p0 = i > 0 ? correctedPoints[i - 1] : correctedPoints[i];
        final Offset p1 = correctedPoints[i];
        final Offset p2 = correctedPoints[i + 1];
        final Offset p3 = i < correctedPoints.length - 2
            ? correctedPoints[i + 2]
            : p2;

        // Calculate control points based on surrounding vectors
        final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
        final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

        ribbonPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
    }

    final int colorSchemeIndex = colorSchemes.indexWhere(
      (element) => element.$1 == colorScheme.$1,
    );

    final List<(List<double>, List<Color>)> myColorSchemesDiscreteSpecific = myColorSchemesDiscrete(k: k, h: h);

    final RadialGradient solarGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.5, // Relative to the Rect provided in createShader
      colors: myColorSchemesDiscreteSpecific[colorSchemeIndex].$2,
      stops: myColorSchemesDiscreteSpecific[colorSchemeIndex].$1,
    );

    // 4. Set up the Paint object
    final Paint ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = solarGradient.createShader(
        Rect.fromCircle(center: centerOffset, radius: boundingCircleRadius),
      );

    // 5. Draw it
    canvas.drawPath(ribbonPath, ribbonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPathRibbonPainter oldDelegate) => true;
}