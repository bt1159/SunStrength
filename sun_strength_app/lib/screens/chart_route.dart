// import 'dart:nativewrappers/_internal/vm/lib/ffi_allocation_patch.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:sun_strength_app/screens/azimuth_widget.dart';
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
/// Note: This Widget, the [HeatMap], creates a [ImagePainter] and passes that as an input to the
/// [ChartWidget] that it creates.  See [ImagePainter] docs for more info about it.  This
/// structure may seem convoluted, but it is done this way so that [ChartWidget] does not actually
/// need the raw image.  From the widget tree's perspective, the image itself is completely handled here, in [HeatMap].
/// It is created here and used here only.
///
/// There are two reasons [HeatMap] is stateful.  First, is holds the current K setting, i.e., the frequency band
/// currently being displayed.  Secondly, being stateful allows it to build the [ChartImageContainer] as a [Future] since
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

  // /// The function that actually creates the 2D array of solar strength bytes.
  // ///
  // /// Note: k is the value that determines what wavelength of sunlight you are looking at:
  // /// Visible: 0.22 <= k <= 0.36
  // /// UV-A: 0.36 <= k <= 0.92
  // /// UV-C: 2.3 <= k <= 4.6
  // Future<ChartImageContainer> createChartImage(double k) async {
  //   print(
  //     'running createImage with lat: ${widget.currentChartSettings.location.lat}, lon: ${widget.currentChartSettings.location.lon}, name: ${widget.currentChartSettings.location.name}',
  //   );

  //   final Iterable<OrbitAndSolarValues> orbitAndSolarValuesIterable =
  //       calculateOrbitAndSolarValuesIterable(
  //         k: k,
  //         h: 0,
  //         lat: widget.currentChartSettings.location.lat,
  //         lon: widget.currentChartSettings.location.lon,
  //         timeZone: widget.currentChartSettings.timeZone,
  //         year: widget.currentChartSettings.year,
  //       );

  //   final int pixelH = 96;
  //   if (orbitAndSolarValuesIterable.length % pixelH != 0) {
  //     throw InvalidPixelWidth(
  //       pixelWidth: pixelH,
  //       iterableLength: orbitAndSolarValuesIterable.length,
  //     );
  //   }
  //   final int pixelW = (orbitAndSolarValuesIterable.length / pixelH).toInt();

  //   // Use the data points and the pixel width the create the actual chart
  //   final Future<ChartImageContainer> output = generateColorImageInContainer(
  //     valueIterable: orbitAndSolarValuesIterable.map(
  //       (e) => e.solarStrengthsLocalRelativeToGlobalMax,
  //     ),
  //     pixelWidth: pixelW,
  //     colormap: colorscheme.$2,
  //   );

  //   print('about to finish createImage');
  //   return output;
  // }

  // Future<ui.Image> createScaleImage() async {
  //   final int vertHeight = 40;
  //   final int horWidth = 100;
  //   Iterable<double> fullList = Iterable<double>.generate(
  //     vertHeight * horWidth,
  //     (index) {
  //       final int horIndex = (index / vertHeight).floor();
  //       return horIndex / (horWidth - 1);
  //     },
  //   );

  //   final (:image, :rawMatrixData) = await generateColorImage(
  //     valueIterable: fullList,
  //     pixelWidth: horWidth,
  //     colormap: colorscheme.$2,
  //   );

  //   return image;
  // }


  /// Method called by widgets in this build method to change which light frequency/wavelength range
  /// the chart should show
  void _updateParameter(double newValue) {
    print('just started updateParameter');
    setState(() {
      _currentK = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('just started build method for State<HeatMap>');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 800),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<DayIndexNotifier>(
              create: (_) => DayIndexNotifier(0),
            ),
            ChangeNotifierProvider<OrbitAndSolarValuesListNotifier>(
              create: (_) {
                final List<OrbitAndSolarValues> orbitAndSolarValuesList =
                    calculateOrbitAndSolarValuesIterable(
                      k: _currentK,
                      h: 0,
                      lat: widget.currentChartSettings.location.lat,
                      lon: widget.currentChartSettings.location.lon,
                      timeZone: widget.currentChartSettings.timeZone,
                      year: widget.currentChartSettings.year,
                    ).toList();
                return OrbitAndSolarValuesListNotifier(orbitAndSolarValuesList);
              },
            ),
          ],
          builder: (context, child) => Column(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Text(widget.currentChartSettings.location.name),
                  ChartWidget(
                    nXAxisBuckets: 12,
                    nYAxisBuckets: 6,
                    timeZone: widget.currentChartSettings.timeZone,
                    year: widget.currentChartSettings.year,
                  ),
                ],
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
                    onPressed: _currentK == 2
                        ? null
                        : () => _updateParameter(2),
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
                    onPressed: () =>
                        context.read<CurrentIndexNotifier>().value = 1,
                    child: Text('Change location'),
                  ),
                ],
              ),
              Selector<SavedSettingsNotifier, MyColorScheme?>(
                selector: (_, savedSettingsNotifier) =>
                    savedSettingsNotifier.value?.colorScheme,
                builder: (context, colorScheme, child) =>
                    DropdownMenu<MyColorScheme>(
                      initialSelection: colorScheme,
                      label: const Text('Select Color Scheme'),
                      onSelected: (MyColorScheme? value) {
                        if (value == null) {
                          context
                              .read<SavedSettingsNotifier>()
                              .clearColorScheme();
                        } else {
                          context
                              .read<SavedSettingsNotifier>()
                              .updateColorScheme(value);
                        }
                      },
                      dropdownMenuEntries:
                          List<DropdownMenuEntry<MyColorScheme>>.generate(
                            colorSchemes.length,
                            (index) => DropdownMenuEntry<MyColorScheme>(
                              value: colorSchemes[index],
                              label: colorSchemes[index].$1,
                            ),
                          ),
                    ),
              ),
              Flexible(fit: FlexFit.tight, child: const AzimuthWidget()),
            ],
          ),
        ),
      ),
    );
  }
}
