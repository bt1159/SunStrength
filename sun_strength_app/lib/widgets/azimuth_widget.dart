import 'dart:core';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/chart_notifiers.dart';
// import 'package:sun_strength_app/widgets/birdseye_widget.dart';
import 'package:sun_strength_app/widgets/globe_widget.dart';

/// This widget contains the entire window that contains the azimuth chart.  It also therefore
/// constains the title, the buttons, etc.
class AzimuthChartWindow extends StatelessWidget {
  const AzimuthChartWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return CNP<AzChartSizeNotifier>(
      create: (context) => AzChartSizeNotifier(AzChartSize.large),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RowToColumnRenderWidget(
              key: ValueKey('Azimuth chart'),
              rowMainAxisAlignment: MainAxisAlignment.spaceBetween,
              rowCrossAxisAlignment: CrossAxisAlignment.center,
              columnCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sun strength and location on a single day',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                C<AzChartSizeNotifier>(
                  builder: (context, azChartSizeNotifier, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 4,
                      children: [
                        ElevatedButton(
                          onPressed:
                              azChartSizeNotifier.value == AzChartSize.small
                              ? null
                              : () {
                                  azChartSizeNotifier.value = AzChartSize.small;

                                  print(
                                    'changing C<AzChartSizeNotifier>, value: ${azChartSizeNotifier.value.name}',
                                  );
                                },
                          child: Text('S'),
                        ),
                        ElevatedButton(
                          onPressed:
                              azChartSizeNotifier.value == AzChartSize.medium
                              ? null
                              : () {
                                  azChartSizeNotifier.value =
                                      AzChartSize.medium;
                                  print(
                                    'changing C<AzChartSizeNotifier>, value: ${azChartSizeNotifier.value.name}',
                                  );
                                },
                          child: Text('M'),
                        ),
                        ElevatedButton(
                          onPressed:
                              azChartSizeNotifier.value == AzChartSize.large
                              ? null
                              : () {
                                  azChartSizeNotifier.value = AzChartSize.large;
                                  print(
                                    'changing C<AzChartSizeNotifier>, value: ${azChartSizeNotifier.value.name}',
                                  );
                                },
                          child: Text('L'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            Consumer<DayDataNot>(
              builder: (context, dayDataNotifier, _) {
                final tz.TZDateTime hoverDateTimeRaw =
                    dayDataNotifier.value[12 * 4].tzDateTime;
                return Text(
                  intl.DateFormat('d MMM yyyy').format(hoverDateTimeRaw),
                  style: Theme.of(context).textTheme.titleSmall,
                );
              },
            ),
            Container(
              alignment: Alignment.center,
              child: const GlobeVizHolder(),
              // const BirdsEyeWidget(),
            ),
          ],
        );
      },
    );
  }
}
