import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'orbit_calcs.dart';

class HeatMap extends StatefulWidget {
  const HeatMap({super.key});

  @override
  State<HeatMap> createState() => _HeatMapState();
}

class _HeatMapState extends State<HeatMap> {
  ui.Image? _heatmapImage;

  Future<void> setBytesAndTriggerImageCreation() async {
    final Iterable<({double earthRotationAngle, double trueAnomaly})>
    yearTrueAnomalies = getYearTrueAnomalies();
    final Iterable<double> yearSolarElevationAngles =
        getYearSolarElevationAngles(yearTrueAnomalies);
    final Iterable<double> yearSolarStrengthsLocalRelative =
        getYearSolarStrengthsLocalRelativeToGlobal(yearSolarElevationAngles);
    // final int listLength = yearSolarStrengthsLocalRelative.length;
    // final Iterable<double> tempOutput = yearSolarStrengthsLocalRelative
    //     .skip((listLength / 2).toInt())
    //     .take(96 * 10);
    print(
      'getYearSolarStrengthsLocalRelativeToGlobal.length: ${yearSolarStrengthsLocalRelative.length}',
    );
    final int pixelH = 96;
    final int pixelW = (yearSolarStrengthsLocalRelative.length / pixelH)
        .toInt();
    print('pixelW: $pixelW');

    // // Example: 12 pixels (3 rows X 4 columns X 4 Bytes per pixel)
    // final Uint8List rgbaList = Uint8List(
    //   yearSolarStrengthsLocalRelative.length * 4,
    // );

    // for (int i = 0; i < rgbaList.length; i = i + 4) {
    //   rgbaList[i] =
    //       yearSolarStrengthsLocalRelative.elementAt((i ~/ 4).toInt()) > 0.5
    //       ? 0
    //       : 255;
    //   rgbaList[i + 1] = 0;
    //   rgbaList[i + 2] =
    //       yearSolarStrengthsLocalRelative.elementAt((i ~/ 4).toInt()) <= 0.5
    //       ? 0
    //       : 255;
    //   rgbaList[i + 3] = 255;
    // }

    // ui.decodeImageFromPixels(
    //   rgbaList,
    //   pixelW,
    //   pixelH,
    //   ui.PixelFormat.rgba8888,
    //   (img) {
    //     setState(() {
    //       _heatmapImage = img;
    //     });
    //   },
    // );

    final ui.Image img = await generateSunMap(chronologicalSunStrength: yearSolarStrengthsLocalRelative, width: pixelW);
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
  Widget build(BuildContext context) {
    final bottomWidget = _heatmapImage == null
        ? Text('No Image')
        : Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: HeatMapPainter(_heatmapImage),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: setBytesAndTriggerImageCreation,
          child: Text('Reset Image'),
        ),
        bottomWidget,
        SizedBox(
          width: 400,
          height: 400,
          child: ColoredBox(color: Colors.brown),
        ),
      ],
    );
  }
}

class HeatMapPainter extends CustomPainter {
  final ui.Image? image;

  // Pass the image through the constructor
  HeatMapPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      // Logic for drawing the image goes here
      canvas.drawImage(image!, Offset.zero, Paint());
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

    // // Map your 0.0 - 1.0 float to an RGBA color value
    // // (Example: Grayscale mapping for strength, fully opaque)
    // int colorValue = (strength * 255).round().clamp(0, 255);

    // pixelBuffer[targetByteIndex] = colorValue; // R
    // pixelBuffer[targetByteIndex + 1] = colorValue; // G
    // pixelBuffer[targetByteIndex + 2] = colorValue; // B
    // pixelBuffer[targetByteIndex + 3] = 255; // A (Opaque)

    
    pixelBuffer[targetByteIndex] = 255; // R
    pixelBuffer[targetByteIndex + 1] = (strength * 255).toInt(); // G
    pixelBuffer[targetByteIndex + 2] = 0; // B
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
