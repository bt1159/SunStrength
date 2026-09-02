import 'dart:core';
import 'dart:math';
import 'package:color_map/color_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
// import 'package:vector_math/vector_math_64.dart' as vector;

class AzimuthWidget extends StatelessWidget {
  const AzimuthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrbitAndSolarValuesListNotifier, DayIndexNotifier>(
      builder: (context, orbitAndSolarValuesListNotifier, dayIndexNotifier, child) {
        print(
          'Consumer2<OrbitAndSolarValuesListNotifier, DayIndexNotifier> has been triggered insidde azimuth widget',
        );
        final int startingMasterIndex = 96 * dayIndexNotifier.value!;
        final List<OrbitAndSolarValues> orbitAndSolarValuesListSingleDay =
            orbitAndSolarValuesListNotifier.value.sublist(
              startingMasterIndex,
              startingMasterIndex + 96,
            );
        return Selector<SavedSettingsNotifier, MyColorScheme?>(
          selector: (_, savedAppSettingsNotifier) =>
              savedAppSettingsNotifier.value?.colorScheme,
              shouldRebuild: (previous, next) => previous?.$1 != next?.$1,
          builder: (context, myColorScheme, child) {
            print(
              'Running Builder under Selector<SavedSettingsNotifier, Colormap?> inside azimuth widget',
            );
            return Padding(
              padding: const EdgeInsets.all(40.0),
              // child: AzimuthRenderObjectWidget(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: BuilderAzimuthChart(
                    orbitAndSolarValuesListSingleDay:
                        orbitAndSolarValuesListSingleDay,
                    colormap: myColorScheme?.$2,
                  ),
                ),
              // ),
            );
          },
        );
      },
    );
  }
}

class BuilderAzimuthChart extends StatelessWidget {
  const BuilderAzimuthChart({
    super.key,
    required this.orbitAndSolarValuesListSingleDay,
    this.colormap,
  });

  final List<OrbitAndSolarValues> orbitAndSolarValuesListSingleDay;
  final Colormap? colormap;

  @override
  Widget build(BuildContext context) {
    print('Running BuilderAzimuthChart.build, colormap: $colormap');

    // final double startingHOffsetFromJ2000 =
    //     orbitAndSolarValuesListSingleDay.first.hOffsetFromJ2000;
    final Iterable<OrbitAndSolarValues> visibleSunOnlyData =
        orbitAndSolarValuesListSingleDay.where(
          (element) => element.solarElevationAngle > 0.0001,
        );

    final List<double> azAngles = visibleSunOnlyData
        .map((e) => e.solarAzimuthAngle)
        .toList();
    final List<double> elAngles = visibleSunOnlyData
        .map((e) => e.solarElevationAngle)
        .toList();

    final List<Offset> solarDataOffsets = visibleSunOnlyData
        .map(
          (e) => Offset(
            sin(e.solarAzimuthAngle) * cos(e.solarElevationAngle),

            -cos(e.solarAzimuthAngle) * cos(e.solarElevationAngle),
          ),
        )
        .toList();

    final List<double> solarDataStrengths = visibleSunOnlyData
        .map((e) => e.solarStrengthsLocalRelativeToGlobalMax)
        .toList();
    print(
      'orbitAndSolarValuesListSingleDay.length: ${orbitAndSolarValuesListSingleDay.length}',
    );
    print('azAngles: $azAngles');
    print('elAngles: $elAngles');
    print('solarDataOffsets: $solarDataOffsets');
    print('solarDataStrengths: $solarDataStrengths');

    return CustomPaint(
      painter: CustomPathRibbonPainter(
        points: solarDataOffsets,
        colormap: colormap ?? constColorMap,
        positiveStrengths: solarDataStrengths,
        appBackgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

// class AzimuthRenderObjectWidget extends SingleChildRenderObjectWidget {
//   const AzimuthRenderObjectWidget({super.key, super.child});

//   @override
//   AzimuthRenderObject createRenderObject(BuildContext context) {
//     print('Running createRenderObject inside AzimuthRenderObjectWidget');
//     return AzimuthRenderObject(appBackgroundColor: Theme.of(context).colorScheme.surface);
//   }

//   // @override
//   // void updateRenderObject(BuildContext context, covariant AzimuthRenderObject renderObject) {

//   // }
// }

// class AzimuthRenderObject extends RenderBox
//     with RenderObjectWithChildMixin<RenderBox>, DebugOverflowIndicatorMixin {
//   AzimuthRenderObject({required this.appBackgroundColor});

//   final Color appBackgroundColor;

//   @override
//   Size computeDryLayout(covariant BoxConstraints constraints) {
//     final Size drySize = Size(
//       min(constraints.maxWidth, constraints.maxHeight),
//       min(constraints.maxWidth, constraints.maxHeight),
//     );
//     return drySize;
//   }

//   @override
//   void performLayout() {
//     size = computeDryLayout(constraints);
//     child?.layout(BoxConstraints.tight(size));
//   }

//   @override
//   void paint(PaintingContext context, Offset offset) {
//     print('Running paint inside AzimuthRenderObject');
//     final Offset center = offset + Offset(size.width / 2, size.height / 2);
//     final double circleRadius = size.width / 2;

//     final Paint circlePaint = Paint()
//       ..color = Color.lerp(Colors.black, appBackgroundColor, 0.5)!
//       ..strokeWidth = 4
//       ..style = PaintingStyle.stroke;

//     context.canvas.drawCircle(center, circleRadius, circlePaint);
//     // child?.paint(context, offset);
//     if (child != null) {
//       context.paintChild(child!, offset);
//     }
//   }
// }
