import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/chart_notifiers.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/main_notifiers.dart';
import 'package:sun_strength_app/screens/location_selection_route.dart';
import 'package:sun_strength_app/widgets/chart_widget.dart';
import 'package:sun_strength_app/widgets/color_scale_widget.dart';

class YearlyChart extends StatelessWidget {
  const YearlyChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      children: [
        Center(child: const ChartWidget(nXAxisBuckets: 12, nYAxisBuckets: 6)),
        const ColorScaleWidget(),
        const KButtonRow(),
        const LocationButtonRow(),
        const DropdownColorschemeButton(),
      ],
    );
  }
}

class DropdownColorschemeButton extends StatelessWidget {
  const DropdownColorschemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        print(
          'inside DropDownColorschemeButton.build, constraints: $constraints',
        );
        return Padding(
          padding: const EdgeInsets.all(kButtonTapTargetPadding),
          child: Selector<SavedSettingsNot, MyColorScheme?>(
            selector: (_, savedSettingsNotifier) =>
                savedSettingsNotifier.value?.colorScheme,
            builder: (context, colorScheme, child) =>
                DropdownMenu<MyColorScheme>(
                  initialSelection: colorScheme,
                  label: const Text('Select Color Scheme'),
                  onSelected: (MyColorScheme? value) {
                    if (value == null) {
                      context.read<SavedSettingsNot>().clearColorScheme();
                    } else {
                      context.read<SavedSettingsNot>().updateColorScheme(value);
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
      },
    );
  }
}

class KButtonRow extends StatelessWidget {
  const KButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        print('inside KButtonRow.build, constraints: $constraints');
        return Consumer<KNot>(
          builder: (context, kNotifer, child) {
            print('Building k button row, k: ${kNotifer.value}');
            return Row(
              spacing: 20,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    print(
                      'inside KButtonRow.build, constraints given to first Row child: $constraints',
                    );
                    return ElevatedButton(
                      onPressed: kNotifer.value == 0.3
                          ? null
                          : () {
                              print(
                                'current k: ${kNotifer.value}, about to change it to 0.3',
                              );
                              kNotifer.value = 0.3;
                            },
                      child: Text('Visible light'),
                    );
                  },
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
      },
    );
  }
}

class LocationButtonRow extends StatelessWidget {
  const LocationButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        print('inside LocationButtonRow.build, constraints: $constraints');
        return Consumer<ChartSettingsNot>(
          builder: (context, currentChartSettingsNotifier, child) {
            return RowToColumnRenderWidget(
              rowMainAxisSize: MainAxisSize.min,
              rowSpacing: 20,
              rowCrossAxisAlignment: CrossAxisAlignment.start,
              columnMainAxisSize: MainAxisSize.min,
              columnCrossAxisAlignment: CrossAxisAlignment.center,
              columnSpacing: 5,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    print(
                      'inside LocationButtonRow.build, constraints given to first row child: $constraints',
                    );
                    return ElevatedButton(
                      onPressed:
                          (context
                                      .read<SavedSettingsNot>()
                                      .value
                                      ?.defaultLocation ==
                                  currentChartSettingsNotifier
                                      .value
                                      ?.location ||
                              currentChartSettingsNotifier.value?.location ==
                                  null)
                          ? null
                          : () async {
                              await context
                                  .read<SavedSettingsNot>()
                                  .updateLocation(
                                    currentChartSettingsNotifier
                                        .value!
                                        .location,
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
                    );
                  },
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
      },
    );
  }
}
