import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/timezone.dart' as tz;

class DayDataNotifier extends ValueNotifier<List<OrbitAndSolarValues>?> {
  DayDataNotifier(super.value);

  /// This function will get added to a
  /// [ChangeNotifierProxyProvider<OrbitAndSolarValuesListNotifier,DayDataNotifier>]
  /// as its update method.  That means that the purpose of this function is to update
  /// the [DayDataNotifier] specifically when the [OrbitAndSolarValuesListNotifier] value
  /// is updated.  This method will therefore NOT be used when just the date is updated.
  static DayDataNotifier changeNotifierProxyProviderUpdateFunction(
    BuildContext context,
    OrbitAndSolarValuesListNotifier orbitAndSolarValuesListNotifier,
    DayDataNotifier? oldDayDataNotifier,
  ) {
    if (oldDayDataNotifier == null) {
      // Throw error if previous the previous notifier itself is null (i.e, not the value but the notifier itself)
      throw 'null previous in ProxyProvider';
    } else if (oldDayDataNotifier.value == null) {
      // If there was no date selected, continue to keep this blank
      return oldDayDataNotifier;
    } else {
      // Replace the old day's data with the new data from the same day of the year (using the current and possibly updated year).
      final tz.TZDateTime oldTZDateTime =
          oldDayDataNotifier.value!.first.tzDateTime;
      final tz.TZDateTime newTZDateTime =
          orbitAndSolarValuesListNotifier.value.first.tzDateTime;
      final DateTime oldDate = DateTime.utc(
        newTZDateTime.year,
        oldTZDateTime.month,
        oldTZDateTime.day,
      );
      final DateTime newDate = DateTime.utc(
        newTZDateTime.year,
        newTZDateTime.month,
        newTZDateTime.day,
      );
      final int dayIndex = oldDate.difference(newDate).inDays;
      return oldDayDataNotifier
        ..value = orbitAndSolarValuesListNotifier.value.sublist(
          96 * dayIndex,
          96 * (dayIndex + 1),
        );
    }
  }
}

class KNotifier extends ValueNotifier<double> {
  KNotifier([super.value = 2]);
}
