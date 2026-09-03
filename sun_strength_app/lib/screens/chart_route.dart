import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:sun_strength_app/widgets/azimuth_widget.dart';
import 'package:sun_strength_app/widgets/color_scale_widget.dart';
import '../models/orbit_calcs.dart';
import 'package:sun_strength_app/widgets/chart_widget.dart';

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
class HeatMap extends StatelessWidget {
  /// {@macro HeatMap}
  const HeatMap({super.key, required this.currentChartSettings});
  final CurrentChartSettings currentChartSettings;

  @override
  Widget build(BuildContext context) {
    print('just started build method for State<HeatMap>');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 800),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<KNotifier>(create: (_) => KNotifier(2.0)),
            ChangeNotifierProvider<DayIndexNotifier>(
              create: (_) => DayIndexNotifier(null),
            ),
            ChangeNotifierProxyProvider<
              KNotifier,
              OrbitAndSolarValuesListNotifier
            >(
              create: (_) {
                final List<OrbitAndSolarValues> orbitAndSolarValuesList =
                    calculateOrbitAndSolarValuesIterable(
                      k: 2,
                      h: 0,
                      lat: currentChartSettings.location.lat,
                      lon: currentChartSettings.location.lon,
                      timeZone: currentChartSettings.timeZone,
                      year: currentChartSettings.year,
                    ).toList();
                return OrbitAndSolarValuesListNotifier(orbitAndSolarValuesList);
              },
              update: (context, kNotifier, orbitAndSolarValuesListNotifier) {
                if (orbitAndSolarValuesListNotifier == null) {
                  throw 'null previous in ProxyProvider';
                }
                final List<OrbitAndSolarValues> orbitAndSolarValuesList =
                    calculateOrbitAndSolarValuesIterable(
                      k: kNotifier.value,
                      h: 0,
                      lat: currentChartSettings.location.lat,
                      lon: currentChartSettings.location.lon,
                      timeZone: currentChartSettings.timeZone,
                      year: currentChartSettings.year,
                    ).toList();
                return orbitAndSolarValuesListNotifier
                  ..value = orbitAndSolarValuesList;
              },
            ),
          ],
          builder: (context, child) {
            return ListView(              
              // spacing: 20,
              // crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpansionTile(
                  backgroundColor: Color.lerp(Theme.of(context).colorScheme.surface, Color.fromARGB(255,255,255,255),0.25),
                  title: Text(
                    'How does this chart work?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.zero, side: BorderSide.none),
                  children: [
                    Padding(padding: const EdgeInsets.all(16.0)),
                    Text(
                      'This chart shows the strength of the sun at every moment throughout '
                      'an entire year.  As you look across the chart from left to right, you '
                      'go from one day to the next, so the far left is January 1st.  As you go '
                      'up in the chart, from the bottom to the top, you go from the beginning '
                      'to the end of a single day.  You can hover your cursor over the chart '
                      'to see the time and date of any specific point and the strength of the '
                      'sun at that point.\n\n'
                      'The "strength" of the sun is always shown as a percentage of the '
                      'strongest sun strength the Earth ever gets, in other words when the sun '
                      'is straight up in the sky at the equator.\n\n'
                      'You may be suprised by how many places on Earth routinely get over 90% '
                      'of that max strength, but it\'s true!\n\n\n\n',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      currentChartSettings.location.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      currentChartSettings.year.toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ChartWidget(
                      nXAxisBuckets: 12,
                      nYAxisBuckets: 6,
                      timeZone: currentChartSettings.timeZone,
                      year: currentChartSettings.year,
                    ),
                  ],
                ),
                const ColorScaleWidget(),
                Consumer<KNotifier>(
                  builder: (context, kNotifer, child) => Row(
                    children: [
                      ElevatedButton(
                        onPressed: kNotifer.value == 0.3
                            ? null
                            : () => kNotifer.value = 0.3,
                        child: Text('Visible light'),
                      ),
                      ElevatedButton(
                        onPressed: kNotifer.value == 0.64
                            ? null
                            : () => kNotifer.value = 0.64,
                        child: Text('UV-A'),
                      ),
                      ElevatedButton(
                        onPressed: kNotifer.value == 2
                            ? null
                            : () => kNotifer.value = 2,
                        child: Text('UV-B'),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed:
                          context
                                  .read<SavedSettingsNotifier>()
                                  .value
                                  ?.defaultLocation ==
                              currentChartSettings.location
                          ? null
                          : () async {
                              await context
                                  .read<SavedSettingsNotifier>()
                                  .updateLocation(
                                    currentChartSettings.location,
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
                Selector<DayIndexNotifier, bool>(
                  selector: (_, dayIndexNotifier) =>
                      dayIndexNotifier.value != null,
                  builder: (context, valueNotNull, child) {
                    print(
                      'Inside the selector that determines whether to build the azimuth chart, dayIndex is ${valueNotNull ? 'not ' : ''}null',
                    );
                    return valueNotNull ? child! : Container();
                  },
                  child: const Flexible(
                    fit: FlexFit.tight,
                    child: AzimuthWidget(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
