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

  void setBytesAndTriggerImageCreation() {
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

    // Example: 12 pixels (3 rows X 4 columns X 4 Bytes per pixel)
    final Uint8List rgbaList = Uint8List(
      yearSolarStrengthsLocalRelative.length * 4,
    );

    for (int i = 0; i < rgbaList.length; i = i + 4) {
      rgbaList[i] =
          yearSolarStrengthsLocalRelative.elementAt((i ~/ 4).toInt()) > 0.5 ? 0 : 255 ;
      rgbaList[i + 1] = 0;
      rgbaList[i + 2] = yearSolarStrengthsLocalRelative.elementAt((i ~/ 4).toInt()) <= 0.5 ? 0 : 255 ;
      rgbaList[i + 3] = 255;
    }

    ui.decodeImageFromPixels(
      rgbaList,
      pixelW,
      pixelH,
      ui.PixelFormat.rgba8888,
      (img) {
        setState(() {
          _heatmapImage = img;
        });
      },
    );
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
