import 'dart:core';
import 'dart:math';
// import 'dart:collection';
import 'dart:ui' as ui show Gradient;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  // double nextX = 0;
  // double nextAngle = 0; // 1. Store the cumulative rotation of your 3D world
  static final v.Quaternion rotY = v.Quaternion.axisAngle(
    v.Vector3(0, 1, 0),
    pi / 6,
  );
  static final v.Quaternion rotX = v.Quaternion.axisAngle(
    v.Vector3(1, 0, 0),
    pi / 6,
  );
  // v.Quaternion _canvasOrientation = v.Quaternion.identity();
  v.Quaternion _canvasOrientation = ((rotX * rotY) * rotY).normalized();
  late v.Quaternion _startOrientation;
  v.Vector3? vecStart;
  int rotationIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, 800);
        print('_canvasSize: $_canvasSize');
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // onTap: rotateThroughRotations,
          onTap: () => print('triggered onTap'),
          onPanStart: (details) {
            print('running onPanStart');
            _dragStartPoint = details.localPosition;
            _startOrientation = __canvasOrientation.clone();
          },
          onPanUpdate: (details) {
            print('running onPanUpdate');
            if (_dragStartPoint == null || vecStart == null) return;

            final Offset currentPoint = details.localPosition;
            final v.Vector3 vecCurrent = _projectToSphere(
              currentPoint,
              _canvasSize!,
            );

            // Calculate rotation directly from the start point to the current point
            final v.Quaternion deltaRotation = v.Quaternion.fromTwoVectors(
              vecStart!,
              vecCurrent,
            );

            print(
              'inside onPanUpdate.  About to set a new value for __canvasOrientation.  Current value: $__canvasOrientation',
            );
            // Pre-multiply to rotate relative to the camera/screen space
            __canvasOrientation = (deltaRotation * _startOrientation)
                .normalized();
            // __canvasOrientation = (_startOrientation * deltaRotation)
            // .normalized();

            print('inside onPanUpdate.  New value: $__canvasOrientation');
          },
          onPanEnd: (_) {
            _dragStartPoint = null;
          },
          onPanCancel: () {
            _dragStartPoint = null;
          },
          child: GlobeWidget(canvasOrientation: __canvasOrientation),
        );
      },
    );
  }
}

class GlobeWidget extends StatelessWidget {
  const GlobeWidget({super.key, required this.canvasOrientation});
  final v.Quaternion canvasOrientation;

  @override
  Widget build(BuildContext context) {
    return Selector<SavedSettingsNot, MyColorScheme?>(
      selector: (_, savedAppSettingsNotifier) =>
          savedAppSettingsNotifier.value?.colorScheme,
      shouldRebuild: (previous, next) => previous?.$1 != next?.$1,
      builder: (context, colorScheme, child) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: Consumer<DayDataNot>(
            builder: (context, dayDataNotifier, _) {
              final int finalIndex = dayDataNotifier.value.length - 1;
              final int firstDaylightIndex = dayDataNotifier.value.indexWhere(
                (element) => element.solarElevationAngle > 0.0001,
              );
              final int lastDaylightIndex = dayDataNotifier.value
                  .lastIndexWhere(
                    (element) => element.solarElevationAngle > 0.0001,
                  );
              final List<OrbSolValues> visibleSunOnlyData = dayDataNotifier
                  .value
                  .sublist(
                    max(firstDaylightIndex - 1, 0),
                    min(lastDaylightIndex + 1, finalIndex),
                  );
              final List<GlobeInputData> angleMaps = visibleSunOnlyData
                  .map(
                    (e) => (
                      angleMaps: CelestialCoordinates(
                        alpha: e.solarElevationAngle,
                        theta: e.solarAzimuthAngle,
                      ),
                      solarStrengths: e.solarStrengthsLocalRelativeToGlobalMax,
                    ),
                  )
                  .toList();
              return CustomPaint(
                size: Size.infinite,
                painter: GlobePainter(
                  inputData: angleMaps,
                  colormap: colorScheme?.$2,
                  canvasRot: canvasOrientation,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

typedef GlobeInputData = ({
  CelestialCoordinates angleMaps,
  double solarStrengths,
});
typedef GlobeIntermediateData = ({
  Offset coordinates,
  GlobeInputData globeInputData,
});

extension EqualityTest on List<GlobeInputData> {
  bool customEquals(List<GlobeInputData> other) =>
      equals(other, EqualityBy((p0) => p0.angleMaps));
}

final _angleMapsEquality = ListEquality<GlobeInputData>(
  EqualityBy<GlobeInputData, CelestialCoordinates>((p0) => p0.angleMaps),
);

class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.inputData,
    this.colormap,
    required this.canvasRot,
  }) : grassNormalTransformed = canvasRot.conjugated().rotate(
         v.Vector3(0, -1, 0),
       );

  final List<GlobeInputData> inputData;
  final Colormap? colormap;
  final v.Quaternion canvasRot;
  final v.Vector3 grassNormalTransformed;

  static TextPainter textPainterCompassPoint(String text, Color color) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

  static const double textWidthScale = 0.7;
  static const double textBufferCoefficientNS = 0.1;

  static final grassPaintFill = Paint()
    ..color = Colors.green
    ..style = PaintingStyle.fill;

  static final grassPaintLine = Paint.from(grassPaintFill)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;

  static final dirtPaint = Paint()
    ..color = Color.fromARGB(255, 113, 76, 50)
    ..style = PaintingStyle.fill;

  static final skyPaint = Paint()
    ..color = Colors.blue.shade300
    ..style = PaintingStyle.fill;

  static final skyCirclePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static v.Vector3 convertCelestialCoordinatesToXYZ(
    CelestialCoordinates angleMap,
  ) {
    final double xIntermediate =
        cos(angleMap.alpha) * cos((angleMap.theta) - pi);
    final double yIntermediate = sin(angleMap.alpha);
    final double zIntermediate =
        cos(angleMap.alpha) * sin((angleMap.theta) - pi);
    return v.Vector3(xIntermediate, yIntermediate, zIntermediate);
  }

  static v.Vector2 convertXYZIntermediateToXY(v.Vector3 v3, double xRotAngle) {
    final double x = v3.x;
    final double y = v3.z * sin(xRotAngle) - v3.y * cos(xRotAngle);
    return v.Vector2(x, y);
  }

  static const double xRotAngle = pi / 12;

  GreatCircleData projectGreatCircle(v.Vector3 unrotatedNormal, double radius) {
    final v.Vector3 n = canvasRot.conjugated().rotate(
      unrotatedNormal.normalized(),
    );
    final double tiltAngle = atan2(n.y, n.x) + pi / 2;

    return GreatCircleData(
      minorRadius: n.z.abs() * radius,
      tiltAngle: tiltAngle,
      frontFacing: n.z < 0,
      normalVectorTransformed: n,
    );
  }

  void paintSkyGreatCircleThenRestore(
    v.Vector3 unrotatedNormal,
    double majorRadius,
    Canvas canvas,
    Offset centerOffset,
  ) {
    final GreatCircleData greatCircleData = projectGreatCircle(unrotatedNormal, majorRadius);

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

  List<(Path path, Paint paint)> solarPaths(double scaleValue) {
    // For now, use the daylight only points.  Later, go back and make it start one earlier and end one later.
    final List<(Path path, Paint paint)> output = <(Path path, Paint paint)>[];

    final List<GlobeIntermediateData> globeIntermediateDataList = inputData.map(
      (inputDataElement) {
        final v.Vector3 intermediateXYZ = convertCelestialCoordinatesToXYZ(
          inputDataElement.angleMaps,
        );
        final v.Vector2 vectorOutput =
            convertXYZIntermediateToXY(intermediateXYZ, xRotAngle) +
            v.Vector2(1.0, 1.0);

        return (
          coordinates: vectorOutput.toOffset,
          globeInputData: inputDataElement,
        );
      },
    ).toList();

    Paint basePaintWithoutShader = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 / scaleValue
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Tension factor (0.0 = sharp linear, 0.5 = natural Catmull-Rom curve)
    const double tension = 0.5;

    for (int i = 1; i < globeIntermediateDataList.length - 2; i++) {
      final Path thisPath = Path();
      final Offset p0 = globeIntermediateDataList[i - 1].coordinates;
      final Offset p1 = globeIntermediateDataList[i].coordinates;
      final Offset p2 = globeIntermediateDataList[i + 1].coordinates;
      final Offset p3 = globeIntermediateDataList[i + 2].coordinates;

      // Calculate control points based on surrounding vectors
      final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
      final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

      thisPath.moveTo(p1.dx, p1.dy);
      thisPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final v.Vector4 firstColorVector = colorValuesFromMap(
        globeIntermediateDataList[i].globeInputData.solarStrengths,
        false,
        colormap,
      );
      final v.Vector4 secondColorVector = colorValuesFromMap(
        globeIntermediateDataList[i + 1].globeInputData.solarStrengths,
        false,
        colormap,
      );
      final Paint thisPaint = Paint.from(basePaintWithoutShader)
        ..shader = ui.Gradient.linear(p1, p2, [
          firstColorVector.toColor,
          secondColorVector.toColor,
        ]);

      output.add((thisPath, thisPaint));
    }
    return output;
  }

  void drawGroundLabelThenRestore(
    Canvas canvas,
    String text,
    v.Vector3 unrotatedPos, // e.g., v.Vector3(-globeR0 * 0.85, 0, 0) for North
    Offset centerOffset,
    Color color,
  ) {
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

    final TextPainter tp = textPainterCompassPoint(text, color)..layout();

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

  // static void drawTransformedText(
  //   TextPainter textPainter,
  //   Canvas canvas,
  //   Offset position,
  // ) {
  //   canvas.save();
  //   canvas.translate(position.dx, position.dy);
  //   final transform = Matrix4.rotationZ(-pi / 2)
  //     ..scaleByVector3(v.Vector3(textWidthScale, 1.0, 1.0));
  //   canvas.transform(transform.storage);
  //   textPainter.paint(canvas, Offset.zero);
  //   canvas.restore();
  // }

  @override
  bool shouldRepaint(covariant GlobePainter oldDelegate) =>
      !_angleMapsEquality.equals(oldDelegate.inputData, inputData) ||
      colormap != oldDelegate.colormap ||
      oldDelegate.canvasRot != canvasRot;

  @override
  void paint(Canvas canvas, Size size) {
    final double globeD0 = size.height;
    final double globeR0 = globeD0 / 2;
    final Offset centerOffset = Offset(globeD0 / 2, globeD0 / 2);
    final Rect fullRect = Rect.fromLTWH(-globeR0, -globeR0, globeD0, globeD0);

    // Note on drawArc.sweepAngle:  The angle used here is NOT the geometric angle from th +X
    // axis to the last point of the curve (i.e., the true anomaly).  It is instead the angle
    // of a radial line on a true circle that would pass through the final point (i.e.,
    // eccentric anomaly).

    final GreatCircleData grass = projectGreatCircle(
      v.Vector3(0, -1, 0),
      globeR0,
    );

    v.Vector3 xEnd = canvasRot.conjugated().rotate(v.Vector3(globeR0, 0, 0));
    v.Vector3 yEnd = canvasRot.conjugated().rotate(v.Vector3(0, globeR0, 0));
    v.Vector3 zEnd = canvasRot.conjugated().rotate(v.Vector3(0, 0, globeR0));
    Paint axisPaint(Color strokeColor) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = strokeColor;

    final bool skySweepAnglePositive =
        -grassNormalTransformed.x * sin(grass.tiltAngle) +
            grassNormalTransformed.y * cos(grass.tiltAngle) >=
        0;

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
      } else {
        canvas.drawLine(
          Offset(-globeR0, 0),
          Offset(globeR0, 0),
          grassPaintLine,
        );
      }
      canvas.restore();
      drawGroundLabelThenRestore(
        canvas,
        'N',
        v.Vector3(-0.85 * globeR0, 0, 0),
        centerOffset,
        Colors.white,
      );
      drawGroundLabelThenRestore(
        canvas,
        'S',
        v.Vector3(0.85 * globeR0, 0, 0),
        centerOffset,
        Colors.white,
      );
      drawGroundLabelThenRestore(
        canvas,
        'E',
        v.Vector3(0, 0, 0.85 * globeR0),
        centerOffset,
        Colors.white,
      );
      drawGroundLabelThenRestore(
        canvas,
        'W',
        v.Vector3(0, 0, -0.85 * globeR0),
        centerOffset,
        Colors.white,
      );

      paintSkyGreatCircleThenRestore(v.Vector3(0, 0, 1), globeR0, canvas, centerOffset);      
      paintSkyGreatCircleThenRestore(v.Vector3(1, 0, 0), globeR0, canvas, centerOffset);
    } else {
      // grass is NOT front facing, so draw noon arc first
      canvas.restore();

      paintSkyGreatCircleThenRestore(v.Vector3(0, 0, 1), globeR0, canvas, centerOffset);
      paintSkyGreatCircleThenRestore(v.Vector3(1, 0, 0), globeR0, canvas, centerOffset);
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
      final Color darkBrown = Color.fromARGB(
        255,
        113,
        76,
        50,
      ).desaturated(0.5).darkened(0.5);
      drawGroundLabelThenRestore(
        canvas,
        'N',
        v.Vector3(-0.85 * globeR0, 0, 0),
        centerOffset,
        darkBrown,
      );
      drawGroundLabelThenRestore(
        canvas,
        'S',
        v.Vector3(0.85 * globeR0, 0, 0),
        centerOffset,
        darkBrown,
      );
      drawGroundLabelThenRestore(
        canvas,
        'E',
        v.Vector3(0, 0, 0.85 * globeR0),
        centerOffset,
        darkBrown,
      );
      drawGroundLabelThenRestore(
        canvas,
        'W',
        v.Vector3(0, 0, -0.85 * globeR0),
        centerOffset,
        darkBrown,
      );
    }

    // canvas.drawLine(
    //   centerOffset,
    //   centerOffset + xEnd.toOffset,
    //   axisPaint(
    //     xEnd.z <= 0 ? Colors.red : Color.lerp(Colors.red, Colors.black, 0.5)!,
    //   ),
    // );
    // canvas.drawLine(
    //   centerOffset,
    //   centerOffset + yEnd.toOffset,
    //   axisPaint(
    //     yEnd.z <= 0
    //         ? Colors.yellow
    //         : Color.lerp(Colors.yellow, Colors.black, 0.5)!,
    //   ),
    // );
    // canvas.drawLine(
    //   centerOffset,
    //   centerOffset + zEnd.toOffset,
    //   axisPaint(
    //     zEnd.z <= 0 ? Colors.cyan : Color.lerp(Colors.cyan, Colors.black, 0.5)!,
    //   ),
    // );

    print('xEnd: $xEnd, red');
    print('yEnd: $yEnd, yellow');
    print('zEnd: $zEnd, cyan');
    print('canvasRot: $canvasRot');

    // return;
    // final TextPainter textPainterN = textPainterCompassPoint('N');
    // final TextPainter textPainterS = textPainterCompassPoint('S');
    // final TextPainter textPainterE = textPainterCompassPoint('E');
    // final TextPainter textPainterW = textPainterCompassPoint('W');
    // textPainterN.layout();
    // textPainterS.layout();
    // textPainterE.layout();
    // textPainterW.layout();
    // final double minorToMajorRatio = groundRect.height / groundRect.width;
    // drawTransformedText(
    //   textPainterN,
    //   canvas,
    //   Offset(
    //     horDiam / 2 * textBufferCoefficientNS,
    //     diameter / 2 + (textPainterN.width * textWidthScale) / 2,
    //   ),
    // );
    // drawTransformedText(
    //   textPainterS,
    //   canvas,

    //   Offset(
    //     horDiam - horDiam / 2 * textBufferCoefficientNS - textPainterS.height,
    //     diameter / 2 + (textPainterS.width * textWidthScale) / 2,
    //   ),
    // );
    // drawTransformedText(
    //   textPainterE,
    //   canvas,

    //   Offset(
    //     horDiam / 2 - textPainterE.height / 2,
    //     centerOffset.dy +
    //         textWidthScale * textPainterE.width -
    //         groundRect.height / 2 +
    //         minorToMajorRatio * textBufferCoefficientNS * (diameter / 2),
    //   ),
    // );

    // drawTransformedText(
    //   textPainterW,
    //   canvas,

    //   Offset(
    //     horDiam / 2 - textPainterE.height / 2,
    //     centerOffset.dy +
    //         groundRect.height / 2 -
    //         minorToMajorRatio * textBufferCoefficientNS * (diameter / 2),
    //   ),
    // );
    // canvas.save();
    // canvas.translate(0, 0);
    // // It is probably not right to use both the horDiam and the diameter.  Check this out later.
    // canvas.scale(horDiam / 2, diameter / 2);
    // // canvas.drawPath(solarTrail, pathPaint(horDiam / 2));
    // for (final (Path path, Paint paint) in solarPaths(horDiam / 2)) {
    //   canvas.drawPath(path, paint);
    // }
    // canvas.restore();
  }
}
