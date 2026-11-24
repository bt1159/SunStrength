// Fix: ADD LABELS FOR EACH HOUR.
// FIX: the solar path is still backward
// FIX: the solar path touches horizon at sunset but not at sunrise

import 'dart:core';
import 'dart:math';
// import 'dart:collection';
import 'dart:ui' as ui show Gradient, TextDirection;

import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
// import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:color_map/color_map.dart';
import 'package:sun_strength_app/models/main_notifiers.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/chart_notifiers.dart';

class GlobeVizHolder extends StatefulWidget {
  const GlobeVizHolder({super.key});

  @override
  State<GlobeVizHolder> createState() => _GlobeVizHolderState();
}

class _GlobeVizHolderState extends State<GlobeVizHolder> {
  static final v.Quaternion rotY = v.Quaternion.axisAngle(
    v.Vector3(0, 1, 0),
    pi / 6,
  );
  static final v.Quaternion rotX = v.Quaternion.axisAngle(
    v.Vector3(1, 0, 0),
    pi / 6,
  );
  // v.Quaternion _canvasOrientation = v.Quaternion.identity();
  late final ValueNotifier<TooltipInfo?> _tooltipNotifier;
  v.Quaternion _canvasOrientation = ((rotX * rotY) * rotY).normalized();
  late v.Quaternion _startOrientation;
  v.Vector3? vecStart;
  int rotationIndex = 0;
  Offset? _lastCursorPos;

  v.Quaternion get __canvasOrientation => _canvasOrientation;

  set __canvasOrientation(v.Quaternion input) {
    if (input == __canvasOrientation) {
      print('in __canvasOrientation setter, input is the same');
      return;
    }
    final v.Quaternion clone = __canvasOrientation.clone();
    setState(() {
      _canvasOrientation = input;
    });
    print(
      'finished __canvasOrientation setter with a new value.  was: $clone, now $_canvasOrientation',
    );
  }

  // These state variables store information about the current drag event.
  // Every time a new drag starts, these are overwritten.
  Offset? _dragStartPointHidden;
  Offset? get _dragStartPoint => _dragStartPointHidden;
  set _dragStartPoint(Offset? input) {
    if (input == _dragStartPoint) return;
    _dragStartPointHidden = input;
    if (_canvasSize != null && _dragStartPointHidden != null) {
      vecStart = _projectToSphere(input!, _canvasSize!);
    }
  }

  Size? _canvasSizeHidden;
  Size? get _canvasSize => _canvasSizeHidden;
  set _canvasSize(Size? input) {
    if (input == _canvasSize || input == null) return;
    _canvasSizeHidden = input;
    if (_canvasSizeHidden != null && _dragStartPoint != null) {
      vecStart = _projectToSphere(_dragStartPoint!, input);
    }
  }

  // Helper inside LayoutBuilder (or taking globeR0, centerOffset, visibleSunOnlyData)
  void _evaluateHoverAt(
    Offset localPos,
    List<OrbSolValues> visibleSunOnlyData,
    double globeR0,
    Offset centerOffset,
  ) {
    _lastCursorPos = localPos;
    final v.Vector3 groundNormal = __canvasOrientation.conjugated().rotate(
      v.Vector3(0, -1, 0),
    );
    if (groundNormal.z > 0) {
      final double tilt = atan2(groundNormal.y, groundNormal.x) + pi / 2;
      final double minorR = groundNormal.z.abs() * globeR0;
      final Offset rel = localPos - centerOffset;
      final double lx = rel.dx * cos(tilt) + rel.dy * sin(tilt);
      final double ly = -rel.dx * sin(tilt) + rel.dy * cos(tilt);

      if (minorR > 0 &&
          (lx * lx) / (globeR0 * globeR0) + (ly * ly) / (minorR * minorR) <=
              1.0) {
        _hideTooltip();
        return; // Cursor is over the brown ground underside
      }
    }
    final List<SolarXFormedPosAndData> points =
        GlobePainter.solarXFormedPosGenerator(
          inputData: visibleSunOnlyData,
          globeRadius: globeR0,
          centerOffset: centerOffset,
          canvasRot: __canvasOrientation,
        );

    final List<tz.TZDateTime> pointDateTimes = points
        .map((e) => e.data.tzDateTime)
        .toList();
    print('in _evaluateHoverAt, pointDateTimes: $pointDateTimes');
    print(
      'in _evaluateHoverAt, pointDateTimes.length: ${pointDateTimes.length}',
    );

    final ({OrbSolValues data, Offset anchorPos, double t})? hit =
        hitTestSolarPath(cursor: localPos, points: points);
    sendHitToToolTipInfo(hit);
  }

  ({OrbSolValues data, Offset anchorPos, double t})? hitTestSolarPath({
    required Offset cursor,
    required List<SolarXFormedPosAndData> points,
    double maxDistancePx = 14.0,
  }) {
    if (points.length < 2) return null;

    double bestDist = maxDistancePx;
    ({OrbSolValues data, Offset anchorPos, double t})? bestHit;

    // Match the exact segment range drawn by solarPaths()
    for (int i = 0; i < points.length - 1; i++) {
      final Offset a = points[i].screenPos;
      final Offset b = points[i + 1].screenPos;

      final Offset ab = b - a;
      final Offset ap = cursor - a;
      final double abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;

      // Normalized position along segment AB, clamped to the endpoints
      final double t = abLenSq > 0.0
          ? ((ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq).clamp(0.0, 1.0)
          : 0.0;

      final Offset closestPoint = a + ab * t;
      final double dist = (cursor - closestPoint).distance;

      if (dist <= bestDist) {
        bestDist = dist;
        bestHit = (
          // Snap to nearest 15-min sample (or use `t` to interpolate)
          data: t < 0.5 ? points[i].data : points[i + 1].data,
          anchorPos: closestPoint,
          t: t,
        );
      }
    }
    print(
      'bestHit found, anchorPos: ${bestHit?.anchorPos}, incoming cursor: $cursor',
    );
    return bestHit;
  }

  void sendHitToToolTipInfo(
    ({OrbSolValues data, Offset anchorPos, double t})? hit,
  ) {
    if (hit == null) {
      _tooltipNotifier.value = null;
    } else {
      // Currently, the tooltip will appear at the closest data point because anchorPos is used.  This could be ignored to instead use event.localPosition.
      _tooltipNotifier.value = (
        hoverBoxPosition:
            hit.anchorPos +
            MouseFollowingTooltipDelegate.toolTipFormattingOffset,
        tooltipText12:
            '${DateFormat('d MMM yyyy h:mm a').format(hit.data.tzDateTime)} ${hit.data.tzDateTime.timeZoneName}\n'
            'Strength: ${(hit.data.solarStrengthsLocalRelativeToGlobalMax * 100).toStringAsFixed(0)}%\n'
            'Elevation: ${v.degrees(hit.data.solarElevationAngle).toStringAsFixed(0)}\u00B0\n'
            'Direction: ${v.degrees(hit.data.solarAzimuthAngle).toStringAsFixed(0)}\u00B0',
        tooltipText24:
            '${DateFormat('d MMM yyyy HH:mm').format(hit.data.tzDateTime)} ${hit.data.tzDateTime.timeZoneName}\n'
            'Strength: ${(hit.data.solarStrengthsLocalRelativeToGlobalMax * 100).toStringAsFixed(0)}%\n'
            'Elevation: ${v.degrees(hit.data.solarElevationAngle).toStringAsFixed(0)}\u00B0\n'
            'Direction: ${v.degrees(hit.data.solarAzimuthAngle).toStringAsFixed(0)}\u00B0',
      );
    }
  }

  /// Helper: Map 2D screen coordinate to 3D unit vector on your virtual sphere
  v.Vector3 _projectToSphere(Offset localPosition, Size canvasSize) {
    // Standardize coordinates so center of canvas is (0,0) and radius is 1.0
    final double x =
        (2.0 * localPosition.dx - canvasSize.width) / canvasSize.width;
    final double y =
        (2.0 * localPosition.dy - canvasSize.height) /
        canvasSize.height; // Invert Y

    final double lengthSquared = x * x + y * y;

    if (lengthSquared <= 1.0) {
      // Point is inside the sphere
      return v.Vector3(x, y, -sqrt(1.0 - lengthSquared));
    } else {
      // Point is outside the sphere, project to closest edge
      final double length = sqrt(lengthSquared);
      return v.Vector3(x / length, y / length, 0.0);
    }
  }

  void _hideTooltip() {
    if (_tooltipNotifier.value != null) _tooltipNotifier.value = null;
  }

  @override
  void initState() {
    super.initState();
    _tooltipNotifier = ValueNotifier<TooltipInfo?>(null);
  }

  @override
  void dispose() {
    _tooltipNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SavedSettingsNot, MyColorScheme?>(
      selector: (_, savedAppSettingsNotifier) =>
          savedAppSettingsNotifier.value?.colorScheme,
      shouldRebuild: (previous, next) => previous?.$1 != next?.$1,
      builder: (context, colorScheme, child) {
        return Consumer<DayDataNot>(
          builder: (context, dayDataNotifier, _) {
            final List<double> strengths = dayDataNotifier.value
                .map((e) => e.solarStrengthsLocalRelativeToGlobalMax)
                .toList();
            final List<tz.TZDateTime> datetimes = dayDataNotifier.value
                .map((e) => e.tzDateTime)
                .toList();
            final List<double> elevations = dayDataNotifier.value
                .map((e) => e.solarElevationAngle)
                .toList();
            final List<double> azimuths = dayDataNotifier.value
                .map((e) => e.solarAzimuthAngle)
                .toList();
            print('inside _GlobalVizHolderState');
            print('number of points: ${dayDataNotifier.value.length}');
            print('strengths: $strengths');
            print('datetimes: $datetimes');
            print('elevations: $elevations');
            print('azimuths: $azimuths');
            final int firstDaylightIndex = dayDataNotifier.value.indexWhere(
              (element) => element.solarElevationAngle > 0.0001,
            );
            final int lastDaylightIndex = dayDataNotifier.value.lastIndexWhere(
              (element) => element.solarElevationAngle > 0.0001,
            );
            final List<OrbSolValues> visibleSunOnlyData = dayDataNotifier.value
                .sublist(
                  max(firstDaylightIndex - 1, 0),
                  min(lastDaylightIndex + 2, dayDataNotifier.value.length),
                );
            print(
              'visibleSunOnlyData uses firstDaylightIndex - 1: ${firstDaylightIndex - 1} and lastDaylightIndex + 1: ${lastDaylightIndex + 1}',
            );
            print('visibleSunOnlyData.length: ${visibleSunOnlyData.length}');
            return Consumer<AzChartSizeNotifier>(
              builder: (context, azChartSizeNotifier, _) {
                print(
                  'running builder under C<AzChartSizeNotifier>, value: ${azChartSizeNotifier.value.name}',
                );
                return LayoutBuilder(
                  builder: (context, constraints) {
                    print(
                      'running LayoutBuilder in _GlobeVizHolderState that should change the size of the widget',
                    );
                    final double targetWidth;
                    switch (azChartSizeNotifier.value) {
                      case AzChartSize.small:
                        targetWidth = max(200.0, constraints.maxWidth / 4);
                        break;
                      case AzChartSize.medium:
                        targetWidth =
                            (max(200.0, constraints.maxWidth / 4) +
                                constraints.maxWidth) /
                            2;
                        break;
                      case AzChartSize.large:
                        targetWidth = constraints.maxWidth;
                        break;
                    }
                    final double side = targetWidth.clamp(
                      0.0,
                      min(constraints.maxWidth, constraints.maxHeight),
                    );
                    final Size squareSize = constraints.constrain(
                      Size(side, side),
                    );
                    final double globeR0 = squareSize.width / 2;
                    final Offset centerOffset = Offset(globeR0, globeR0);
                    _canvasSize = squareSize;

                    print(
                      'running builder under C<AzChartSizeNotifier>, targetWidth: $targetWidth',
                    );
                    return MouseRegion(
                      onHover: (event) => _evaluateHoverAt(
                        event.localPosition,
                        visibleSunOnlyData,
                        globeR0,
                        centerOffset,
                      ),
                      onExit: (_) => _hideTooltip(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => print('triggered onTap'),
                        onPanStart: (details) {
                          print('running onPanStart');
                          _hideTooltip();
                          _dragStartPoint = details.localPosition;
                          _startOrientation = __canvasOrientation.clone();
                        },
                        onPanUpdate: (details) {
                          print('running onPanUpdate');
                          if (_dragStartPoint == null || vecStart == null) {
                            return;
                          }

                          final Offset currentPoint = details.localPosition;
                          final v.Vector3 vecCurrent = _projectToSphere(
                            currentPoint,
                            _canvasSize!,
                          );

                          // Calculate rotation directly from the start point to the current point
                          final v.Quaternion deltaRotation = v
                              .Quaternion.fromTwoVectors(vecStart!, vecCurrent);

                          print(
                            'inside onPanUpdate.  About to set a new value for __canvasOrientation.  Current value: $__canvasOrientation',
                          );
                          // Pre-multiply to rotate relative to the camera/screen space
                          __canvasOrientation =
                              (deltaRotation * _startOrientation).normalized();
                          // __canvasOrientation = (_startOrientation * deltaRotation)
                          // .normalized();

                          print(
                            'inside onPanUpdate.  New value: $__canvasOrientation',
                          );
                        },
                        onPanEnd: (_) {
                          _dragStartPoint = null;
                          if (_lastCursorPos != null) {
                            _evaluateHoverAt(
                              _lastCursorPos!,
                              visibleSunOnlyData,
                              globeR0,
                              centerOffset,
                            );
                          }
                        },
                        onPanCancel: () {
                          _dragStartPoint = null;
                        },
                        child: SizedBox(
                          width: targetWidth,
                          height: targetWidth,
                          child: Builder(
                            builder: (context) {
                              print(
                                'running builderXYZ wand targetWidth: $targetWidth',
                              );
                              return RepaintBoundary(
                                child: Builder(
                                  builder: (context) {
                                    print(
                                      'running builderABC wand targetWidth: $targetWidth',
                                    );
                                    return Stack(
                                      clipBehavior: Clip.hardEdge,
                                      children: [
                                        CustomPaint(
                                          size: Size.infinite,
                                          painter: GlobePainter(
                                            inputData: visibleSunOnlyData,
                                            colormap: colorScheme?.$2,
                                            canvasRot: __canvasOrientation,
                                            appBackgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                          ),
                                        ),
                                        ValueListenableBuilder<TooltipInfo?>(
                                          valueListenable: _tooltipNotifier,
                                          builder: (context, tooltipInfo, child) {
                                            if (tooltipInfo != null) {
                                              return CustomSingleChildLayout(
                                                delegate:
                                                    MouseFollowingTooltipDelegate(
                                                      hoverBoxPosition:
                                                          tooltipInfo
                                                              .hoverBoxPosition,
                                                    ),
                                                child: IgnorePointer(
                                                  // Prevents the tooltip box from stealing mouse focus
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    // padding: const EdgeInsets.all(0),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.65,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Selector<SavedSettingsNot, bool>(
                                                      selector:
                                                          (
                                                            _,
                                                            savedSettingsNotifier,
                                                          ) =>
                                                              savedSettingsNotifier
                                                                  .value
                                                                  ?.twelveHour ??
                                                              true,
                                                      builder: (_, twelveHour, _) => Stack(
                                                        alignment:
                                                            Alignment.topRight,
                                                        children: [
                                                          // The point of this first Text widget is to have a widget the max size of
                                                          // the actual Text widget.  This forces the parent to always be this max
                                                          // size.  That way, when the input text changes and the width of the lower
                                                          // Text changes, the black box doesn't change.  This is most important since
                                                          // the width determines the position when the cursor gets close to the ends.
                                                          // Without this, when in a certain place, the user could see the tooltip
                                                          // jump side to side repeatedly with small mouse movements.
                                                          Text(
                                                            twelveHour
                                                                ? '88 888 8888 88:88 88 XXX\nStrength: 100%'
                                                                : '88 888 8888 88:88 XXX\nStrength: 100%',
                                                            style: const TextStyle(
                                                              color: Colors
                                                                  .transparent,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            twelveHour
                                                                ? tooltipInfo
                                                                      .tooltipText12
                                                                : tooltipInfo
                                                                      .tooltipText24,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.inputData,
    this.colormap,
    required this.canvasRot,
    required this.appBackgroundColor,
  }) : grassNormalTransformed = canvasRot.conjugated().rotate(
         v.Vector3(0, -1, 0),
       ) {
    print('constructing GlobePainter, inputData.length: ${inputData.length}');
  }

  final List<OrbSolValues> inputData;
  final Colormap? colormap;
  final v.Quaternion canvasRot;
  final v.Vector3 grassNormalTransformed;
  final Color appBackgroundColor;

  static final double solarPathWidth = 4.0;
  static final Color compassPointTextColor = Colors.white;
  static const double textWidthScale = 0.7;
  static const double textBufferCoefficientNS = 0.1;
  static const Color grassColor = Colors.green;
  static final Paint grassPaintFill = Paint()
    ..color = grassColor
    ..style = PaintingStyle.fill;

  static final Paint grassPaintLine = Paint.from(grassPaintFill)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;
  static final Color dirtColor = Color.fromARGB(255, 113, 76, 50);
  static final Paint dirtPaint = Paint()
    ..color = dirtColor
    ..style = PaintingStyle.fill;
  static final Color darkBrown = dirtColor.desaturated(0.5).darkened(0.5);
  static final Paint skyPaint = Paint()
    ..color = Colors.blue.shade300
    ..style = PaintingStyle.fill;

  static final Paint skyCirclePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final double ratioCardinalTipRadius = 0.9;
  static final double ratioCardinalWidth = 0.25;
  static final double ratioIntercardinalWidth = 0.15;
  static final double ratioCardinalApparentStrokeWidth = 1.1;
  static final double ratioIntercardinalApparentStrokeWidth = 0.9;
  static final Paint solarHourlyPointPaint = Paint()
    ..color = Colors.white.withAlpha(127)
    ..strokeWidth = 0.0
    ..style = PaintingStyle.fill;
  static final (String, CoordinateAxis) northAxis = ('N', CoordinateAxis.negX);
  static final (String, CoordinateAxis) southAxis = ('S', CoordinateAxis.posX);
  static final (String, CoordinateAxis) eastAxis = ('E', CoordinateAxis.posZ);
  static final (String, CoordinateAxis) westAxis = ('W', CoordinateAxis.negZ);
  static final double compassPointTextPositionRatio = 0.85;  // How far along the globeRadius to located the compass point label

  static v.Vector3 convertCelestialAnglesToVector({
    required double azimuth,
    required double elevation,
  }) {
    final double x = cos(elevation) * cos((azimuth) - pi);
    final double y = -sin(elevation);
    final double z = -cos(elevation) * sin((azimuth) - pi);
    return v.Vector3(x, y, z);
  }

  static List<SolarXFormedPosAndData> solarXFormedPosGenerator({
    required List<OrbSolValues> inputData,
    required v.Quaternion canvasRot,
    required double globeRadius,
    required Offset centerOffset,
  }) {
    return inputData.map((inputDataElement) {
      final v.Vector3 untransformedVector = convertCelestialAnglesToVector(
        elevation: inputDataElement.solarElevationAngle,
        azimuth: inputDataElement.solarAzimuthAngle,
      );
      final v.Vector3 transformedVector = canvasRot
          .conjugated()
          .rotate(untransformedVector)
          .scaled(globeRadius);

      return SolarXFormedPosAndData(
        screenPos: transformedVector.toOffset + centerOffset,
        data: inputDataElement,
      );
    }).toList();
  }

  static GreatCircleXFormedData xFormGreatCircle({
    required v.Quaternion canvasRot,
    required v.Vector3 unrotatedNormal,
    required double radius,
  }) {
    final v.Vector3 n = canvasRot.conjugated().rotate(
      unrotatedNormal.normalized(),
    );
    final double tiltAngle = atan2(n.y, n.x) + pi / 2;

    return GreatCircleXFormedData(
      minorRadius: n.z.abs() * radius,
      tiltAngle: tiltAngle,
      frontFacing: n.z < 0,
      normalVectorTransformed: n,
    );
  }

  static void paintSkyGreatCircleThenRestore({
    required v.Quaternion canvasRot,
    required v.Vector3 unrotatedNormal,
    required double majorRadius,
    required Canvas canvas,
    required Offset centerOffset,
  }) {
    final GreatCircleXFormedData greatCircleData = xFormGreatCircle(
      canvasRot: canvasRot,
      unrotatedNormal: unrotatedNormal,
      radius: majorRadius,
    );

    final v.Vector3 grassNormalTransformed = canvasRot.conjugated().rotate(
      v.Vector3(0, -1, 0),
    );

    final v.Vector3 grassIntersectionVector = grassNormalTransformed
        .cross(greatCircleData.normalVectorTransformed)
        .normalized();

    final double cosT = cos(greatCircleData.tiltAngle);
    final double sinT = sin(greatCircleData.tiltAngle);

    final double northNoonLocalX =
        grassIntersectionVector.x * cosT + grassIntersectionVector.y * sinT;
    final double northNoonLocalY =
        -grassIntersectionVector.x * sinT + grassIntersectionVector.y * cosT;

    final double grassNormalNoonLocalX =
        grassNormalTransformed.x * cosT + grassNormalTransformed.y * sinT;
    final double grassNormalNoonLocalY =
        -grassNormalTransformed.x * sinT + grassNormalTransformed.y * cosT;

    final double minorRatioNoon = greatCircleData.minorRadius / majorRadius;
    final double startEccentricAnomalyNoon = minorRatioNoon > 1e-6
        ? atan2(northNoonLocalY / minorRatioNoon, northNoonLocalX)
        : (northNoonLocalX >= 0 ? 0.0 : pi);

    final double crossNoon =
        northNoonLocalX * grassNormalNoonLocalY -
        northNoonLocalY * grassNormalNoonLocalX;
    final double sweepAngleNoon = crossNoon >= 0 ? pi : -pi;

    canvas.save();
    canvas.translate(centerOffset.dx, centerOffset.dy);
    canvas.rotate(greatCircleData.tiltAngle);
    if (greatCircleData.minorRadius > 1e-3) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset.zero,
          width: majorRadius * 2,
          height: greatCircleData.minorRadius * 2,
        ),
        startEccentricAnomalyNoon,
        sweepAngleNoon,
        false,
        skyCirclePaint,
      );
    } else {
      // Edge-on fallback: line from North to South through Zenith
      canvas.drawLine(
        Offset(northNoonLocalX * majorRadius, 0),
        Offset(-northNoonLocalX * majorRadius, 0),
        skyCirclePaint,
      );
    }
    canvas.restore();
  }

  static (List<SolarPathAndPaint>, List<Offset>) solarPathsGenerator({
    required double globeRadius,
    required centerOffset,
    required List<OrbSolValues> inputData,
    required v.Quaternion canvasRot,
    required Colormap? colormap,
  }) {
    final List<SolarPathAndPaint> output1 = <SolarPathAndPaint>[];
    final List<Offset> output2 = <Offset>[];
    
    // If not enough points in inputData, return empty lists
    if (inputData.length < 3) {
      return (output1, output2);
    }

    final List<SolarXFormedPosAndData> solarPoints = solarXFormedPosGenerator(
      centerOffset: centerOffset,
      canvasRot: canvasRot,
      globeRadius: globeRadius,
      inputData: inputData,
    );
    // final List<tz.TZDateTime> pointDateTimes = solarPoints
    //     .map((e) => e.data.tzDateTime)
    //     .toList();
    // print('in GlobePainter.paint, pointDateTimes: $pointDateTimes');
    // print(
    //   'in GlobePainter.paint, pointDateTimes.length: ${pointDateTimes.length}',
    // );

    Paint basePaintWithoutGradient = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Tension factor (0.0 = sharp linear, 0.5 = natural Catmull-Rom curve)
    const double tension = 0.5;

    final int lastIndexOverall = solarPoints.length - 1;
    final int indexFirstLight;
    final int indexLastLight;
    if (solarPoints.first.data.solarElevationAngle >= 0.0001) {
      indexFirstLight = 0;
    } else {
      indexFirstLight = 1;
    }
    if (solarPoints.last.data.solarElevationAngle >= 0.0001) {
      indexLastLight = lastIndexOverall;
    } else {
      indexLastLight = lastIndexOverall - 1;
    }
    if (indexFirstLight == 0) {
      // p1 is first point
      // create p0 by extrapolation

      // 24 hour daylight
      final int minute = solarPoints[0].data.tzDateTime.minute;
      if (minute == 0) {
        output2.add(solarPoints[0].screenPos);
      }
      final Path thisPath = Path();
      final Offset p1 = solarPoints[0].screenPos;
      final Offset p2 = solarPoints[1].screenPos;
      final Offset p3 = solarPoints[2].screenPos;
      final Offset p0 = Offset(2 * p1.dx - p2.dx, 2 * p1.dy - p2.dy);

      // Calculate control points based on surrounding vectors
      final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
      final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

      thisPath.moveTo(p1.dx, p1.dy);
      thisPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final v.Vector4 firstColorVector = colorValuesFromMap(
        solarPoints[0].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final v.Vector4 secondColorVector = colorValuesFromMap(
        solarPoints[1].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final Paint thisPaint = Paint.from(basePaintWithoutGradient)
        ..shader = ui.Gradient.linear(p1, p2, [
          firstColorVector.toColor,
          secondColorVector.toColor,
        ]);

      output1.add(SolarPathAndPaint(path: thisPath, paint: thisPaint));
    } else {
      // p0 is the first point
      // create p1 by interpolating between first two points
      // normal sunrise between p0 and p1
      final double p1Elevation = 0;
      final double elFractionPastP0 =
          ((p1Elevation - solarPoints[0].data.solarElevationAngle) /
                  (solarPoints[1].data.solarElevationAngle -
                      solarPoints[0].data.solarElevationAngle))
              .clamp(0, 1);
      
      double deltaAz = solarPoints[1].data.solarAzimuthAngle - solarPoints[0].data.solarAzimuthAngle;
      if (deltaAz > pi) deltaAz -= 2 * pi;
      if (deltaAz < -pi) deltaAz += 2 * pi;
      final double p1Azimuth = solarPoints[0].data.solarAzimuthAngle + deltaAz * elFractionPastP0;


      final v.Vector3 untransformedP1 = convertCelestialAnglesToVector(
        elevation: p1Elevation,
        azimuth: p1Azimuth,
      );
      final v.Vector3 transformedP1 = canvasRot
          .conjugated()
          .rotate(untransformedP1)
          .scaled(globeRadius);

      
      
      final Path thisPath = Path();
      final Offset p0 = solarPoints[0].screenPos;
      final Offset p2 = solarPoints[1].screenPos;
      final Offset p3 = solarPoints[2].screenPos;
      final Offset p1 = transformedP1.toOffset + centerOffset;

      // Calculate control points based on surrounding vectors
      final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
      final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

      thisPath.moveTo(p1.dx, p1.dy);
      thisPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final v.Vector4 firstColorVector = colorValuesFromMap(
        solarPoints[0].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final v.Vector4 secondColorVector = colorValuesFromMap(
        solarPoints[1].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final Paint thisPaint = Paint.from(basePaintWithoutGradient)
        ..shader = ui.Gradient.linear(p1, p2, [
          firstColorVector.toColor,
          secondColorVector.toColor,
        ]);

      output1.add(SolarPathAndPaint(path: thisPath, paint: thisPaint));
    }
    // After this, no matter the situation, we are ready to create the path from i = 1 to i = 2;

    for (int i = 1; i < lastIndexOverall - 1; i++) {
      final int minute = solarPoints[i].data.tzDateTime.minute;
      if (minute == 0) {
        output2.add(solarPoints[i].screenPos);
      }
      final Path thisPath = Path();
      final Offset p0 = solarPoints[i - 1].screenPos;
      final Offset p1 = solarPoints[i].screenPos;
      final Offset p2 = solarPoints[i + 1].screenPos;
      final Offset p3 = solarPoints[i + 2].screenPos;

      // Calculate control points based on surrounding vectors
      final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
      final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

      thisPath.moveTo(p1.dx, p1.dy);
      thisPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final v.Vector4 firstColorVector = colorValuesFromMap(
        solarPoints[i].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final v.Vector4 secondColorVector = colorValuesFromMap(
        solarPoints[i + 1].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final Paint thisPaint = Paint.from(basePaintWithoutGradient)
        ..shader = ui.Gradient.linear(p1, p2, [
          firstColorVector.toColor,
          secondColorVector.toColor,
        ]);

      output1.add(SolarPathAndPaint(path: thisPath, paint: thisPaint));
    }

    if (indexLastLight == lastIndexOverall) {
      // p2 is last point
      // create p3 by extrapolation
      // 24 hour daylight
      final int minute = solarPoints[lastIndexOverall].data.tzDateTime.minute;
      if (minute == 0) {
        output2.add(solarPoints[lastIndexOverall].screenPos);
      }
      final Path thisPath = Path();
      final Offset p0 = solarPoints[lastIndexOverall - 2].screenPos;
      final Offset p1 = solarPoints[lastIndexOverall - 1].screenPos;
      final Offset p2 = solarPoints[lastIndexOverall].screenPos;
      final Offset p3 = Offset(2 * p2.dx - p1.dx, 2 * p2.dy - p1.dy);

      // Calculate control points based on surrounding vectors
      final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
      final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

      thisPath.moveTo(p1.dx, p1.dy);
      thisPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final v.Vector4 firstColorVector = colorValuesFromMap(
        solarPoints[0].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final v.Vector4 secondColorVector = colorValuesFromMap(
        solarPoints[1].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final Paint thisPaint = Paint.from(basePaintWithoutGradient)
        ..shader = ui.Gradient.linear(p1, p2, [
          firstColorVector.toColor,
          secondColorVector.toColor,
        ]);

      output1.add(SolarPathAndPaint(path: thisPath, paint: thisPaint));
    } else {
      // p2 is the last point
      // create p3 by interpolating between last two points
      // normal sunsetfinal double p1Elevation = 0;
      final double p2Elevation = 0;
      final double elFractionBeforeP3 =
          ((0 - solarPoints[lastIndexOverall].data.solarElevationAngle) /
                  (solarPoints[lastIndexOverall - 1].data.solarElevationAngle -
                      solarPoints[lastIndexOverall].data.solarElevationAngle))
              .clamp(0, 1);

      
      double deltaAz = solarPoints[lastIndexOverall - 1].data.solarAzimuthAngle - solarPoints[lastIndexOverall].data.solarAzimuthAngle;
      if (deltaAz > pi) deltaAz -= 2 * pi;
      if (deltaAz < -pi) deltaAz += 2 * pi;
      final double p2Azimuth = solarPoints[lastIndexOverall].data.solarAzimuthAngle + deltaAz * elFractionBeforeP3;


      final v.Vector3 untransformedP2 = convertCelestialAnglesToVector(
        elevation: p2Elevation,
        azimuth: p2Azimuth,
      );
      final v.Vector3 transformedP2 = canvasRot
          .conjugated()
          .rotate(untransformedP2)
          .scaled(globeRadius);


      
      final Path thisPath = Path();
      final Offset p0 = solarPoints[lastIndexOverall - 2].screenPos;
      final Offset p1 = solarPoints[lastIndexOverall - 1].screenPos;
      final Offset p3 = solarPoints[lastIndexOverall].screenPos;
      final Offset p2 = transformedP2.toOffset + centerOffset;

      // Calculate control points based on surrounding vectors
      final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
      final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

      thisPath.moveTo(p1.dx, p1.dy);
      thisPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final v.Vector4 firstColorVector = colorValuesFromMap(
        solarPoints[0].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final v.Vector4 secondColorVector = colorValuesFromMap(
        solarPoints[1].data.solarStrengthsLocalRelativeToGlobalMax,
        false,
        colormap,
      );
      final Paint thisPaint = Paint.from(basePaintWithoutGradient)
        ..shader = ui.Gradient.linear(p1, p2, [
          firstColorVector.toColor,
          secondColorVector.toColor,
        ]);

      output1.add(SolarPathAndPaint(path: thisPath, paint: thisPaint));
    }

    return (output1, output2);
  }

  static void drawGenericGroundLabelThenRestore({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required String text,
    required v.Vector3
    unrotatedPos, // e.g., v.Vector3(-globeR0 * 0.85, 0, 0) for North
    required Offset centerOffset,
    Color? color,
  }) {
    final v.Quaternion q = canvasRot.conjugated();

    // Rotate anchor position and the two local text axes into screen space
    final v.Vector3 pos = q.rotate(unrotatedPos);
    final v.Vector3 dU = q.rotate(
      v.Vector3(0, 0, 1),
    ); // Local +X (across glyph)
    final v.Vector3 dV = q.rotate(v.Vector3(1, 0, 0)); // Local +Y (down glyph)

    // Guard against a singular (zero-area) matrix when the ground is nearly edge-on
    final double det2D = dU.x * dV.y - dU.y * dV.x;
    if (det2D.abs() < 1e-3) return;

    // final TextPainter tp = textPainterCompassPoint(text, color)..layout();

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? compassPointTextColor,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    // Column-major Matrix4 mapping (u, v) -> pos + u * dU + v * dV
    final Matrix4 transform = Matrix4(
      dU.x,
      dU.y,
      0,
      0,
      dV.x,
      dV.y,
      0,
      0,
      0,
      0,
      1,
      0,
      centerOffset.dx + pos.x,
      centerOffset.dy + pos.y,
      0,
      1,
    );

    canvas.save();
    canvas.transform(transform.storage);
    // Painting at (-width/2, -height/2) centers the glyph directly on unrotatedPos
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  static void drawNorthGroundLabelThenRestore({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required Offset centerOffset,
    required double globeRadius,
    Color? color,
  }) => drawGenericGroundLabelThenRestore(
    canvas: canvas,
    canvasRot: canvasRot,
    centerOffset: centerOffset,
    color: color,
    text: northAxis.$1,
    unrotatedPos: northAxis.$2.normalVector * globeRadius * compassPointTextPositionRatio,
  );
  static void drawSouthGroundLabelThenRestore({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required Offset centerOffset,
    required double globeRadius,
    Color? color,
  }) => drawGenericGroundLabelThenRestore(
    canvas: canvas,
    canvasRot: canvasRot,
    centerOffset: centerOffset,
    color: color,
    text: southAxis.$1,
    unrotatedPos: southAxis.$2.normalVector * globeRadius * compassPointTextPositionRatio,
  );
  static void drawEastGroundLabelThenRestore({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required Offset centerOffset,
    required double globeRadius,
    Color? color,
  }) => drawGenericGroundLabelThenRestore(
    canvas: canvas,
    canvasRot: canvasRot,
    centerOffset: centerOffset,
    color: color,
    text: eastAxis.$1,
    unrotatedPos: eastAxis.$2.normalVector * globeRadius * compassPointTextPositionRatio,
  );
  static void drawWestGroundLabelThenRestore({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required Offset centerOffset,
    required double globeRadius,
    Color? color,
  }) => drawGenericGroundLabelThenRestore(
    canvas: canvas,
    canvasRot: canvasRot,
    centerOffset: centerOffset,
    color: color,
    text: westAxis.$1,
    unrotatedPos: westAxis.$2.normalVector * globeRadius * compassPointTextPositionRatio,
  );

  static Path pathFromVectorList(
    Iterable<v.Vector3> vectorList,
    Offset centerOffset, [
    bool closed = true,
  ]) {
    final Path output = Path();
    for (final (int index, v.Vector3 vector) in vectorList.indexed) {
      if (index == 0) {
        output.moveTo(vector.x + centerOffset.dx, vector.y + centerOffset.dy);
      } else {
        output.lineTo(vector.x + centerOffset.dx, vector.y + centerOffset.dy);
      }
    }
    if (closed) {
      output.close();
    }
    return output;
  }

  static void paintNonCadinalPoints({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required double globeRadius,
    required Offset centerOffset,
    required Paint paint,
  }) {
    // Black non-cardinal points
    final List<v.Vector3> untransformedVectors = [
      v.Vector3(
        -ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
        0,
        ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
      ),
      v.Vector3(
        0,
        0,
        ratioIntercardinalApparentStrokeWidth *
            ratioIntercardinalWidth *
            globeRadius,
      ),
      v.Vector3(
        ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
        0,
        ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
      ),
      v.Vector3(
        ratioIntercardinalApparentStrokeWidth *
            ratioIntercardinalWidth *
            globeRadius,
        0,

        0,
      ),
      v.Vector3(
        ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
        0,
        -ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
      ),
      v.Vector3(
        0,
        0,
        -ratioIntercardinalApparentStrokeWidth *
            ratioIntercardinalWidth *
            globeRadius,
      ),
      v.Vector3(
        -ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
        0,
        -ratioIntercardinalApparentStrokeWidth * globeRadius / sqrt2,
      ),
      v.Vector3(
        -ratioIntercardinalApparentStrokeWidth *
            ratioIntercardinalWidth *
            globeRadius,
        0,
        0,
      ),
    ];
    final Iterable<v.Vector3> transformedVectors = untransformedVectors.map(
      (e) => canvasRot.conjugated().rotate(e),
    );
    final Path path = pathFromVectorList(transformedVectors, centerOffset);
    canvas.drawPath(path, paint);
  }

  static void paintCardinalBackground({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required double globeRadius,
    required Offset centerOffset,
    required Paint paint,
  }) {
    final List<v.Vector3> untransformedVectors = [
      v.Vector3(
        ratioCardinalApparentStrokeWidth * ratioCardinalTipRadius * globeRadius,
        0,
        0,
      ),
      v.Vector3(
        ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
        0,
        ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
      ),
      v.Vector3(
        0,
        0,
        ratioCardinalApparentStrokeWidth * ratioCardinalTipRadius * globeRadius,
      ),
      v.Vector3(
        -ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
        0,
        ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
      ),
      v.Vector3(
        -ratioCardinalApparentStrokeWidth *
            ratioCardinalTipRadius *
            globeRadius,
        0,
        0,
      ),
      v.Vector3(
        -ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
        0,
        -ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
      ),
      v.Vector3(
        0,
        0,
        -ratioCardinalApparentStrokeWidth *
            ratioCardinalTipRadius *
            globeRadius,
      ),
      v.Vector3(
        ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
        0,
        -ratioCardinalApparentStrokeWidth *
            ratioCardinalWidth *
            globeRadius /
            sqrt2,
      ),
    ];
    final Iterable<v.Vector3> transformedVectors = untransformedVectors.map(
      (e) => canvasRot.conjugated().rotate(e),
    );
    final Path path = pathFromVectorList(transformedVectors, centerOffset);
    canvas.drawPath(path, paint);
  }

  static void paintCardinalForeground({
    required Canvas canvas,
    required v.Quaternion canvasRot,
    required double globeRadius,
    required Offset centerOffset,
    required Paint paint,
  }) {
    final List<v.Vector3> untransformedVectorsNorth = [
      v.Vector3(0, 0, 0),
      v.Vector3(-ratioCardinalTipRadius * globeRadius, 0, 0),
      v.Vector3(
        -ratioCardinalWidth * globeRadius / sqrt2,
        0,
        -ratioCardinalWidth * globeRadius / sqrt2,
      ),
    ];

    final List<v.Vector3> untransformedVectorsSouth = [
      v.Vector3(0, 0, 0),
      v.Vector3(0, 0, ratioCardinalTipRadius * globeRadius),
      v.Vector3(
        -ratioCardinalWidth * globeRadius / sqrt2,
        0,
        ratioCardinalWidth * globeRadius / sqrt2,
      ),
    ];

    final List<v.Vector3> untransformedVectorsEast = [
      v.Vector3(0, 0, 0),
      v.Vector3(ratioCardinalTipRadius * globeRadius, 0, 0),
      v.Vector3(
        ratioCardinalWidth * globeRadius / sqrt2,
        0,
        ratioCardinalWidth * globeRadius / sqrt2,
      ),
    ];

    final List<v.Vector3> untransformedVectorsWest = [
      v.Vector3(0, 0, 0),
      v.Vector3(0, 0, -ratioCardinalTipRadius * globeRadius),
      v.Vector3(
        ratioCardinalWidth * globeRadius / sqrt2,
        0,
        -ratioCardinalWidth * globeRadius / sqrt2,
      ),
    ];
    final Iterable<v.Vector3> transformedVectorsNorth =
        untransformedVectorsNorth.map((e) => canvasRot.conjugated().rotate(e));
    final Iterable<v.Vector3> transformedVectorsSouth =
        untransformedVectorsSouth.map((e) => canvasRot.conjugated().rotate(e));
    final Iterable<v.Vector3> transformedVectorsEast = untransformedVectorsEast
        .map((e) => canvasRot.conjugated().rotate(e));
    final Iterable<v.Vector3> transformedVectorsWest = untransformedVectorsWest
        .map((e) => canvasRot.conjugated().rotate(e));
    final Path pathNorth = pathFromVectorList(
      transformedVectorsNorth,
      centerOffset,
    );
    final Path pathSouth = pathFromVectorList(
      transformedVectorsSouth,
      centerOffset,
    );
    final Path pathEast = pathFromVectorList(
      transformedVectorsEast,
      centerOffset,
    );
    final Path pathWest = pathFromVectorList(
      transformedVectorsWest,
      centerOffset,
    );
    canvas.drawPath(pathNorth, paint);
    canvas.drawPath(pathSouth, paint);
    canvas.drawPath(pathEast, paint);
    canvas.drawPath(pathWest, paint);
  }

  @override
  bool shouldRepaint(covariant GlobePainter oldDelegate) =>
      !oldDelegate.inputData.equals(inputData) ||
      colormap != oldDelegate.colormap ||
      oldDelegate.canvasRot != canvasRot;

  @override
  void paint(Canvas canvas, Size size) {
    print('Just started GlobePainter, paint() with size: $size');
    final double globeR0 = size.height / 2;
    final Offset centerOffset = Offset(globeR0, globeR0);
    final Rect fullRect = Rect.fromLTWH(
      -globeR0,
      -globeR0,
      2 * globeR0,
      2 * globeR0,
    );
    final Paint nonCardingalPaint = Paint()
      ..color = grassColor.darkened(0.25)
      ..style = PaintingStyle.fill;
    final Paint cardinalBackPaint = Paint()
      ..color = grassColor.darkened(0.25)
      ..style = PaintingStyle.fill;
    final Paint cardinalForePaint = Paint()
      ..color = grassColor.darkened(0.1)
      ..style = PaintingStyle.fill;

    // Note on drawArc.sweepAngle:  The angle used here is NOT the geometric angle from th +X
    // axis to the last point of the curve (i.e., the true anomaly).  It is instead the angle
    // of a radial line on a true circle that would pass through the final point (i.e.,
    // eccentric anomaly).

    final GreatCircleXFormedData grass = xFormGreatCircle(
      canvasRot: canvasRot,
      unrotatedNormal: v.Vector3(0, -1, 0),
      radius: globeR0,
    );

    final bool skySweepAnglePositive =
        -grassNormalTransformed.x * sin(grass.tiltAngle) +
            grassNormalTransformed.y * cos(grass.tiltAngle) >=
        0;

    final List<SolarPathAndPaint> solarPaths;
    final List<Offset> solarHourlyPoints;
    if (inputData.length < 3) {
      solarPaths = <SolarPathAndPaint>[];
      solarHourlyPoints = <Offset>[];
    } else {
      (solarPaths, solarHourlyPoints) = solarPathsGenerator(
        globeRadius: globeR0,
        centerOffset: centerOffset,
        canvasRot: canvasRot,
        colormap: colormap,
        inputData: inputData,
      );
    }

    // Start Painting!!!  Beware of order!!
    canvas.save();
    canvas.translate(centerOffset.dx, centerOffset.dy);
    canvas.rotate(grass.tiltAngle);
    canvas.drawArc(
      fullRect,
      0,
      skySweepAnglePositive ? pi : -pi,
      true,
      skyPaint,
    );
    canvas.drawArc(
      fullRect,
      0,
      skySweepAnglePositive ? -pi : pi,
      true,
      dirtPaint,
    );
    if (grass.frontFacing) {
      if (grass.minorRadius > 1e-3) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: globeR0 * 2,
            height: grass.minorRadius * 2,
          ),
          grassPaintFill,
        );
        canvas.restore();

        paintNonCadinalPoints(
          canvas: canvas,
          canvasRot: canvasRot,
          globeRadius: globeR0,
          centerOffset: centerOffset,
          paint: nonCardingalPaint,
        );

        paintCardinalBackground(
          canvas: canvas,
          canvasRot: canvasRot,
          globeRadius: globeR0,
          centerOffset: centerOffset,
          paint: cardinalBackPaint,
        );

        paintCardinalForeground(
          canvas: canvas,
          canvasRot: canvasRot,
          globeRadius: globeR0,
          centerOffset: centerOffset,
          paint: cardinalForePaint,
        );
      } else {
        canvas.drawLine(
          Offset(-globeR0, 0),
          Offset(globeR0, 0),
          grassPaintLine,
        );
        canvas.restore();
      }
      drawNorthGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
      );
      drawSouthGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
      );
      drawEastGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
      );
      drawWestGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
      );

      // Paint the Celestrial Meridian
      paintSkyGreatCircleThenRestore(
        canvasRot: canvasRot,
        unrotatedNormal: v.Vector3(0, 0, 1),
        majorRadius: globeR0,
        canvas: canvas,
        centerOffset: centerOffset,
      );

      // Paint the Prime Vertical
      paintSkyGreatCircleThenRestore(
        canvasRot: canvasRot,
        unrotatedNormal: v.Vector3(1, 0, 0),
        majorRadius: globeR0,
        canvas: canvas,
        centerOffset: centerOffset,
      );

      solarPaths.forEach(canvas.drawPathFromRecord);
      for (final Offset centerPoint in solarHourlyPoints) {
        canvas.drawCircle(
          centerPoint,
          solarPathWidth / 2,
          solarHourlyPointPaint,
        );
      }
    } else {
      // grass is NOT front facing, so draw noon arc first
      canvas.restore();

      // Paint the Celestrial Meridian
      paintSkyGreatCircleThenRestore(
        canvasRot: canvasRot,
        unrotatedNormal: CoordinateAxis.posZ.normalVector,
        majorRadius: globeR0,
        canvas: canvas,
        centerOffset: centerOffset,
      );

      // Paint the Prime Vertical
      paintSkyGreatCircleThenRestore(
        canvasRot: canvasRot,
        unrotatedNormal: CoordinateAxis.posX.normalVector,
        majorRadius: globeR0,
        canvas: canvas,
        centerOffset: centerOffset,
      );

      solarPaths.forEach(canvas.drawPathFromRecord);
      for (final Offset centerPoint in solarHourlyPoints) {
        canvas.drawCircle(
          centerPoint,
          solarPathWidth / 2,
          solarHourlyPointPaint,
        );
      }

      canvas.save();
      canvas.translate(centerOffset.dx, centerOffset.dy);
      canvas.rotate(grass.tiltAngle);
      if (grass.minorRadius > 1e-3) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: globeR0 * 2,
            height: grass.minorRadius * 2,
          ),
          dirtPaint,
        );
      } else {
        canvas.drawLine(Offset(-globeR0, 0), Offset(globeR0, 0), dirtPaint);
      }
      canvas.restore();

      drawNorthGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
        color: darkBrown,
      );
      drawSouthGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
        color: darkBrown,
      );
      drawEastGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
        color: darkBrown,
      );
      drawWestGroundLabelThenRestore(
        canvas: canvas,
        canvasRot: canvasRot,
        centerOffset: centerOffset,
        globeRadius: globeR0,
        color: darkBrown,
      );
    }
  }
}
