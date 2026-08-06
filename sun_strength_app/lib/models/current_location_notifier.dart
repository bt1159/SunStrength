import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;

class CurrentLocationNotifier extends ValueNotifier<CurrentChartSettings?> {
  CurrentLocationNotifier() : super(null) {
    print(
      'running CurrentLocationNotifier constructor, with value?.location.name: ${value?.location.name}, value?.year: ${value?.year}, value?.timeZone.name: ${value?.timeZone.name}',
    );
  }

  tz.Location getTZFromLocation(Location location) {
    tz.initializeTimeZones();
    tz.Location output;

    final String timeZoneName = tzmap.latLngToTimezoneString(
      location.lat,
      location.lon,
    );
    try {
      output = tz.getLocation(timeZoneName);
      print(
        'inside CurrentLocationNotifier.getTZFromLocation, trying to see if lat and lon result in valid tz',
      );
    } catch (error) {
      print(error);
      output = tz.getLocation("America/New_York");
    }
    return output;
  }

  bool savedChartSettingsLoaded = false;

  /// Method that updates the current chart settings when the saved settings are first loaded.  After the initial load, any time after that the saved settings are updated
  /// gets ignored.
  ///
  /// Note: the current location is updated to the saved default location, as is the year.  The chart route, however, will have the ability to quickly
  /// toggle these back.  This entire updating structure is designed with the intent that the chart is not actually displayed until the saved settings are accessed.
  void updateWithInitialSaved({Location? newLocation, int? newYear}) {
    if (savedChartSettingsLoaded) return;
    if (newLocation == null) {
      value == null;
    } else {
      final newTZ = getTZFromLocation(newLocation);
      newYear ??= tz.TZDateTime.now(tz.UTC).year;
      final newValue = CurrentChartSettings(
        location: newLocation,
        year: newYear,
        timeZone: newTZ,
      );
      value = newValue;
    }
    savedChartSettingsLoaded = true;
    print('CurrentLocationNotifier just updated from savedChartSettings');
  }

  void updateCurrentChartSettings({
    Location? newLocation,
    int? newYear,
    tz.Location? newTimeZone,
  }) {
    if (newLocation == null && newYear == null && newTimeZone == null) {
      // If all inputs are null, do nothing.  This should not actually happen.
      return;
    } else if (newLocation == value?.location &&
        newYear == value?.year &&
        newTimeZone == value?.timeZone) {
      // This is the escape meaning that no change is actually needed
      return;
    } else {
      if (newLocation != null) {
        newTimeZone ??= getTZFromLocation(newLocation);
      } else {
        newTimeZone ??= value?.timeZone;
      }

      newLocation ??= value?.location;
      newYear ??= value?.year ?? tz.TZDateTime.now(tz.UTC).year;
      
      final CurrentChartSettings newSettings = CurrentChartSettings(
        location: newLocation!,
        year: newYear,
        timeZone: newTimeZone!,
      );
      value = newSettings;

      print('CurrentLocationNotifier just updated via updateCurrentChartSettings');
    }
  }
}
