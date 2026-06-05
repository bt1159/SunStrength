import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'orbit_calcs.dart';
import 'package:sun_strength_app/chart_widget.dart';

class HeatMap extends StatelessWidget {
  const HeatMap({super.key});

  Future<ui.Image> createImage() async {
    final Iterable<({double earthRotationAngle, double trueAnomaly})>
    yearTrueAnomalies = getYearTrueAnomalies();
    print(yearTrueAnomalies.first);
    final Iterable<double> yearSolarElevationAngles =
        getYearSolarElevationAngles(yearTrueAnomalies);
    print(
      'yearSolarElevationAngles, first 96: ${yearSolarElevationAngles.take(96).toList()}',
    );
    final Iterable<double> yearSolarStrengthsLocalRelative =
        getYearSolarStrengthsLocalRelativeToGlobal(
          h: 0,
          //k: 0.8,
          k: 2,
          yearSolarElevationAngles: yearSolarElevationAngles,
        );
    print(
      'getYearSolarStrengthsLocalRelativeToGlobal.first: ${yearSolarStrengthsLocalRelative.first}',
    );
    print(
      'getYearSolarStrengthsLocalRelativeToGlobal.length: ${yearSolarStrengthsLocalRelative.length}',
    );
    final int pixelH = 96;
    final int pixelW = (yearSolarStrengthsLocalRelative.length / pixelH)
        .toInt();
    print('pixelW: $pixelW');

    final Future<ui.Image> img = generateSunMap(
      chronologicalSunStrength: yearSolarStrengthsLocalRelative,
      width: pixelW,
    );
    return img;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: createImage(),
      builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('snapshot.connectionState == ConnectionState.waiting');
          return const Center(
            child: CircularProgressIndicator(), // Your spinner
          );
        }
        if (snapshot.hasError) {
          print('snapshot.hasError');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.hasData) {
          print('snapshot.hasData');
    
          return PublicChartRenderObjectWidget(
            chartArrayWidget: CustomPaint(
              painter: HeatMapPainter(snapshot.data),
            ),
            nXAxisBuckets: 4,
            nYAxisBuckets: 4,
          );
        }
    
        print(
          'proceeding to final option after the other three snapshot cases',
        );
        // Fallback case (should rarely be reached)
        return const Center(child: Text('No Image'));
      },
    );
  }
}

/// {@template HeatMap}
/// Widget that holds either a blank Widget or the 2D array of the heat map.  Since the function that creates
/// the heat map is async, when it loads, it replaces the child of this widget.  That way, this widget remains
/// unaffected.
/// {@endtemplate}
class HeatMapArchive extends StatefulWidget {
  /// {@macro HeatMap}
  const HeatMapArchive({super.key});

  @override
  State<HeatMapArchive> createState() => _HeatMapArchiveState();
}

class _HeatMapArchiveState extends State<HeatMapArchive> {
  ui.Image? _heatmapImage;

  Future<void> setBytesAndTriggerImageCreation() async {
    final Iterable<({double earthRotationAngle, double trueAnomaly})>
    yearTrueAnomalies = getYearTrueAnomalies();
    print(yearTrueAnomalies.first);
    final Iterable<double> yearSolarElevationAngles =
        getYearSolarElevationAngles(yearTrueAnomalies);
    print(
      'yearSolarElevationAngles, first 96: ${yearSolarElevationAngles.take(96).toList()}',
    );
    final Iterable<double> yearSolarStrengthsLocalRelative =
        getYearSolarStrengthsLocalRelativeToGlobal(
          h: 0,
          //k: 0.8,
          k: 2,
          yearSolarElevationAngles: yearSolarElevationAngles,
        );
    // final int listLength = yearSolarStrengthsLocalRelative.length;
    // final Iterable<double> tempOutput = yearSolarStrengthsLocalRelative
    //     .skip((listLength / 2).toInt())
    //     .take(96 * 10);
    print(
      'getYearSolarStrengthsLocalRelativeToGlobal.first: ${yearSolarStrengthsLocalRelative.first}',
    );
    print(
      'getYearSolarStrengthsLocalRelativeToGlobal.length: ${yearSolarStrengthsLocalRelative.length}',
    );
    final int pixelH = 96;
    final int pixelW = (yearSolarStrengthsLocalRelative.length / pixelH)
        .toInt();
    print('pixelW: $pixelW');

    final ui.Image img = await generateSunMap(
      chronologicalSunStrength: yearSolarStrengthsLocalRelative,
      width: pixelW,
    );
    setState(() {
      _heatmapImage = img;
    });
  }

  @override
  void dispose() {
    _heatmapImage?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies(); // Always call super first

    // Example: Reacting to a change in Theme or Provider
    setBytesAndTriggerImageCreation();
  }

  @override
  Widget build(BuildContext context) {
    final bottomWidget = _heatmapImage == null
        ? Text('No Image')
        : PublicChartRenderObjectWidget(
            chartArrayWidget: CustomPaint(
              painter: HeatMapPainter(_heatmapImage),
            ),
            nXAxisBuckets: 4,
            nYAxisBuckets: 4,
          );
    return bottomWidget;
  }
}

class HeatMapPainter extends CustomPainter {
  final ui.Image? image;

  // Pass the image through the constructor
  HeatMapPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      // 1. Define the full bounds of the raw source image pixels
      final Rect src = Rect.fromLTWH(
        0, 
        0, 
        image!.width.toDouble(), 
        image!.height.toDouble(),
      );
      
      // 2. Define the full layout bounds allocated to your CustomPaint (600x300)
      final Rect dst = Rect.fromLTWH(0, 0, size.width, size.height);
      
      // 3. Create a paint object. 
      // Optional: Set filterQuality to determine how pixels blend when stretched
      final Paint paint = Paint()
        ..filterQuality = FilterQuality.medium; // Use .none for crisp pixel blocks, .medium for smooth blending

      // 4. Draw it stretched!
      canvas.drawImageRect(image!, src, dst, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HeatMapPainter oldDelegate) {
    // Optimization: Only repaint if the image object has actually changed
    return oldDelegate.image != image;
  }
}

Future<ui.Image> generateSunMap({
  required Iterable<double> chronologicalSunStrength,
  required int width,
}) async {
  const int height = 96; // 15-minute intervals in 24 hours (24 * 4)
  const int bytesPerPixel = 4; // RGBA

  // 1. Allocate the final flat byte buffer upfront.
  final Uint8List pixelBuffer = Uint8List(width * height * bytesPerPixel);

  int x = 0;
  int yMath = 0;

  // 2. Iterate once. This triggers the lazy evaluation item-by-item.
  // Memory overhead remains incredibly low because we don't store intermediate lists.
  for (final strength in chronologicalSunStrength) {
    // Determine which day (X) and 15-min block (Y_math) this value represents

    // Invert Y because ui.decodeImageFromPixels expects Y=0 at the TOP,
    // but your math treats midnight morning as the BOTTOM.
    int yImage = 95 - yMath; // 96 - 1

    // Calculate the exact target starting byte in row-major order
    int targetByteIndex = (yImage * 365 + x) * 4;

    pixelBuffer[targetByteIndex] = (min(1, 3 * strength) * 255).toInt(); // R
    pixelBuffer[targetByteIndex + 1] = (min(1, max(0, 3 * strength - 1)) * 255)
        .toInt(); // G
    pixelBuffer[targetByteIndex + 2] = (max(0, 3 * strength - 2) * 255)
        .toInt(); // B
    pixelBuffer[targetByteIndex + 3] = 255; // A (Opaque)

    yMath++;
    if (yMath == 96) {
      yMath = 0;
      x++;
    }
  }

  // 3. Hand the perfectly ordered buffer over to the engine
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    pixelBuffer,
  );
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );

  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

