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