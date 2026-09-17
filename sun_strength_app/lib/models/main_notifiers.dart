import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;

class CurrentChartSettingsNotifier
    extends ValueNotifier<CurrentChartSettings?> {
  CurrentChartSettingsNotifier() : super(null) {
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
        'inside CurrentLocationNotifier.getTZFromLocation, lat and lon have yielded a valid tz, output.name: ${output.name}',
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

      print(
        'CurrentLocationNotifier just updated via updateCurrentChartSettings',
      );
    }
  }
}

/// This Notifier is a bit different from typical.  It is NOT ALWAYS intended to trigger rebuilds for all updates.  It depends on multiple
/// logic steps.  For instance, [_loadSettingsFromStorage] will always call [notifyListeners].  The [CurrentLocationNotifier], for instance
/// needs to reuild when the default settings are initially loaded.  Even after that, when the twelveHour setting is updated, this notifier
/// is where the current AND the default setting is saved.  So, any widgets that display time should update when the twelveHour bool is
/// changed.  The default location, however, should NOT trigger rebuilds when it is changed by itself.  In other words, when it is updated
/// as part of the initial load, then yes it should trigger CurrentLocationNotifier to update. After that, however, when the user selects a
/// new default location, I don't want anything to update.  Rather than being handled here in the update functions, all updates call
/// [notifyListeners].  Instead, the widget tree itself should use context.read, Selector, or other methods to control exactly when its
/// rebuild is triggered by this notifier.
class SavedSettingsNotifier extends ValueNotifier<SavedAppSettings?> {
  // Initialize with null, meaning "we don't know the state yet"
  SavedSettingsNotifier() : super(null) {
    print('Starting SavedSettingsNotifier constructor');
    _loadSettingsFromStorage();
    print('finished SavedSettingsNotifier constructor');
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Load from localStorage on boot
  // CALLS NOTIFYLISTENERS
  Future<void> _loadSettingsFromStorage() async {
    print('Starting SavedSettingsNotifier._loadSettingsFromStorage');
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      value = SavedAppSettings.fromSaved(prefs);
      print(
        'In SavedSettingsNotifier._loadSettingsFromStorage, just set value to new value, value: $value',
      );
    } catch (e) {
      debugPrint("Error reading storage: $e");
      _isInitialized = true;
    }

    print('Finished SavedSettingsNotifier._loadSettingsFromStorage');
  }

  /// Update location and/or timezone from the selection screen.  NOTE: a null passed for either input will NOT setting the setting to null.
  // Instead, it will skip that setting.
  // CALLS NOTIFYLISTENERS
  Future<void> updateSettings(
    Location? newDefaultLocation,
    bool? newTwelveHour,
    int? newDefaultYear,
    MyColorScheme? newColorScheme,
  ) async {
    if (newDefaultLocation == null &&
        newTwelveHour == null &&
        newDefaultYear == null &&
        newColorScheme == null) {
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newDefaultLocation ?? value?.defaultLocation,
      defaultYear: newDefaultYear ?? value?.defaultYear,
      twelveHour: newTwelveHour ?? value?.twelveHour,
      colorScheme: newColorScheme ?? value?.colorScheme,
    );
    if (value == settings) return;
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (newDefaultLocation != null) {
      await prefs.setString(
        'default_solar_location',
        newDefaultLocation.toJSONString,
      );
    }
    if (newDefaultYear != null) {
      await prefs.setString('default_solar_year', newDefaultYear.toString());
    }
    if (newTwelveHour != null) {
      await prefs.setString('twelveHour', newTwelveHour.toString());
    }
    if (newColorScheme != null) {
      await prefs.setString('colorScheme', newColorScheme.$1);
    }
    print('just finished saving new settings: value: $value');
  }

  /// Clear all settings from memory
  Future<void> clearSettings() async {
    final SavedAppSettings settings = SavedAppSettings(defaultLocation: null);
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_location');
    await prefs.remove('default_solar_timezone');
    await prefs.remove('twelveHour');
    await prefs.remove('default_solar_year');
    await prefs.remove('colorScheme');
    print('just finished clearing saved settings, value: $value');
  }

  /// Update location from the selection screen
  Future<void> updateLocation(Location newLocation) async {
    if (value?.defaultLocation == newLocation) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newLocation,
      defaultYear: value?.defaultYear,
      twelveHour: value?.twelveHour,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_location', newLocation.toJSONString);
  }

  /// Clear location
  Future<void> clearLocation() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: null,
      defaultYear: value?.defaultYear,
      twelveHour: value?.twelveHour,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_location');
  }

  /// Update twelveHour from the selection screen
  Future<void> updateTwelveHour(bool twelveHour) async {
    print('running updateTwelveHour with twelveHour: $twelveHour');
    if (value?.twelveHour == twelveHour) {
      print(
        'inside updateTwelveHour, about to return because new value matches previous value',
      );
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      twelveHour: twelveHour,
      defaultYear: value?.defaultYear,
      colorScheme: value?.colorScheme,
    );
    print(
      'inside updateTwelveHour, previous value?.twelveHour: ${value?.twelveHour}, new settings: $settings',
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('twelveHour', twelveHour.toString());
  }

  /// Clear twelveHour
  Future<void> clearTwelveHour() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultYear: value?.defaultYear,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('twelveHour');
  }

  /// Update year from the selection screen
  Future<void> updateYear(int newYear) async {
    print('running updateYear with newYear: $newYear');
    if (value?.defaultYear == newYear) {
      print(
        'inside updateYear, about to return because new value matches previous value',
      );
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      twelveHour: value?.twelveHour,
      defaultYear: newYear,
      colorScheme: value?.colorScheme,
    );
    print(
      'inside updateTwelveHour, previous value?.twelveHour: ${value?.twelveHour}, new settings: $settings',
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_year', newYear.toString());
  }

  /// Clear year
  Future<void> clearYear() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      twelveHour: value?.twelveHour,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_year');
  }

  Future<void> updateColorScheme(MyColorScheme newColorScheme) async {
    print('running updateColorScheme with newYear: $newColorScheme');
    if (value?.colorScheme == newColorScheme) {
      print(
        'inside updateColorScheme, about to return because new value matches previous value',
      );
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      twelveHour: value?.twelveHour,
      defaultYear: value?.defaultYear,
      colorScheme: newColorScheme,
    );
    print(
      'inside updateColorScheme, previous value?.colorScheme.\$1: ${value?.colorScheme.$1}, new settings: $settings',
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorScheme', newColorScheme.$1);
  }

  Future<void> clearColorScheme() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      twelveHour: value?.twelveHour,
      defaultYear: value?.defaultYear,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('colorScheme');
  }

  @override
  notifyListeners() {
    print('running SavedSettingsNotifier.notifyListeners()');
    super.notifyListeners();
  }
}

// class PageIndexNotifier extends ValueNotifier<int> {
//   PageIndexNotifier() : super(0);

//   bool savedSettingsIsInitialized = false;

//   @override
//   set value(int newValue) => super.value = newValue.clamp(0, 1);
// }
