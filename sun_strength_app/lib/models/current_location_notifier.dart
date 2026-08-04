import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;

// TODO: I think I will need to add a way to update the location without updating the timezone to the new local.

// TODO: I need a better way to handle when one is null and the other is not in saved settings.
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
  /// Note: the current location is updated to the saved default location, as is the year and the timezone.  The chart route, however, will have the ability to quickly
  /// toggle these back.  This entire updating structure is designed with the intent that the chart is not actually displayed until the saved settings are accessed.
  void updateWithInitialSaved({Location? newLocation, int? newYear}) {
    if (savedChartSettingsLoaded) return;
    if (newLocation == null && newYear == null) {
      wipeSettings();
    } else if (newLocation == null) {
      updateWithNewYear(newYear: newYear!);
    } else if (newYear == null) {
      updateWithNewLocationLocalTZ(newLocation: newLocation);
    } else {
      updateWithNewLocationLocalTZAndYear(
        newLocation: newLocation,
        newYear: newYear,
      );
    }
    savedChartSettingsLoaded = true;
    print('CurrentLocationNotifier just updated from savedChartSettings');
  }

  void wipeSettings() {
    if (value == null) return;
    value = null;
  }

  void updateWithNewLocationLocalTZ({required Location newLocation}) {
    print(
      'Before assignment: Equal? ${value?.location == newLocation}, value?.location.name: ${value?.location.name}, newLocation?.name: ${newLocation.name}',
    );
    if (newLocation == value?.location) {
      return;
    } // If this is true, it won't rebuild!
    if (value == null) {
      print(
        'tried to update a non-null current location with a non-null location, but current year is still null.  Location will not be updated',
      );
      return;
    } else {
      final CurrentChartSettings newSettings = CurrentChartSettings(
        location: newLocation,
        year: value!.year,
        timeZone: getTZFromLocation(newLocation),
      );
      value = newSettings;
    }

    print('CurrentLocationNotifier just updated from new Location?');
  }

  void updateWithNewLocationLocalTZAndYear({
    required Location newLocation,
    required int newYear,
  }) {
    print(
      'Before assignment: Equal? ${value?.location == newLocation}, value?.location.name: ${value?.location.name}, newLocation?.name: ${newLocation.name}, value?.year: ${value?.year}, newYear: $newYear',
    );
    if (newLocation == value?.location && newYear == value?.year) {
      return;
    } // If this is true, it won't rebuild!

    final CurrentChartSettings newSettings = CurrentChartSettings(
      location: newLocation,
      year: newYear,
      timeZone: getTZFromLocation(newLocation),
    );
    value = newSettings;

    print('CurrentLocationNotifier just updated from new Location?');
  }

  void updateWithNewYear({required int newYear}) {
    print(
      'Before assignment: Equal? ${value?.year == newYear}, value?.year: ${value?.year}, newYear: $newYear',
    );
    if (newYear == value?.year) {
      return;
    } // If this is true, it won't rebuild!
    if (value == null) {
      print(
        'tried to update a non-null current year with a non-null year, but current location is still null.  Year will not be updated',
      );
      return;
    } else {
      final CurrentChartSettings newSettings = CurrentChartSettings(
        location: value!.location,
        year: newYear,
        timeZone: value!.timeZone,
      );
      value = newSettings;
    }

    print('CurrentLocationNotifier just updated from new Location?');
  }
}
