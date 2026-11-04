import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as v;
// import 'package:vector_math/vector_math_64.dart';

void main() {
  runApp(const MyApp2());
}

class MyApp2 extends StatelessWidget {
  const MyApp2({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizon Diagram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // <-- This does the heavy lifting
        ),
      ),
      themeMode: ThemeMode.dark,
      home:
          // const RowColumnTester(),
          Scaffold(
            appBar: AppBar(title: Text('Horizon Diagram')),
            body: SizedBox(
              height: 400,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: DiagramRenderWidget(),
              ),
            ),
          ),
    );
  }
}

class DiagramRenderWidget extends LeafRenderObjectWidget {
  const DiagramRenderWidget({super.key});

  @override
  DiagramRenderObject createRenderObject(BuildContext context) {
    return DiagramRenderObject();
  }
}

class DiagramRenderObject extends RenderBox with DebugOverflowIndicatorMixin {
  DiagramRenderObject();

  final TextPainter textPainterN = TextPainter(
    text: const TextSpan(
      text: 'N',
      style: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  final TextPainter textPainterS = TextPainter(
    text: const TextSpan(
      text: 'S',
      style: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  final TextPainter textPainterE = TextPainter(
    text: const TextSpan(
      text: 'E',
      style: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  final TextPainter textPainterW = TextPainter(
    text: const TextSpan(
      text: 'W',
      style: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  static const double textWidthScale = 0.7;
  static const double textBufferCoefficientNS = 0.1;

  static v.Vector3 convertAngleMapToXYZ(AngleMap angleMap) {
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

  final List<AngleMap> angleMaps = [
  AngleMap(alpha: 0, theta: 1.570796),
  AngleMap(alpha: 0.153224, theta: 1.767146),
  AngleMap(alpha: 0.300559, theta: 1.963495),
  AngleMap(alpha: 0.436344, theta: 2.159845),
  AngleMap(alpha: 0.55536, theta: 2.356194),
  AngleMap(alpha: 0.653035, theta: 2.552544),
  AngleMap(alpha: 0.725613, theta: 2.748894),
  AngleMap(alpha: 0.770307, theta: 2.945243),
  AngleMap(alpha: 0.785398, theta: 3.141593),
  AngleMap(alpha: 0.770307, theta: 3.337942),
  AngleMap(alpha: 0.725613, theta: 3.534292),
  AngleMap(alpha: 0.653035, theta: 3.730641),
  AngleMap(alpha: 0.55536, theta: 3.926991),
  AngleMap(alpha: 0.436344, theta: 4.12334),
  AngleMap(alpha: 0.300559, theta: 4.31969),
  AngleMap(alpha: 0.153224, theta: 4.516039),
  AngleMap(alpha: 0, theta: 4.712389),
];

  Iterable<v.Vector2> get pathLocalCoordinates => angleMaps.map((angleMap) {
    final v.Vector3 intermediateXYZ = convertAngleMapToXYZ(angleMap);
    final v.Vector2 output =
        convertXYZIntermediateToXY(intermediateXYZ, xRotAngle) +
        v.Vector2(1.0, 1.0);
    print(
      'inside pathLocalCoordinates getter, angleMap: $angleMap, intermediateXYZ: $intermediateXYZ, output: $output',
    );
    return output;
  });

  Path get solarTrail {
    Path path = Path();
    for (final (int index, v.Vector2 loc) in pathLocalCoordinates.indexed) {
      if (index == 0) {
        path.moveTo(loc.x, loc.y);
      } else {
        path.lineTo(loc.x, loc.y);
      }
    }
    return path;
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performResize() {
    size = computeDryLayout(constraints);
  }

  void drawTransformedText(
    TextPainter textPainter,
    Canvas canvas,
    Offset position,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    final transform = Matrix4.rotationZ(-pi / 2)
      ..scaleByVector3(v.Vector3(textWidthScale, 1.0, 1.0));
    canvas.transform(transform.storage);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bottomHalfCirclePaint = Paint()
      ..color = Colors.green.shade900
      ..style = PaintingStyle.fill;

    final topHalfCirclePaint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.fill;

    final groundOvalPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final noonOvalPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    Paint pathPaint(double scaleValue) => Paint()
      ..color = Colors.red
      ..strokeWidth = 4 / scaleValue
      ..style = PaintingStyle.stroke;

    final double vertDiam = size.height;
    final double horDiam = size.width;
    final Offset centerLocalOffset = Offset(horDiam / 2, vertDiam / 2);
    final Offset centerGlobalOffset = centerLocalOffset + offset;
    final Rect fullRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      horDiam,
      vertDiam,
    );
    final Rect groundRect = Rect.fromCenter(
      center: centerGlobalOffset,
      width: horDiam,
      height: vertDiam * sin(xRotAngle),
    );
    final double verticalGapNoonToTop =
        (1 - sqrt(1 - pow(xRotAngle,2))) *
        (vertDiam /
            2); // Technically, this is vertDiam / 2 * (1 - sqrt(1 - (vertDiam/3 / vertDiam)^2)).  I have hardcoded this is to save performance.  If groundRect everchanges height, this will be incorrect.
    final Rect noonRect = Rect.fromCenter(
      center: centerGlobalOffset,
      width: horDiam,
      height: vertDiam - 2 * verticalGapNoonToTop,
    );

    // final rectFull = Rect.fromCircle(center: offset + centerOffset, radius: hDiam / 2);
    context.canvas.drawArc(fullRect, 0, pi, true, bottomHalfCirclePaint);
    context.canvas.drawArc(fullRect, 0, -pi, true, topHalfCirclePaint);
    context.canvas.drawOval(groundRect, groundOvalPaint);
    context.canvas.drawArc(noonRect, 0, -pi, false, noonOvalPaint);
    context.canvas.drawLine(
      centerGlobalOffset.translate(0, -(vertDiam / 2 - verticalGapNoonToTop)),
      centerGlobalOffset,
      noonOvalPaint,
    );
    textPainterN.layout();
    textPainterS.layout();
    textPainterE.layout();
    textPainterW.layout();
    final double minorToMajorRatio = groundRect.height / groundRect.width;
    drawTransformedText(
      textPainterN,
      context.canvas,
      offset +
          Offset(
            horDiam / 2 * textBufferCoefficientNS,
            vertDiam / 2 + (textPainterN.width * textWidthScale) / 2,
          ),
    );
    drawTransformedText(
      textPainterS,
      context.canvas,
      offset +
          Offset(
            horDiam -
                horDiam / 2 * textBufferCoefficientNS -
                textPainterS.height,
            vertDiam / 2 + (textPainterS.width * textWidthScale) / 2,
          ),
    );
    drawTransformedText(
      textPainterE,
      context.canvas,
      offset +
          Offset(
            horDiam / 2 - textPainterE.height / 2,
            centerLocalOffset.dy +
                textWidthScale * textPainterE.width -
                groundRect.height / 2 +
                minorToMajorRatio * textBufferCoefficientNS * (vertDiam / 2),
          ),
    );
    print(
      'groundRect.center: ${groundRect.center}, groundRect.width: ${groundRect.width}, groundRect.height: ${groundRect.height}',
    );
    drawTransformedText(
      textPainterW,
      context.canvas,
      offset +
          Offset(
            horDiam / 2 - textPainterE.height / 2,
            centerLocalOffset.dy +
                groundRect.height / 2 -
                minorToMajorRatio * textBufferCoefficientNS * (vertDiam / 2),
          ),
    );
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    // It is probably not right to use both the horDiam and the vertDiam.  Check this out later.
    context.canvas.scale(horDiam / 2, vertDiam / 2);
    context.canvas.drawPath(solarTrail, pathPaint(horDiam / 2));
    context.canvas.restore();
  }
}

class AngleMap {
  const AngleMap({required this.alpha, required this.theta});

  final double alpha;
  final double theta;

  @override
  String toString() {
    return 'AngleMap(alpha: $alpha, theta: $theta)';
  }
}
