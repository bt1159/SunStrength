import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/widgets/azimuth_widget.dart';
import 'package:sun_strength_app/widgets/color_scale_widget.dart';
import '../models/orbit_calcs.dart';
import 'package:sun_strength_app/widgets/chart_widget.dart';
import 'package:sun_strength_app/models/chart_notifiers.dart';
import 'package:sun_strength_app/models/main_notifiers.dart';

/// {@template ChartHomePage}
///
/// Widget called from the main screen that contains the full chart route/page.
///
/// Its only actual function is to expose the [Consumer] of the [CurrentChartSettingsNotifier] to widgets below.
///
/// {@endtemplate}
class ChartHomePage extends StatelessWidget {
  /// {@macro ChartHomePage}
  const ChartHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.read<CurrentChartSettingsNotifier>().value == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<KNotifier>(create: (_) => KNotifier(2.0)),
          ChangeNotifierProxyProvider2<
            KNotifier,
            CurrentChartSettingsNotifier,
            OrbitAndSolarValuesListNotifier
          >(
            create: (_) {
              print('running create for OrbitAndSolarValuesListNotifier');
              final CurrentChartSettings currentChartSettings = context
                  .read<CurrentChartSettingsNotifier>()
                  .value!;
              final List<OrbitAndSolarValues> orbitAndSolarValuesList =
                  calculateOrbitAndSolarValuesIterable(
                    k: 2,
                    h: 0,
                    lat: currentChartSettings.location.lat,
                    lon: currentChartSettings.location.lon,
                    timeZone: currentChartSettings.timeZone,
                    year: currentChartSettings.year,
                  ).toList();
              print('running CNP<OrbitAndSolarValuesListNotifier>.create');
              return OrbitAndSolarValuesListNotifier(
                orbitAndSolarValuesList,
                lastK: 2,
                lastcurrentChartSettings: currentChartSettings,
              );
            },
            update:
                (
                  context,
                  kNotifier,
                  currentLocationNotifier,
                  orbitAndSolarValuesListNotifier,
                ) {
                  if (orbitAndSolarValuesListNotifier == null) {
                    throw 'null previous in ProxyProvider';
                  }
                  print(
                    'running update for orbitAndSolarValuesListNotifier.  lastK: ${orbitAndSolarValuesListNotifier.lastK}, lastchart: ${orbitAndSolarValuesListNotifier.lastcurrentChartSettings}, this k: ${kNotifier.value}',
                  );
                  if (currentLocationNotifier.value ==
                      orbitAndSolarValuesListNotifier
                          .lastcurrentChartSettings) {
                    if (kNotifier.value ==
                        orbitAndSolarValuesListNotifier.lastK) {
                      return orbitAndSolarValuesListNotifier;
                    } else {
                      final List<OrbitAndSolarValues> orbitAndSolarValuesList =
                          recalculateOrbitAndSolarValuesIterableNewK(
                            h: 0,
                            k: kNotifier.value,
                            oldValues: orbitAndSolarValuesListNotifier.value,
                          ).toList();
                      return orbitAndSolarValuesListNotifier
                        ..lastK = kNotifier.value
                        ..value = orbitAndSolarValuesList;
                    }
                  } else {
                    final List<OrbitAndSolarValues> orbitAndSolarValuesList =
                        calculateOrbitAndSolarValuesIterable(
                          k: kNotifier.value,
                          h: 0,
                          lat: currentLocationNotifier.value!.location.lat,
                          lon: currentLocationNotifier.value!.location.lon,
                          timeZone: currentLocationNotifier.value!.timeZone,
                          year: currentLocationNotifier.value!.year,
                        ).toList();

                    return orbitAndSolarValuesListNotifier
                      ..lastK = kNotifier.value
                      ..value = orbitAndSolarValuesList
                      ..lastcurrentChartSettings =
                          currentLocationNotifier.value;
                  }
                },
          ),
          ChangeNotifierProxyProvider<
            OrbitAndSolarValuesListNotifier,
            DayDataNotifier
          >(
            create: (_) => DayDataNotifier(null),
            update: DayDataNotifier.changeNotifierProxyProviderUpdateFunction,
          ),
        ],
        builder: (context, child) => Column(
          children: [
            const PinnedChartPageWidget(),
            const ScrollableChartPageWidget(),
          ],
        ),
      ),
    );
  }
}

class PinnedChartPageWidget extends StatelessWidget {
  const PinnedChartPageWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: SizedBox(
          width: double.infinity,
          child: Consumer<CurrentChartSettingsNotifier>(
            builder: (context, currentLocationNotifier, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    currentLocationNotifier.value!.location.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    currentLocationNotifier.value!.year.toString(),
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

class ScrollableChartPageWidget extends StatelessWidget {
  const ScrollableChartPageWidget({super.key});

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
                const AzimuthWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DropdownColorschemeButton extends StatelessWidget {
  const DropdownColorschemeButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kButtonTapTargetPadding),
      child: Selector<SavedSettingsNotifier, MyColorScheme?>(
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
    );
  }
}

class KButtonRow extends StatelessWidget {
  const KButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KNotifier>(
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
    return Consumer<CurrentChartSettingsNotifier>(
      builder: (context, currentChartSettingsNotifier, child) {
        return Row(
          spacing: 20,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed:
                  (context
                              .read<SavedSettingsNotifier>()
                              .value
                              ?.defaultLocation ==
                          currentChartSettingsNotifier.value?.location ||
                      currentChartSettingsNotifier.value?.location == null)
                  ? null
                  : () async {
                      await context
                          .read<SavedSettingsNotifier>()
                          .updateLocation(
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
              onPressed: () => context.read<PageIndexNotifier>().value = 1,
              child: Text('Change location'),
            ),
            Selector<SavedSettingsNotifier, Location?>(
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
                                .read<SavedSettingsNotifier>()
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
