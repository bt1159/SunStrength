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

  void updateWithInitialSaved(CurrentChartSettings? savedChartSettings) {
    if (savedChartSettingsLoaded) return;
    print(
      'Before assignment: Equal? ${value == savedChartSettings} and value?.location.name: ${value?.location.name}, savedLocation?.name: ${savedChartSettings?.location.name}',
    );
    if (value != savedChartSettings) {
      value = savedChartSettings;
    }
    savedChartSettingsLoaded = true;
    print('CurrentLocationNotifier just updated from savedChartSettings');
  }

  void wipeSettings() {
    if (value == null) return;
    value = null;
  }

  void updateWithNewLocation({required Location newLocation}) {
    print(
      'Before assignment: Equal? ${value?.location == newLocation}, value?.location.name: ${value?.location.name}, newLocation?.name: ${newLocation?.name}',
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

  void updateWithNewLocationAndYear({required Location newLocation, required int newYear}) {
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
