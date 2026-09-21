import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/screens/location_selection_route.dart';
import 'package:sun_strength_app/widgets/azimuth_widget.dart';
import 'package:sun_strength_app/widgets/color_scale_widget.dart';
// import 'package:timezone/timezone.dart' as tz;
import '../models/orbit_calcs.dart';
import 'package:sun_strength_app/widgets/chart_widget.dart';
import 'package:sun_strength_app/models/chart_notifiers.dart';
import 'package:sun_strength_app/models/main_notifiers.dart';

/// {@template ChartHomePage}
///
/// Widget called from the main screen that contains the full chart route/page.
///
/// Its only actual function is to expose the [Consumer] of the [ChartSettingsNot] to widgets below.
///
/// {@endtemplate}
class ChartRoute extends StatelessWidget {
  /// {@macro ChartHomePage}
  const ChartRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ChartAppBar(),
      drawer: const MainScaffoldDrawer(),
      body: Builder(
        builder: (context) {
          if (context.read<ChartSettingsNot>().value == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MultiProvider(
              providers: [
                CNP<KNot>(create: (_) => KNot(2.0)),
                CNPP2<KNot, ChartSettingsNot, OrbSolValuesListNot>(
                  create: (_) {
                    return OrbSolValuesListNot(<OrbSolValues>[]);
                  },
                  update: (context, kNot, chartSettingsNot, orbSolValuesListNot) {
                    if (orbSolValuesListNot == null) {
                      throw 'null previous in ProxyProvider';
                    }
                    print(
                      'running update for orbitAndSolarValuesListNotifier.  lastK: ${orbSolValuesListNot.lastK}, lastchart: ${orbSolValuesListNot.lastcurrentChartSettings}, this k: ${kNot.value}',
                    );
                    if (orbSolValuesListNot.value.isNotEmpty) {
                      if (chartSettingsNot.value ==
                          orbSolValuesListNot.lastcurrentChartSettings) {
                        if (kNot.value == orbSolValuesListNot.lastK) {
                          return orbSolValuesListNot;
                        } else {
                          final List<OrbSolValues> orbitAndSolarValuesList =
                              recalculateOrbSolValuesIterNewK(
                                h: 0,
                                k: kNot.value,
                                oldValues: orbSolValuesListNot.value,
                              ).toList();
                          return orbSolValuesListNot
                            ..lastK = kNot.value
                            ..value = orbitAndSolarValuesList;
                        }
                      }
                    }

                    final List<OrbSolValues> orbitAndSolarValuesList =
                        calculateOrbSolValuesIter(
                          k: kNot.value,
                          h: 0,
                          lat: chartSettingsNot.value!.location.lat,
                          lon: chartSettingsNot.value!.location.lon,
                          timeZone: chartSettingsNot.value!.timeZone,
                          year: chartSettingsNot.value!.year,
                        ).toList();

                    return orbSolValuesListNot
                      ..lastK = kNot.value
                      ..value = orbitAndSolarValuesList
                      ..lastcurrentChartSettings = chartSettingsNot.value;
                  },
                ),
                CNPP<OrbSolValuesListNot, DayDataNot>(
                  create: (_) => DayDataNot(<OrbSolValues>[]),
                  update: DayDataNot.cNPPUpdateFunction,
                ),
              ],
              builder: (context, child) => Column(
                children: [
                  const PinnedChartPageHeading(),
                  const ScrollableChartPageContent(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PinnedChartPageHeading extends StatelessWidget {
  const PinnedChartPageHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: SizedBox(
          width: double.infinity,
          child: Consumer<ChartSettingsNot>(
            builder: (context, chartSettingsNot, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    chartSettingsNot.value!.location.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    chartSettingsNot.value!.year.toString(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class ScrollableChartPageContent extends StatelessWidget {
  const ScrollableChartPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: Column(
              spacing: 10,
              children: [
                const ChartWidget(nXAxisBuckets: 12, nYAxisBuckets: 6),
                const ColorScaleWidget(),
                const KButtonRow(),
                const LocationButtonRow(),
                const DropdownColorschemeButton(),
                const AzimuthChart(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScrollableChartPageContentR extends StatelessWidget {
  const ScrollableChartPageContentR({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {

            return Flex(
              direction: constraints.maxWidth > 800 ? Axis.horizontal : Axis.vertical,
              children: [
                Column(
                  spacing: 10,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 800),
                        child: const ChartWidget(
                          nXAxisBuckets: 12,
                          nYAxisBuckets: 6,
                        ),
                      ),
                    ),
                    const ColorScaleWidget(),
                    const KButtonRow(),
                    const LocationButtonRow(),
                    const DropdownColorschemeButton(),
                  ],
                ),
                const AzimuthChart(),
              ],
            );
          }
        ),
      ),
    );
  }
}

class DropdownColorschemeButton extends StatelessWidget {
  const DropdownColorschemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kButtonTapTargetPadding),
      child: Selector<SavedSettingsNot, MyColorScheme?>(
        selector: (_, savedSettingsNotifier) =>
            savedSettingsNotifier.value?.colorScheme,
        builder: (context, colorScheme, child) => DropdownMenu<MyColorScheme>(
          initialSelection: colorScheme,
          label: const Text('Select Color Scheme'),
          onSelected: (MyColorScheme? value) {
            if (value == null) {
              context.read<SavedSettingsNot>().clearColorScheme();
            } else {
              context.read<SavedSettingsNot>().updateColorScheme(value);
            }
          },
          dropdownMenuEntries: List<DropdownMenuEntry<MyColorScheme>>.generate(
            colorSchemes.length,
            (index) => DropdownMenuEntry<MyColorScheme>(
              value: colorSchemes[index],
              label: colorSchemes[index].$1,
            ),
          ),
        ),
      ),
    );
  }
}

class KButtonRow extends StatelessWidget {
  const KButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KNot>(
      builder: (context, kNotifer, child) {
        print('Building k button row, k: ${kNotifer.value}');
        return Row(
          spacing: 20,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: kNotifer.value == 0.3
                  ? null
                  : () {
                      print(
                        'current k: ${kNotifer.value}, about to change it to 0.3',
                      );
                      kNotifer.value = 0.3;
                    },
              child: Text('Visible light'),
            ),
            ElevatedButton(
              onPressed: kNotifer.value == 0.64
                  ? null
                  : () {
                      print(
                        'current k: ${kNotifer.value}, about to change it to 0.64',
                      );
                      kNotifer.value = 0.64;
                    },
              child: Text('UV-A'),
            ),
            ElevatedButton(
              onPressed: kNotifer.value == 2
                  ? null
                  : () {
                      print(
                        'current k: ${kNotifer.value}, about to change it to 2',
                      );
                      kNotifer.value = 2;
                    },
              child: Text('UV-B'),
            ),
          ],
        );
      },
    );
  }
}

class LocationButtonRow extends StatelessWidget {
  const LocationButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChartSettingsNot>(
      builder: (context, currentChartSettingsNotifier, child) {
        return Row(
          spacing: 20,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed:
                  (context.read<SavedSettingsNot>().value?.defaultLocation ==
                          currentChartSettingsNotifier.value?.location ||
                      currentChartSettingsNotifier.value?.location == null)
                  ? null
                  : () async {
                      await context.read<SavedSettingsNot>().updateLocation(
                        currentChartSettingsNotifier.value!.location,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Location saved as default'),
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LocationSelectionRoute(),
                ),
              ),
              child: Text('Change location'),
            ),
            Selector<SavedSettingsNot, Location?>(
              selector: (_, savedSettingsNotifier) =>
                  savedSettingsNotifier.value?.defaultLocation,
              builder: (context, defaultLocation, child) => ElevatedButton(
                onPressed:
                    (defaultLocation == null ||
                        currentChartSettingsNotifier.value?.location ==
                            defaultLocation)
                    ? null
                    : () => currentChartSettingsNotifier
                          .updateCurrentChartSettings(
                            newLocation: context
                                .read<SavedSettingsNot>()
                                .value!
                                .defaultLocation,
                          ),
                child: Text('Reset chart to default location'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ChartAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChartAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: const Text('Sun strength'),
      actions: [
        IconButton(
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Information'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      Text(
                        'Heatmap chart',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                        'of that max strength, but it\'s true!',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Visible light vs. UV bands',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'There are three buttons that let you select why kind of sunlight the chart '
                        'is considering.  If you click "Visible light", you are essentially looking '
                        'at how much visible light your location is reciving. This is pretty much like '
                        'the calculators only that calculate your solar energy savings.\n\n'
                        'When you click UV-A or UV-B, you are only considering the sun\'s ultraviolet '
                        'light.  This is what really matters if you are focusing on skin health and '
                        'avoiding sunburn.\n\n'
                        'Within ultraviolet light, UV-B is the portion that is, by far, the most dangerous. '
                        'You should absolutely avoid a lot of UV-B exposure.  Luckily, most UV-B light gets '
                        'blocked whever the sun is a decent amount away from straight overhead.\n\n'
                        'Even though UV-A is not as harmful as UV-B, it is better at getting through the '
                        'atmosphere.  That means it is still dangerous even when the sun is much lower in '
                        'the sky.\n\n'
                        'So, what should you click?  Usually, looking at UV-A is the best bet if you are '
                        'trying to protect your skin.  That said, it is sometimes helpful to check out '
                        'UV-B to see the times you should definitely be the most careful.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Direction of the sun, the bottom chart',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'The bottom chart primarily shows where the sun will be at any point '
                        'during one specific day.  The circular chart works like a compass, so if '
                        'it shows the sun at the far left edge at a certain time, that means the '
                        'sun will be due East in the sky when it rises.  As the sun gets higher in '
                        'the sky, it moves toward the center.  Basically, it\'s a bit like looking '
                        'down from a bird\'s eye view.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ok'),
                ),
              ],
            ),
          ),
          icon: Icon(Icons.info),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
