import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:sun_strength_app/widgets/azimuth_widget.dart';
import 'package:sun_strength_app/widgets/color_scale_widget.dart';
import 'package:timezone/timezone.dart' as tz;
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
            ? Container()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MultiProvider(
                  providers: [
                    ChangeNotifierProvider<KNotifier>(
                      create: (_) => KNotifier(2.0),
                    ),
                    ChangeNotifierProvider<DayIndexNotifier>(
                      create: (_) => DayIndexNotifier(null),
                    ),
                    ChangeNotifierProxyProvider2<
                      KNotifier,
                      CurrentLocationNotifier,
                      OrbitAndSolarValuesListNotifier
                    >(
                      create: (_) {
                        final List<OrbitAndSolarValues>
                        orbitAndSolarValuesList =
                            calculateOrbitAndSolarValuesIterable(
                              k: 2,
                              h: 0,
                              lat: currentLocationNotifier.value!.location.lat,
                              lon: currentLocationNotifier.value!.location.lon,
                              timeZone: currentLocationNotifier.value!.timeZone,
                              year: currentLocationNotifier.value!.year,
                            ).toList();
                        return OrbitAndSolarValuesListNotifier(
                          orbitAndSolarValuesList,
                          lastK: 2,
                          lastcurrentChartSettings:
                              currentLocationNotifier.value,
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
                            if (currentLocationNotifier.value ==
                                orbitAndSolarValuesListNotifier
                                    .lastcurrentChartSettings) {
                              if (kNotifier.value ==
                                  orbitAndSolarValuesListNotifier.lastK) {
                                return orbitAndSolarValuesListNotifier;
                              } else {
                                final List<OrbitAndSolarValues>
                                orbitAndSolarValuesList =
                                    recalculateOrbitAndSolarValuesIterableNewK(
                                      h: 0,
                                      k: kNotifier.value,
                                      oldValues:
                                          orbitAndSolarValuesListNotifier.value,
                                    ).toList();
                                return orbitAndSolarValuesListNotifier
                                  ..value = orbitAndSolarValuesList;
                              }
                            } else {
                              final List<OrbitAndSolarValues>
                              orbitAndSolarValuesList =
                                  calculateOrbitAndSolarValuesIterable(
                                    k: kNotifier.value,
                                    h: 0,
                                    lat: currentLocationNotifier
                                        .value!
                                        .location
                                        .lat,
                                    lon: currentLocationNotifier
                                        .value!
                                        .location
                                        .lon,
                                    timeZone:
                                        currentLocationNotifier.value!.timeZone,
                                    year: currentLocationNotifier.value!.year,
                                  ).toList();
                              return OrbitAndSolarValuesListNotifier(
                                orbitAndSolarValuesList,
                                lastK: 2,
                                lastcurrentChartSettings:
                                    currentLocationNotifier.value,
                              );
                            }
                          },
                    ),
                  ],
                  builder: (context, child) {
                    return SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 800),
                          child: Column(
                            spacing: 20,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    currentLocationNotifier
                                        .value!
                                        .location
                                        .name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  Text(
                                    currentLocationNotifier.value!.year
                                        .toString(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  SizedBox(height: 20),
                                  Align(
                                    alignment: AlignmentGeometry.centerLeft,
                                    child: Text(
                                      'Sun strength throughout the year',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  ChartWidget(
                                    nXAxisBuckets: 12,
                                    nYAxisBuckets: 6,
                                    timeZone:
                                        currentLocationNotifier.value!.timeZone,
                                    year: currentLocationNotifier.value!.year,
                                  ),
                                ],
                              ),
                              const ColorScaleWidget(),
                              Consumer<KNotifier>(
                                builder: (context, kNotifer, child) => Row(
                                  spacing: 20,
                                  mainAxisSize: MainAxisSize.min,
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
                                spacing: 20,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed:
                                        context
                                                .read<SavedSettingsNotifier>()
                                                .value
                                                ?.defaultLocation ==
                                            currentLocationNotifier
                                                .value!
                                                .location
                                        ? null
                                        : () async {
                                            await context
                                                .read<SavedSettingsNotifier>()
                                                .updateLocation(
                                                  currentLocationNotifier
                                                      .value!
                                                      .location,
                                                );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'Location saved as default',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                  width:
                                                      200, // Narrows the width to look like a toast
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Save as default location',
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        context
                                                .read<CurrentIndexNotifier>()
                                                .value =
                                            1,
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
                                          List<
                                            DropdownMenuEntry<MyColorScheme>
                                          >.generate(
                                            colorSchemes.length,
                                            (index) =>
                                                DropdownMenuEntry<
                                                  MyColorScheme
                                                >(
                                                  value: colorSchemes[index],
                                                  label: colorSchemes[index].$1,
                                                ),
                                          ),
                                    ),
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 400),
                                child: Selector<DayIndexNotifier, bool>(
                                  selector: (_, dayIndexNotifier) =>
                                      dayIndexNotifier.value != null,
                                  builder: (context, valueNotNull, child) {
                                    print(
                                      'Inside the selector that determines whether to build the azimuth chart, dayIndex is ${valueNotNull ? 'not ' : ''}null',
                                    );
                                    return valueNotNull ? child! : Container();
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sun strength and location on a single day',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Consumer<DayIndexNotifier>(
                                        builder:
                                            (context, dayIndexNotifier, child) {
                                              final int dayIndex =
                                                  (dayIndexNotifier.value ?? 0);
                                              final int datetimeDelta =
                                                  (((dayIndex * 24 * 60)) *
                                                  60 *
                                                  1000);
                                              final tz.TZDateTime
                                              hoverDateTimeRaw =
                                                  tz.TZDateTime(
                                                    currentLocationNotifier
                                                        .value!
                                                        .timeZone,
                                                    currentLocationNotifier
                                                        .value!
                                                        .year,
                                                  ).add(
                                                    Duration(
                                                      milliseconds:
                                                          datetimeDelta,
                                                    ),
                                                  );
                                              return Text(
                                                DateFormat(
                                                  'd MMM yyyy',
                                                ).format(hoverDateTimeRaw),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleSmall,
                                              );
                                            },
                                      ),
                                      const AzimuthWidget(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
      },
    );
  }
}
