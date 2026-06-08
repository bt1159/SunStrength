import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/orbit_calcs.dart';
import 'package:sun_strength_app/screens/chart_widget.dart';

class HeatMap extends StatefulWidget {
  const HeatMap({super.key});

  @override
  State<HeatMap> createState() => _HeatMapState();
}

class _HeatMapState extends State<HeatMap> {
  double _currentK = 2;
  late Future<ImageContainer> _chartImageFuture;

  /// The function that actually creates the 2D array of solar strength bytes.
  ///
  /// Note: k is the value that determines what wavelength of sunlight you are looking at:
  /// Visible: 0.22 <= k <= 0.36
  /// UV-A: 0.36 <= k <= 0.92
  /// UV-C: 2.3 <= k <= 4.6
  Future<ImageContainer> createImage(double k) async {
    final Iterable<double> yearSolarStrengthsLocalRelative =
        masterFunctionSolarStrengthArray(h: 0, k: k);
    final int pixelH = 96;
    final int pixelW = (yearSolarStrengthsLocalRelative.length / pixelH)
        .toInt();

    final Future<ImageContainer> output = generateSunMap(
      chronologicalSunStrength: yearSolarStrengthsLocalRelative,
      width: pixelW,
    );

    // I need a more robust way to determin leap year or not
    return output;
  }

  @override
  void initState() {
    super.initState();
    _chartImageFuture = createImage(_currentK);
  }

  void _updateParameter(double newValue) {
    setState(() {
      _currentK = newValue;
      // Explicitly trigger a re-run ONLY when the button is tapped!
      _chartImageFuture = createImage(_currentK);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<ImageContainer>(
          future: _chartImageFuture,
          builder: (BuildContext context, AsyncSnapshot<ImageContainer> snapshot) {
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

              if (snapshot.data == null) {
                return Center(child: Text('No data returned'));
              } else {

              return PublicChartRenderObjectWidget(
                chartArrayWidget: CustomPaint(
                  painter: HeatMapPainter(snapshot.data!.image),
                ),
                rawMatrixData: [],
                nXAxisBuckets: 12,
                nYAxisBuckets: 6,
                leapYear: snapshot.data!.leapYear,
              );
              }
            }

            print(
              'proceeding to final option after the other three snapshot cases',
            );
            // Fallback case (should rarely be reached)
            return const Center(child: Text('No Image'));
          },
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => _updateParameter(0.3),
              child: Text('Switch to visible light'),
            ),
            ElevatedButton(
              onPressed: () => _updateParameter(0.64),
              child: Text('Switch to UV-A'),
            ),
            ElevatedButton(
              onPressed: () => _updateParameter(2),
              child: Text('Switch to UV-B'),
            ),
          ],
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
        ..filterQuality = FilterQuality
            .medium; // Use .none for crisp pixel blocks, .medium for smooth blending

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

Future<ImageContainer> generateSunMap({
  required Iterable<double> chronologicalSunStrength,
  required int width,
}) async {
  const int height = 96; // 15-minute intervals in 24 hours (24 * 4)
  const int bytesPerPixel = 4; // RGBA

  // 1. Allocate the final flat byte buffer upfront.
  final Uint8List pixelBuffer = Uint8List(width * height * bytesPerPixel);
  final List<List<double>> rawMatrixData = List.filled(96, List.filled(width, 0));

  int x = -1;
  int yMath = 0;

  // 2. Iterate once. This triggers the lazy evaluation item-by-item.
  // Memory overhead remains incredibly low because we don't store intermediate lists.
  for (final strength in chronologicalSunStrength) {

    // For rawMatrixData, x will index the outer list and y will index each inner list.
    if (yMath == 0) {
      x++;
    }
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

    rawMatrixData[x][yImage] = strength;

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
  return ImageContainer(image: frame.image, leapYear: width == 366, rawMatrixData: rawMatrixData);
}

class ImageContainer {
  ImageContainer({required this.image, required this.leapYear, required this.rawMatrixData});

  final ui.Image image;
  final bool leapYear;
  final List<List<double>> rawMatrixData;
}