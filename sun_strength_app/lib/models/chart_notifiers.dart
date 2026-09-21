import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/timezone.dart' as tz;

class DayDataNot extends ValueNotifier<List<OrbSolValues>> {
  DayDataNot(super.value);

  /// This function will get added to a
  /// [CNPP<OrbitAndSolarValuesListNotifier,DayDataNotifier>]
  /// as its update method.  That means that the purpose of this function is to update
  /// the [DayDataNot] specifically when the [OrbSolValuesListNot] value
  /// is updated.  This method will therefore NOT be used when just the date is updated.
  static DayDataNot cNPPUpdateFunction(
    BuildContext context,
    OrbSolValuesListNot orbitAndSolarValuesListNotifier,
    DayDataNot? oldDayDataNotifier,
  ) {
    if (oldDayDataNotifier == null) {
      // Throw error if previous the previous notifier itself is null (i.e, not the value but the notifier itself)
      throw 'null previous in ProxyProvider';
    } else {
      final tz.TZDateTime newDataJanFirstTZDT =
          orbitAndSolarValuesListNotifier.value.first.tzDateTime;
      int oldMonth;
      int oldDay;
      if (oldDayDataNotifier.value.isEmpty) {
        // if updating for the first time, value is an empty list
        oldMonth = DateTime.now().month;
        oldDay = DateTime.now().day;
      } else {
        // Replace the old day's data with the new data from the same month & day of the new data's year
        final tz.TZDateTime oldTZDT = oldDayDataNotifier.value.first.tzDateTime;
        oldMonth = oldTZDT.month;
        oldDay = oldTZDT.day;
      }
      // Correct day if currently on Feb 29 in a leap year and moving to a non-leap year.
      if (!isLeapYear(newDataJanFirstTZDT.year) &&
          oldMonth == 2 &&
          oldDay == 29) {
        oldDay = 28;
      }
      final DateTime oldUTCDTInNewYear = DateTime.utc(
        newDataJanFirstTZDT.year,
        oldMonth,
        oldDay,
      );
      final DateTime newDataJanFirstUTCDT = DateTime.utc(
        newDataJanFirstTZDT.year,
        newDataJanFirstTZDT.month,
        newDataJanFirstTZDT.day,
      );
      final int dayIndex = oldUTCDTInNewYear
          .difference(newDataJanFirstUTCDT)
          .inDays;
      return oldDayDataNotifier
        ..value = orbitAndSolarValuesListNotifier.value.sublist(
          96 * dayIndex,
          96 * (dayIndex + 1),
        );
    }
  }
}

class KNot extends ValueNotifier<double> {
  KNot([super.value = 2]);
}
