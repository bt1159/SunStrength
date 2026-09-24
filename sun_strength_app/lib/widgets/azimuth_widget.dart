import 'dart:core';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/main_notifiers.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/chart_notifiers.dart';
import 'package:timezone/timezone.dart' as tz;

class AzimuthChart extends StatelessWidget {
  const AzimuthChart({super.key});

  AzimuthChartData generateLists({required List<OrbSolValues> osSingleDay}) {
    final Iterable<OrbSolValues> visibleSunOnlyData = osSingleDay.where(
      (element) => element.solarElevationAngle > 0.0001,
    );
    final Iterable<Offset> solarDataOffsets = visibleSunOnlyData.map(
      (e) => Offset(
        sin(e.solarAzimuthAngle) * cos(e.solarElevationAngle),

        -cos(e.solarAzimuthAngle) * cos(e.solarElevationAngle),
      ),
    );
    final Iterable<double> solarDataStrengths = visibleSunOnlyData.map(
      (e) => e.solarStrengthsLocalRelativeToGlobalMax,
    );

    final Iterable<tz.TZDateTime> tzDateTime = visibleSunOnlyData.map(
      (e) => e.tzDateTime,
    );

    return (
      solarDataOffsets: solarDataOffsets,
      solarDataStrengths: solarDataStrengths,
      tzDateTime: tzDateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        print('inside AzimuthChart.build, constraints: $constraints');
        return Consumer<DayDataNot>(
          builder: (context, dayDataNotifier, child) {
            final AzimuthChartData azimuthChartData = generateLists(
              osSingleDay: dayDataNotifier.value,
            );
            final tz.TZDateTime hoverDateTimeRaw =
                dayDataNotifier.value[12 * 4].tzDateTime;
            return CNP<AzChartSizeNotifier>(
              create: (context) => AzChartSizeNotifier(AzChartSize.large),
              builder: (context, _) {
                return Consumer<AzChartSizeNotifier>(
                  builder: (context, azChartSizeNotifier, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        print(
                          'inside AzimuthChart.build, constraints passed below Consumer<AzChartSizeNotifier>: $constraints',
                        );
                        double maxWidth = constraints.maxWidth;
                        final AzChartSizeComplete large = (
                          width: maxWidth,
                          azChartSize: AzChartSize.large,
                        );
                        final AzChartSizeComplete small = (
                          width: (maxWidth / 4).clamp(200, maxWidth),
                          azChartSize: AzChartSize.small,
                        );
                        final AzChartSizeComplete medium = (
                          width: (small.width + large.width) / 2,
                          azChartSize: AzChartSize.medium,
                        );
                        void onPressedSmall() =>
                            azChartSizeNotifier.value == small.azChartSize ||
                                small.width == large.width
                            ? null
                            : azChartSizeNotifier.value = small.azChartSize;
                        void onPressedMedium() =>
                            azChartSizeNotifier.value == medium.azChartSize ||
                                medium.width == large.width
                            ? null
                            : azChartSizeNotifier.value = medium.azChartSize;
                        void onPressedLarge() =>
                            azChartSizeNotifier.value == large.azChartSize
                            ? null
                            : azChartSizeNotifier.value = large.azChartSize;
    
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                print(
                                  'inside AzimuthChart.build, constraints passed to Columns first child: $constraints',
                                );
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        print(
                                          'inside AzimuthChart.build, constraints passed to first child of Row underColumn: $constraints',
                                        );
                                        return child!;
                                      },
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 4,
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            print(
                                              'inside AzimuthChart.build, constraints passed to first child of Row under Row under Column: $constraints',
                                            );
                                            return ElevatedButton(
                                              onPressed:
                                                  azChartSizeNotifier.value ==
                                                          small.azChartSize ||
                                                      small.width == large.width
                                                  ? null
                                                  : onPressedSmall,
                                              child: Text('S'),
                                            );
                                          },
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              azChartSizeNotifier.value ==
                                                      medium.azChartSize ||
                                                  medium.width == large.width
                                              ? null
                                              : onPressedMedium,
                                          child: Text('M'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              azChartSizeNotifier.value ==
                                                  large.azChartSize
                                              ? null
                                              : onPressedLarge,
                                          child: Text('L'),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            Text(
                              intl.DateFormat(
                                'd MMM yyyy',
                              ).format(hoverDateTimeRaw),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Container(
                              // width: double.infinity,
                              alignment: Alignment.center,
                              child: Selector<SavedSettingsNot, MyColorScheme?>(
                                selector: (_, savedAppSettingsNotifier) =>
                                    savedAppSettingsNotifier.value?.colorScheme,
                                shouldRebuild: (previous, next) =>
                                    previous?.$1 != next?.$1,
                                builder: (context, myColorScheme, _) => Selector<SavedSettingsNot, bool>(
                                  selector: (_, savedAppSettingsNotifier) =>
                                      savedAppSettingsNotifier
                                          .value
                                          ?.twelveHour ??
                                      true,
                                  builder: (context, twelveHour, _) => Selector<ChartSettingsNot, double>(
                                    selector:
                                        (_, currentChartSettingsNotifier) =>
                                            currentChartSettingsNotifier
                                                .value
                                                ?.location
                                                .latLng
                                                .latitude ??
                                            0,
                                    builder: (context, latitude, _) {
                                      return Consumer<KNot>(
                                        builder: (context, kNotifier, _) {
                                          return LayoutBuilder(
                                            builder: (context, constraints) {
                                              print(
                                                'inside AzimuthChart.build, constraints passed to Padding under ConstrainedBox with double infinity width: $constraints',
                                              );
                                              return Padding(
                                                padding: const EdgeInsets.all(
                                                  40.0,
                                                ),
                                                // TODO: Move the AzChartSizeNot or whatever it is closer to this.
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxWidth:
                                                        switch (azChartSizeNotifier
                                                            .value) {
                                                          AzChartSize.large =>
                                                            large.width,
                                                          AzChartSize.medium =>
                                                            medium.width,
                                                          AzChartSize.small =>
                                                            small.width,
                                                        },
                                                  ),
                                                  child: LayoutBuilder(
                                                    builder: (context, constraints) {
                                                      print(
                                                        'inside AzimuthChart.build, constraints passed to AspectRatio: $constraints',
                                                      );
                                                      final double
                                                      reCalcMaxWidth =
                                                          switch (azChartSizeNotifier
                                                              .value) {
                                                            AzChartSize.large =>
                                                              large.width,
                                                            AzChartSize
                                                                .medium =>
                                                              medium.width,
                                                            AzChartSize.small =>
                                                              small.width,
                                                          };
                                                      print(
                                                        'insize AzimuthChart.build, just above AspectRatio, reCalcMaxWidth: $reCalcMaxWidth, azChartSizeNotifier.value: ${azChartSizeNotifier.value}, large.width: ${large.width}, medium.width: ${medium.width}, small.width: ${small.width}, ',
                                                      );
                                                      return AspectRatio(
                                                        aspectRatio: 1.0,
                                                        child: LayoutBuilder(
                                                          builder: (context, constraints) {
                                                            print(
                                                              'inside AzimuthChart.build, constraints passed to CustomPaint: $constraints',
                                                            );
                                                            return CustomPaint(
                                                              painter: CustomPathRibbonPainter(
                                                                twelveHour:
                                                                    twelveHour,
                                                                lat: latitude,
                                                                azimuthChartData:
                                                                    azimuthChartData,
                                                                colorScheme:
                                                                    myColorScheme ??
                                                                    constMyColorScheme,
                                                                appBackgroundColor:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .surface,
                                                                k: kNotifier
                                                                    .value,
                                                                h:
                                                                    context
                                                                        .read<
                                                                          ChartSettingsNot
                                                                        >()
                                                                        .value
                                                                        ?.h ??
                                                                    0,
                                                                // We can safely use context.read here because the only time h will change is if the location changes, and that will automatically rebuild the entire thing.
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
          child: Text(
            'Sun strength and location on a single day',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      },
    );
  }
}

/// This uses h and k in order to get the right colorScheme mapped values.  It then uses that to
/// create the circular gradient.  I could improve this slightly by instead sampling the strengths
/// of the input data vs. their radial distance.  If, for instance, the data has a strength of 0.3,
/// which always ties to the middle color, and has a radial distance 0.1, that is essentially a way
/// of constructing the k/h vs. strength curve without needing to actually know the k and h.
class CustomPathRibbonPainter extends CustomPainter {
  final Iterable<Offset> points;
  final Iterable<double> positiveStrengths;
  final Iterable<tz.TZDateTime> tzDateTime;
  final MyColorScheme colorScheme;
  final Color appBackgroundColor;
  final double k;
  final double h;
  final double lat;
  final bool twelveHour;

  CustomPathRibbonPainter({
    required AzimuthChartData azimuthChartData,
    required this.colorScheme,
    required this.appBackgroundColor,
    required this.k,
    required this.h,
    required this.lat,
    required this.twelveHour,
  }) : points = azimuthChartData.solarDataOffsets,
       positiveStrengths = azimuthChartData.solarDataStrengths,
       tzDateTime = azimuthChartData.tzDateTime;

  void paintBackgroundCircle(
    Canvas canvas,
    double boundingCircleRadius,
    Offset centerOffset,
    Paint circlePaint,
  ) => canvas.drawCircle(centerOffset, boundingCircleRadius, circlePaint);

  void paintNonCadinalPoints(
    Canvas canvas,
    double boundingCircleRadius,
    Offset centerOffset,
    Paint nonCardingalPaint,
    double ratioIntercardinalWidth,
    double ratioIntercardinalApparentStrokeWidth,
  ) {
    // Black non-cardinal points
    final nonCardinalPath = Path()
      ..moveTo(
        centerOffset.dx +
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy -
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..lineTo(
        centerOffset.dx +
            ratioIntercardinalApparentStrokeWidth *
                ratioIntercardinalWidth *
                boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx +
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy +
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..lineTo(
        centerOffset.dx,
        centerOffset.dy +
            ratioIntercardinalApparentStrokeWidth *
                ratioIntercardinalWidth *
                boundingCircleRadius,
      )
      ..lineTo(
        centerOffset.dx -
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy +
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..lineTo(
        centerOffset.dx -
            ratioIntercardinalApparentStrokeWidth *
                ratioIntercardinalWidth *
                boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx -
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy -
            ratioIntercardinalApparentStrokeWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..lineTo(
        centerOffset.dx,
        centerOffset.dy -
            ratioIntercardinalApparentStrokeWidth *
                ratioIntercardinalWidth *
                boundingCircleRadius,
      )
      ..close();

    canvas.drawPath(nonCardinalPath, nonCardingalPaint);
  }

  void paintCardinalBackground(
    Canvas canvas,
    double boundingCircleRadius,
    Offset centerOffset,
    Paint cardinalBackPaint,
    double ratioCardinalTipRadius,
    double ratioCardinalWidth,
    double ratioCardinalApparentStrokeWidth,
  ) {
    // Black cardinal background
    final cardinalPath = Path()
      ..moveTo(
        centerOffset.dx,
        centerOffset.dy -
            ratioCardinalApparentStrokeWidth *
                ratioCardinalTipRadius *
                boundingCircleRadius,
      )
      ..lineTo(
        centerOffset.dx +
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy -
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..lineTo(
        centerOffset.dx +
            ratioCardinalApparentStrokeWidth *
                ratioCardinalTipRadius *
                boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx +
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy +
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..lineTo(
        centerOffset.dx,
        centerOffset.dy + ratioCardinalTipRadius * boundingCircleRadius,
      )
      ..lineTo(
        centerOffset.dx -
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy +
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..lineTo(
        centerOffset.dx -
            ratioCardinalApparentStrokeWidth *
                ratioCardinalTipRadius *
                boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx -
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
        centerOffset.dy -
            ratioCardinalApparentStrokeWidth *
                ratioCardinalWidth *
                boundingCircleRadius /
                sqrt2,
      )
      ..close();

    canvas.drawPath(cardinalPath, cardinalBackPaint);
  }

  void paintCardinalForeground(
    Canvas canvas,
    double boundingCircleRadius,
    Offset centerOffset,
    Paint cardinalForePaint,
    double ratioCardinalTipRadius,
    double ratioCardinalWidth,
  ) {
    final northWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(
        centerOffset.dx,
        centerOffset.dy - ratioCardinalTipRadius * boundingCircleRadius,
      )
      ..lineTo(
        centerOffset.dx - ratioCardinalWidth * boundingCircleRadius / sqrt2,
        centerOffset.dy - ratioCardinalWidth * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(northWhite, cardinalForePaint);

    final eastWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(
        centerOffset.dx + ratioCardinalTipRadius * boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx + ratioCardinalWidth * boundingCircleRadius / sqrt2,
        centerOffset.dy - ratioCardinalWidth * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(eastWhite, cardinalForePaint);

    final southWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(
        centerOffset.dx,
        centerOffset.dy + ratioCardinalTipRadius * boundingCircleRadius,
      )
      ..lineTo(
        centerOffset.dx + ratioCardinalWidth * boundingCircleRadius / sqrt2,
        centerOffset.dy + ratioCardinalWidth * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(southWhite, cardinalForePaint);

    final westWhite = Path()
      ..moveTo(centerOffset.dx, centerOffset.dy)
      ..lineTo(
        centerOffset.dx - ratioCardinalTipRadius * boundingCircleRadius,
        centerOffset.dy,
      )
      ..lineTo(
        centerOffset.dx - ratioCardinalWidth * boundingCircleRadius / sqrt2,
        centerOffset.dy + ratioCardinalWidth * boundingCircleRadius / sqrt2,
      )
      ..close();

    canvas.drawPath(westWhite, cardinalForePaint);
  }

  void paintSolarPathRibbon(
    Canvas canvas,
    double boundingCircleRadius,
    Offset centerOffset,
    Paint ribbonPaint,
    List<Offset> correctedPoints,
  ) {
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

    // 5. Draw it
    canvas.drawPath(ribbonPath, ribbonPaint);
  }

  void paintSolarPathBreaksAndLabels(
    Canvas canvas,
    double strokeWidth,
    double labelPadding,
    Paint labelPaint,
    List<Offset> correctedPoints,
  ) {
    // Filter list of points from ribbon that are on the hour
    final Iterable<(int, tz.TZDateTime)> hourMarkerIndeces = tzDateTime.indexed
        .where((element) => element.$2.isOnTheHour);

    // Use that filtered list to gather all data for those points needed to create ribbon breaks and text labels
    final Iterable<SolarPathHourlyData> hourMarkerCenterPoints =
        hourMarkerIndeces.map(
          (e) => (
            tzDateTime: e.$2,
            centerPoint: correctedPoints.elementAt(e.$1),
            normalVHat: getPerpendicularUnitVector(
              e.$1 < hourMarkerIndeces.length - 1
                  ? correctedPoints.elementAt(e.$1)
                  : correctedPoints.elementAt(e.$1 - 1),
              e.$1 < hourMarkerIndeces.length - 1
                  ? correctedPoints.elementAt(e.$1 + 1)
                  : correctedPoints.elementAt(e.$1),
            ),
          ),
        );

    final List<Rect> labelRects = <Rect>[];

    // Iterate through each "on the hour" point and create ribbon break and text label
    for (final SolarPathHourlyData hourMarkerCenterPoint
        in hourMarkerCenterPoints) {
      // Create end points for break
      final Offset p1 =
          hourMarkerCenterPoint.centerPoint +
          hourMarkerCenterPoint.normalVHat.scale(
            strokeWidth / 2,
            strokeWidth / 2,
          );

      final Offset p2 =
          hourMarkerCenterPoint.centerPoint -
          hourMarkerCenterPoint.normalVHat.scale(
            strokeWidth / 2,
            strokeWidth / 2,
          );
      // Draw ribbon break
      canvas.drawLine(p1, p2, labelPaint);

      // Create label
      final String hourText;

      if (twelveHour) {
        hourText = intl.DateFormat(
          'h:mm a',
        ).format(hourMarkerCenterPoint.tzDateTime);
      } else {
        hourText = intl.DateFormat(
          'HH:mm',
        ).format(hourMarkerCenterPoint.tzDateTime);
      }

      final double latAboveEq = lat >= 0 ? 1 : -1;

      final TextSpan textSpan = TextSpan(
        text: hourText,
        style: TextStyle(color: Colors.white, fontSize: max(strokeWidth, 12)),
      );

      final TextPainter textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final Offset offsetTextCornerToCenter = Offset(
        textPainter.size.width / 2,
        textPainter.size.height / 2,
      );

      // 2D vector from spline point to nearest edge of textPainter
      final Offset offsetCenters = hourMarkerCenterPoint.normalVHat
          .scale(2 * strokeWidth, 2 * strokeWidth)
          .scale(latAboveEq, latAboveEq);

      final double arcTanThetaPositive = (offsetCenters.dx / offsetCenters.dy)
          .abs();

      final Offset offsetTextCenterToTextEdgePositive =
          arcTanThetaPositive <=
              offsetTextCornerToCenter.dx / offsetTextCornerToCenter.dy
          ? Offset(
              offsetTextCornerToCenter.dy * arcTanThetaPositive,
              offsetTextCornerToCenter.dy,
            )
          : Offset(
              offsetTextCornerToCenter.dx,
              offsetTextCornerToCenter.dx / arcTanThetaPositive,
            );

      final Offset offsetTextCenterToTextEdgeSigned = Offset(
        offsetCenters.dx < 0
            ? -offsetTextCenterToTextEdgePositive.dx
            : offsetTextCenterToTextEdgePositive.dx,
        offsetCenters.dy < 0
            ? -offsetTextCenterToTextEdgePositive.dy
            : offsetTextCenterToTextEdgePositive.dy,
      );

      final Offset offsetPointAndTextCorner =
          hourMarkerCenterPoint.centerPoint +
          offsetCenters +
          offsetTextCenterToTextEdgeSigned -
          offsetTextCornerToCenter;

      final Rect rect = offsetPointAndTextCorner & textPainter.size;

      bool overlap = labelRects.any(
        (element) => (element.inflate(labelPadding)).overlaps(rect),
      );

      if (!overlap) {
        textPainter.paint(canvas, offsetPointAndTextCorner);
        labelRects.add(rect);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = (size.width / 50).clamp(8, 40);
    if (points.length < 2) return;

    final double boundingCircleRadius = min(size.width, size.height) / 2;
    final Offset centerOffset = Offset(size.width / 2, size.height / 2);
    final double ratioCardinalTipRadius = 1.1;
    final double ratioCardinalWidth = 0.25;
    final double ratioIntercardinalWidth = 0.15;
    final double ratioCardinalApparentStrokeWidth = 1.1;
    final double ratioIntercardinalApparentStrokeWidth = 1.07;
    final double labelPadding = 10;

    final int colorSchemeIndex = colorSchemes.indexWhere(
      (element) => element.$1 == colorScheme.$1,
    );

    final List<(List<double>, List<Color>)> myColorSchemesDiscreteSpecific =
        myColorSchemesDiscrete(k: k, h: h);

    final RadialGradient solarGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.5, // Relative to the Rect provided in createShader
      colors: myColorSchemesDiscreteSpecific[colorSchemeIndex].$2,
      stops: myColorSchemesDiscreteSpecific[colorSchemeIndex].$1,
    );

    // print(
    //   'calculating solarGradient, colors: ${myColorSchemesDiscreteSpecific[colorSchemeIndex].$2}',
    // );
    // print(
    //   'calculating solarGradient, stops: ${myColorSchemesDiscreteSpecific[colorSchemeIndex].$1}',
    // );

    final List<Offset> correctedPoints = points
        .map((e) => (e) * boundingCircleRadius + centerOffset)
        .toList();

    final Paint nonCardingalPaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.3)!
      ..style = PaintingStyle.fill;
    final Paint cardinalBackPaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.3)!
      ..style = PaintingStyle.fill;
    final Paint cardinalForePaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.5)!
      ..style = PaintingStyle.fill;
    final Paint circlePaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.5)!
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final Paint ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = solarGradient.createShader(
        Rect.fromCircle(center: centerOffset, radius: boundingCircleRadius),
      );
    final Paint labelPaint = Paint()
      ..color = Color.lerp(Colors.black, appBackgroundColor, 0.5)!
      ..strokeWidth = lerpDouble(
        2,
        10,
        ((size.width - 200) / (1000 - 200)).clamp(0, 1),
      )!;

    paintBackgroundCircle(
      canvas,
      boundingCircleRadius,
      centerOffset,
      circlePaint,
    );

    paintNonCadinalPoints(
      canvas,
      boundingCircleRadius,
      centerOffset,
      nonCardingalPaint,
      ratioIntercardinalWidth,
      ratioIntercardinalApparentStrokeWidth,
    );

    paintCardinalBackground(
      canvas,
      boundingCircleRadius,
      centerOffset,
      cardinalBackPaint,
      ratioCardinalTipRadius,
      ratioCardinalWidth,
      ratioCardinalApparentStrokeWidth,
    );

    paintCardinalForeground(
      canvas,
      boundingCircleRadius,
      centerOffset,
      cardinalForePaint,
      ratioCardinalTipRadius,
      ratioCardinalWidth,
    );

    paintSolarPathRibbon(
      canvas,
      boundingCircleRadius,
      centerOffset,
      ribbonPaint,
      correctedPoints,
    );

    paintSolarPathBreaksAndLabels(
      canvas,
      strokeWidth,
      labelPadding,
      labelPaint,
      correctedPoints,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPathRibbonPainter oldDelegate) => true;
}

typedef SolarPathHourlyData = ({
  tz.TZDateTime tzDateTime,
  Offset centerPoint,
  Offset normalVHat,
});

enum AzChartSize { small, medium, large }

class AzChartSizeNotifier extends ValueNotifier<AzChartSize> {
  AzChartSizeNotifier(super.value);
}

typedef AzChartSizeComplete = ({double width, AzChartSize azChartSize});
