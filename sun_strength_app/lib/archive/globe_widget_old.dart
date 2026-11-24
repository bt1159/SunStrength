// import 'dart:core';
// import 'dart:math';
// // import 'dart:collection';
// import 'dart:ui' as ui show Gradient;
// import 'package:collection/collection.dart';
// import 'package:material_ui/material_ui.dart';
// import 'package:provider/provider.dart';
// import 'package:vector_math/vector_math_64.dart' as v;
// import 'package:color_map/color_map.dart';
// import 'package:sun_strength_app/models/main_notifiers.dart';
// import 'package:sun_strength_app/models/helpers.dart';
// import 'package:sun_strength_app/models/chart_notifiers.dart';

// class GlobeWidget extends StatelessWidget {
//   const GlobeWidget({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Selector<SavedSettingsNot, MyColorScheme?>(
//       selector: (_, savedAppSettingsNotifier) =>
//           savedAppSettingsNotifier.value?.colorScheme,
//       shouldRebuild: (previous, next) => previous?.$1 != next?.$1,
//       builder: (context, colorScheme, child) {
//         return Consumer<DayDataNot>(
//           builder: (context, dayDataNotifier, _) {
//             final int finalIndex = dayDataNotifier.value.length - 1;
//             final int firstDaylightIndex = dayDataNotifier.value.indexWhere(
//               (element) => element.solarElevationAngle > 0.0001,
//             );
//             final int lastDaylightIndex = dayDataNotifier.value.lastIndexWhere(
//               (element) => element.solarElevationAngle > 0.0001,
//             );
//             final List<OrbSolValues> visibleSunOnlyData = dayDataNotifier.value
//                 .sublist(
//                   max(firstDaylightIndex - 1, 0),
//                   min(lastDaylightIndex + 1, finalIndex),
//                 );
//             final List<GlobeInputData> angleMaps = visibleSunOnlyData
//                 .map(
//                   (e) => (
//                     angleMaps: CelestialAngles(
//                       elevation: e.solarElevationAngle,
//                       azimuth: e.solarAzimuthAngle,
//                     ),
//                     solarStrengths: e.solarStrengthsLocalRelativeToGlobalMax,
//                   ),
//                 )
//                 .toList();
//             return AspectRatio(
//               aspectRatio: 1.0,
//               child: CustomPaint(
//                 size: Size.infinite,
//                 painter: GlobePainter(
//                   inputData: angleMaps,
//                   colormap: colorScheme?.$2,
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }

// typedef GlobeInputData = ({
//   CelestialAngles angleMaps,
//   double solarStrengths,
// });
// typedef GlobeIntermediateData = ({
//   Offset coordinates,
//   GlobeInputData globeInputData,
// });

// extension EqualityTest on List<GlobeInputData> {
//   bool customEquals(List<GlobeInputData> other) =>
//       equals(other, EqualityBy((p0) => p0.angleMaps));
// }

// final _angleMapsEquality = ListEquality<GlobeInputData>(
//   EqualityBy<GlobeInputData, CelestialAngles>((p0) => p0.angleMaps),
// );

// class GlobePainter extends CustomPainter {
//   const GlobePainter({required this.inputData, this.colormap});

//   final List<GlobeInputData> inputData;
//   final Colormap? colormap;

//   static TextPainter textPainterCompassPoint(String text) => TextPainter(
//     text: TextSpan(
//       text: text,
//       style: TextStyle(
//         color: Colors.white,
//         fontSize: 32,
//         fontWeight: FontWeight.bold,
//       ),
//     ),
//     textDirection: TextDirection.ltr,
//   );

//   static const double textWidthScale = 0.7;
//   static const double textBufferCoefficientNS = 0.1;

//   static v.Vector3 convertCelestialCoordinatesToXYZ(
//     CelestialAngles angleMap,
//   ) {
//     final double xIntermediate =
//         cos(angleMap.elevation) * cos((angleMap.azimuth) - pi);
//     final double yIntermediate = sin(angleMap.elevation);
//     final double zIntermediate =
//         cos(angleMap.elevation) * sin((angleMap.azimuth) - pi);
//     return v.Vector3(xIntermediate, yIntermediate, zIntermediate);
//   }

//   static v.Vector2 convertXYZIntermediateToXY(v.Vector3 v3, double xRotAngle) {
//     final double x = v3.x;
//     final double y = v3.z * sin(xRotAngle) - v3.y * cos(xRotAngle);
//     return v.Vector2(x, y);
//   }

//   static const double xRotAngle = pi / 12;

//   List<(Path path, Paint paint)> solarPaths(double scaleValue) {
//     // For now, use the daylight only points.  Later, go back and make it start one earlier and end one later.
//     final List<(Path path, Paint paint)> output = <(Path path, Paint paint)>[];

//     final List<GlobeIntermediateData> globeIntermediateDataList = inputData.map(
//       (inputDataElement) {
//         final v.Vector3 intermediateXYZ = convertCelestialCoordinatesToXYZ(
//           inputDataElement.angleMaps,
//         );
//         final v.Vector2 vectorOutput =
//             convertXYZIntermediateToXY(intermediateXYZ, xRotAngle) +
//             v.Vector2(1.0, 1.0);

//         return (
//           coordinates: vectorOutput.toOffset,
//           globeInputData: inputDataElement,
//         );
//       },
//     ).toList();

//     Paint basePaintWithoutShader = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4.0 / scaleValue
//       ..strokeCap = StrokeCap.round
//       ..strokeJoin = StrokeJoin.round;

//     // Tension factor (0.0 = sharp linear, 0.5 = natural Catmull-Rom curve)
//     const double tension = 0.5;

//     for (int i = 1; i < globeIntermediateDataList.length - 2; i++) {
//       final Path thisPath = Path();
//       final Offset p0 = globeIntermediateDataList[i - 1].coordinates;
//       final Offset p1 = globeIntermediateDataList[i].coordinates;
//       final Offset p2 = globeIntermediateDataList[i + 1].coordinates;
//       final Offset p3 = globeIntermediateDataList[i + 2].coordinates;

//       // Calculate control points based on surrounding vectors
//       final Offset cp1 = p1 + (p2 - p0) * (tension / 3.0);
//       final Offset cp2 = p2 - (p3 - p1) * (tension / 3.0);

//       thisPath.moveTo(p1.dx, p1.dy);
//       thisPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
//       final v.Vector4 firstColorVector = colorValuesFromMap(
//         globeIntermediateDataList[i].globeInputData.solarStrengths,
//         false,
//         colormap,
//       );
//       print(
//         'solar path coloring, i: $i, first solarStrength: ${globeIntermediateDataList[i].globeInputData.solarStrengths}, firstColorVector: $firstColorVector, first color: ${firstColorVector.toColor}',
//       );
//       final v.Vector4 secondColorVector = colorValuesFromMap(
//         globeIntermediateDataList[i + 1].globeInputData.solarStrengths,
//         false,
//         colormap,
//       );
//       print(
//         'solar path coloring, i + 1: ${i + 1}, second solarStrength: ${globeIntermediateDataList[i + 1].globeInputData.solarStrengths}, secondColorVector: $secondColorVector, second color: ${secondColorVector.toColor}',
//       );
//       final Paint thisPaint = Paint.from(basePaintWithoutShader)      
//         ..shader = ui.Gradient.linear(p1, p2, [
//           firstColorVector.toColor,
//           secondColorVector.toColor,
//         ]);
//         print('thisPaint points: p1: $p1, p2: $p2');
//         print('thisPath.getBounds(): ${thisPath.getBounds()}, thisPath.computeMetrics: ${thisPath.computeMetrics()}');
//       output.add((thisPath, thisPaint));
//     }
//     return output;
//   }

//   //   1. Look at Point A, B, C, and D from your data array.
//   // 2. Calculate the two control points for the B-to-C segment using your Catmull-Rom spline logic.

//   // 3. Create a `Path` and move to B: `path.moveTo(B.x, B.y)`.
//   // 4. Draw the curve to C: `path.cubicTo(cp1.x, cp1.y, cp2.x, cp2.y, C.x, C.y)`.
//   // 5. Create your `LinearGradient` paint from B to C using your colormap.
//   // 6. Call `canvas.drawPath`.

//   static void drawTransformedText(
//     TextPainter textPainter,
//     Canvas canvas,
//     Offset position,
//   ) {
//     canvas.save();
//     canvas.translate(position.dx, position.dy);
//     final transform = Matrix4.rotationZ(-pi / 2)
//       ..scaleByVector3(v.Vector3(textWidthScale, 1.0, 1.0));
//     canvas.transform(transform.storage);
//     textPainter.paint(canvas, Offset.zero);
//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant GlobePainter oldDelegate) =>
//       !_angleMapsEquality.equals(oldDelegate.inputData, inputData) || colormap != oldDelegate.colormap;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final bottomHalfCirclePaint = Paint()
//       ..color = Colors.green.shade900
//       ..style = PaintingStyle.fill;

//     final topHalfCirclePaint = Paint()
//       ..color = Colors.blue.shade300
//       ..style = PaintingStyle.fill;

//     final groundOvalPaint = Paint()
//       ..color = Colors.green
//       ..style = PaintingStyle.fill;

//     final noonOvalPaint = Paint()
//       ..color = Colors.white
//       ..strokeWidth = 1
//       ..style = PaintingStyle.stroke;

//     final double vertDiam = size.height;
//     final double horDiam = size.width;
//     final Offset centerOffset = Offset(horDiam / 2, vertDiam / 2);
//     final Rect fullRect = Rect.fromLTWH(0, 0, horDiam, vertDiam);
//     final Rect groundRect = Rect.fromCenter(
//       center: centerOffset,
//       width: horDiam,
//       height: vertDiam * sin(xRotAngle),
//     );
//     final double verticalGapNoonToTop =
//         (1 - sqrt(1 - pow(xRotAngle, 2))) *
//         (vertDiam /
//             2); // Technically, this is vertDiam / 2 * (1 - sqrt(1 - (vertDiam/3 / vertDiam)^2)).  I have hardcoded this is to save performance.  If groundRect everchanges height, this will be incorrect.
//     final Rect noonRect = Rect.fromCenter(
//       center: centerOffset,
//       width: horDiam,
//       height: vertDiam - 2 * verticalGapNoonToTop,
//     );

//     canvas.drawArc(fullRect, 0, pi, true, bottomHalfCirclePaint);
//     canvas.drawArc(fullRect, 0, -pi, true, topHalfCirclePaint);
//     canvas.drawOval(groundRect, groundOvalPaint);
//     canvas.drawArc(noonRect, 0, -pi, false, noonOvalPaint);
//     canvas.drawLine(
//       centerOffset.translate(0, -(vertDiam / 2 - verticalGapNoonToTop)),
//       centerOffset,
//       noonOvalPaint,
//     );
//     final TextPainter textPainterN = textPainterCompassPoint('N');
//     final TextPainter textPainterS = textPainterCompassPoint('S');
//     final TextPainter textPainterE = textPainterCompassPoint('E');
//     final TextPainter textPainterW = textPainterCompassPoint('W');
//     textPainterN.layout();
//     textPainterS.layout();
//     textPainterE.layout();
//     textPainterW.layout();
//     final double minorToMajorRatio = groundRect.height / groundRect.width;
//     drawTransformedText(
//       textPainterN,
//       canvas,
//       Offset(
//         horDiam / 2 * textBufferCoefficientNS,
//         vertDiam / 2 + (textPainterN.width * textWidthScale) / 2,
//       ),
//     );
//     drawTransformedText(
//       textPainterS,
//       canvas,

//       Offset(
//         horDiam - horDiam / 2 * textBufferCoefficientNS - textPainterS.height,
//         vertDiam / 2 + (textPainterS.width * textWidthScale) / 2,
//       ),
//     );
//     drawTransformedText(
//       textPainterE,
//       canvas,

//       Offset(
//         horDiam / 2 - textPainterE.height / 2,
//         centerOffset.dy +
//             textWidthScale * textPainterE.width -
//             groundRect.height / 2 +
//             minorToMajorRatio * textBufferCoefficientNS * (vertDiam / 2),
//       ),
//     );
//     print(
//       'groundRect.center: ${groundRect.center}, groundRect.width: ${groundRect.width}, groundRect.height: ${groundRect.height}',
//     );
//     drawTransformedText(
//       textPainterW,
//       canvas,

//       Offset(
//         horDiam / 2 - textPainterE.height / 2,
//         centerOffset.dy +
//             groundRect.height / 2 -
//             minorToMajorRatio * textBufferCoefficientNS * (vertDiam / 2),
//       ),
//     );
//     canvas.save();
//     canvas.translate(0, 0);
//     // It is probably not right to use both the horDiam and the vertDiam.  Check this out later.
//     canvas.scale(horDiam / 2, vertDiam / 2);
//     // canvas.drawPath(solarTrail, pathPaint(horDiam / 2));
//     for (final (Path path, Paint paint) in solarPaths(horDiam / 2)) {
//       canvas.drawPath(path, paint);
//     }
//     canvas.restore();
//   }
// }
