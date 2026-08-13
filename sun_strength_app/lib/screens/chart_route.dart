// import 'dart:math';
// import 'dart:nativewrappers/_internal/vm/lib/ffi_allocation_patch.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/main.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:sun_strength_app/screens/color_scale_widget.dart';
import '../models/orbit_calcs.dart';
import 'package:sun_strength_app/screens/chart_widget.dart';


/// {@template ChartHomePage}
///
/// Widget called from the main screen that contains the full chart route/page.
///
/// Its only actual function is to expose the [Consumer] of the [CurrentLocationNotifier] to widgets below.
///
/// {@endtemplate}
class ChartHomePage extends StatelessWidget {
  /// {@macro ChartHomePage}
  const ChartHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrentLocationNotifier>(
      builder: (context, currentLocationNotifier, child) {
        print(
          'about to run builder for consumer of CurrentLocationNotifier.  currentLocatinoNotifer.value.name: ${currentLocationNotifier.value?.location.name}',
        );
        return currentLocationNotifier.value == null
            ? Placeholder()
            : HeatMap(currentChartSettings: currentLocationNotifier.value!);
      },
    );
  }
}

/// {@template HeatMap}
///
/// [SatefuleWidget] is the primary widgets containing the building blocks that make up
/// the solar strength chart page.
///
/// This widget holds the [ChartWidget], which is the chart itself, including labels, axes, etc.
/// It also holds the main screen title and all the buttons below.
///
/// Note: This Widget, the [HeatMap], creates a [HeatMapPainter] and passes that as an input to the
/// [ChartWidget] that it creates.  See [HeatMapPainter] docs for more info about it.  This
/// structure may seem convoluted, but it is done this way so that [ChartWidget] does not actually
/// need the raw image.  From the widget tree's perspective, the image itself is completely handled here, in [HeatMap].
/// It is created here and used here only.
///
/// There are two reasons [HeatMap] is stateful.  First, is holds the current K setting, i.e., the frequency band
/// currently being displayed.  Secondly, being stateful allows it to build the [ImageContainer] as a [Future] since
/// that function is async.  More accurately, building the [ui.Image] the async process.  [HeatMap] handles this by
/// defining the [Future] during [initState].  Then, it uses a [FutureBuilder] in the widget tree.  Also, note the
/// overriden [didUpdateWidget] that handles a new [HeatMap] widget and checks if the passed location has changed.
///
/// {@endtemplate}
class HeatMap extends StatefulWidget {
  /// {@macro HeatMap}
  const HeatMap({super.key, required this.currentChartSettings});
  final CurrentChartSettings currentChartSettings;

  @override
  State<HeatMap> createState() => _HeatMapState();
}

class _HeatMapState extends State<HeatMap> {
  double _currentK = 2;
  late Future<ImageContainer?> _chartImageFuture;

  /// The function that actually creates the 2D array of solar strength bytes.
  ///
  /// Note: k is the value that determines what wavelength of sunlight you are looking at:
  /// Visible: 0.22 <= k <= 0.36
  /// UV-A: 0.36 <= k <= 0.92
  /// UV-C: 2.3 <= k <= 4.6
  Future<ImageContainer?> createImage(double k) async {
    print(
      'running createImage with lat: ${widget.currentChartSettings.location.lat}, lon: ${widget.currentChartSettings.location.lon}, name: ${widget.currentChartSettings.location.name}',
    );

    // Generate the Iterable<double> that is all the data points for the chart.
    final Iterable<double> yearSolarStrengthsLocalRelative =
        masterFunctionSolarStrengthArray(
          timeZone: widget.currentChartSettings.timeZone,
          year: widget.currentChartSettings.year,
          h: 0,
          k: k,
          lat: widget.currentChartSettings.location.lat,
          lon: widget.currentChartSettings.location.lon,
        );
    final int pixelH = 96;
    final int pixelW = (yearSolarStrengthsLocalRelative.length / pixelH)
        .toInt();

    // Use the data points and the pixel width the create the actual chart
    final Future<ImageContainer> output = generateSunMap(
      chronologicalSunStrength: yearSolarStrengthsLocalRelative,
      pixelWidth: pixelW,
    );

    // I need a more robust way to determin leap year or not
    // return output;

    print('about to finish createImage');
    return output;
  }

  @override
  void initState() {
    print('just called initState');
    super.initState();
    _chartImageFuture = createImage(_currentK);
    print('hit end of initState');
  }

  /// Method called when a new [HeatMap] widget is built.  That new widget's parameters
  /// need to be checked against the previous ones used to build this State, and if
  /// different, this state needs to update itself.  That checking and updating is done by
  /// this method.
  @override
  void didUpdateWidget(covariant HeatMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the location actually changed between the old widget configuration and the new one
    if (widget.currentChartSettings != oldWidget.currentChartSettings) {
      print('Location changed! Triggering a new createImage future...');

      // Re-run createImage and tell FutureBuilder to rebuild by calling setState
      setState(() {
        _chartImageFuture = createImage(_currentK);
      });
    }
  }

  /// Method called by widgets in this build method to change which light frequency/wavelength range
  /// the chart should show
  void _updateParameter(double newValue) {
    print('just started updateParameter');
    setState(() {
      _currentK = newValue;
      // Explicitly trigger a re-run ONLY when the button is tapped!
      _chartImageFuture = createImage(_currentK);
    });
  }

  @override
  Widget build(BuildContext context) {
    print('just started build method for State<HeatMap>');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 800),
        child: Column(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<ImageContainer?>(
              future: _chartImageFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<ImageContainer?> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      print(
                        'snapshot.connectionState == ConnectionState.waiting',
                      );
                      return const Center(
                        child: CircularProgressIndicator(), // Your spinner
                      );
                    }
                    if (snapshot.hasError) {
                      print('snapshot.hasError');
                      return Center(
                        child: Text('Snapshot Error: ${snapshot.error}'),
                      );
                    }
                    if (snapshot.hasData) {
                      print('snapshot.hasData');

                      if (snapshot.data == null) {
                        return Center(child: Text('No data returned'));
                      } else {
                        return Column(
                          children: [
                            Text(widget.currentChartSettings.location.name),
                            ChartWidget(
                              chartArrayWidget: CustomPaint(
                                painter: HeatMapPainter(snapshot.data!.image),
                              ),
                              rawMatrixData: snapshot.data!.rawMatrixData,
                              nXAxisBuckets: 12,
                              nYAxisBuckets: 6,
                              leapYear: snapshot.data!.leapYear,
                              timeZone: widget.currentChartSettings.timeZone,
                              year: widget.currentChartSettings.year,
                            ),
                          ],
                        );
                      }
                    }

                    print(
                      'proceeding to final option after the other three snapshot cases',
                    );
                    // Fallback case (should rarely be reached)
                    if (snapshot.data == null) {
                      return const Center(child: Text('No location selected'));
                    } else {
                      return const Center(child: Text('No Image'));
                    }
                  },
            ),
            const ColorScaleWidget(),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _currentK == 0.3
                      ? null
                      : () => _updateParameter(0.3),
                  child: Text('Visible light'),
                ),
                ElevatedButton(
                  onPressed: _currentK == 0.64
                      ? null
                      : () => _updateParameter(0.64),
                  child: Text('UV-A'),
                ),
                ElevatedButton(
                  onPressed: _currentK == 2 ? null : () => _updateParameter(2),
                  child: Text('UV-B'),
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed:
                      context
                              .read<SavedSettingsNotifier>()
                              .value
                              ?.defaultLocation ==
                          widget.currentChartSettings.location
                      ? null
                      : () async {
                          await context
                              .read<SavedSettingsNotifier>()
                              .updateLocation(
                                widget.currentChartSettings.location,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Location saved as default',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                                width:
                                    200, // Narrows the width to look like a toast
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Save as default location'),
                ),
                ElevatedButton(
                  onPressed: () => context.read<UpdateCurrentIndex>()(1),
                  child: Text('Change location'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// {@template HeatMapPainter}
///
/// This widget takes an [ui.Image] object as an input actually "paints" that into a widget.
/// This way, this widget is given a canvas and a size and applies the [image] to that.
///
/// {@endtemplate}
class HeatMapPainter extends CustomPainter {
  final ui.Image? image;

  /// {@macro HeatMapPainter}
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

/// [Future] function that actually generates the sun strength chart image given the data point.  That image is actually returned
/// inside of an [ImageContainer].  This [Future] is called, received, and handled by [HeatMap].
///
/// The main work of this function is to receive the long, one-dimensional list of [double] sun strength values, reshape them into
/// the correct rows and columns, then convert them into the correct color bytes, and then create an [ui.Image] from that
/// two-dimensional list of color bytes.
Future<ImageContainer> generateSunMap({
  required Iterable<double> chronologicalSunStrength,
  required int pixelWidth,
}) async {
  print(
    'running generateSunMap, chronologicalSunStrength.length: ${chronologicalSunStrength.length}, pixelWidth: $pixelWidth',
  );
  const int height = 96; // 15-minute intervals in 24 hours (24 * 4)
  const int bytesPerPixel = 4; // RGBA

  // 1. Allocate the final flat byte buffer upfront.
  final Uint8List pixelBuffer = Uint8List(pixelWidth * height * bytesPerPixel);
  final List<List<double>> rawMatrixData = List.generate(
    pixelWidth,
    (_) => List.filled(96, 0.0),
  );

  int x = -1;
  int yMath = 0;
  int z = 0;

  // 2. Iterate once. This triggers the lazy evaluation item-by-item.
  // Memory overhead remains incredibly low because we don't store intermediate lists.
  for (double strength in chronologicalSunStrength) {
    // For rawMatrixData, x will index the outer list and y will index each inner list.
    if (yMath == 0) {
      x++;
    }

    // Invert Y because ui.decodeImageFromPixels expects Y=0 at the TOP,
    // but your math treats midnight morning as the BOTTOM.
    int yImage = 95 - yMath; // 96 - 1

    // Calculate the exact target starting byte in row-major order
    int targetByteIndex = (yImage * pixelWidth + x) * 4;
    pixelBuffer.replaceRange(targetByteIndex, targetByteIndex + 4, pixelByte(strength));
    // final Color color = colorFromMap(strength);
    // pixelBuffer[targetByteIndex] = color.r.toInt(); // R
    // pixelBuffer[targetByteIndex + 1] = color.g.toInt(); // G
    // pixelBuffer[targetByteIndex + 2] =color.b.toInt(); // B
    // pixelBuffer[targetByteIndex + 3] = 255; // A (Opaque)

    rawMatrixData[x][yImage] = strength;

    yMath++;

    if (yMath == 96) {
      yMath = 0;
    }

    z++;
    if (z == 200) {
      z = 0;
    }
  }

  // 3. Hand the perfectly ordered buffer over to the engine
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    pixelBuffer,
  );
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: pixelWidth,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );

  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();
  return ImageContainer(
    image: frame.image,
    leapYear: pixelWidth == 366,
    rawMatrixData: rawMatrixData,
  );
}

/// {@template ImageContainer}
///
/// Lightweight wrapper widget that pairs an [ui.Image], [image], along with the data explaining whether
/// this image is of a leap year, [leapYear], and also along with the raw data points, [rawMatrixData].
///
/// [image] will get used by the [HeatMapPainter].  [rawMatrixData] will get passed to
/// [ChartWidget] and used to fill out the hover text.
///
/// {@endtemplate}
class ImageContainer {
  /// {@macro ImageContainer}
  ImageContainer({
    required this.image,
    required this.leapYear,
    required this.rawMatrixData,
  });

  final ui.Image image;
  final bool leapYear;
  final List<List<double>> rawMatrixData;
}
