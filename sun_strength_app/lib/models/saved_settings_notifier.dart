import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/timezone.dart' as tz;

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

  // Load from localStorage on boot
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

  // Update location and/or timezone from the selection screen.  NOTE: a null passed for either input will NOT setting the setting to null.
  // Instead, it will skip that setting.
  // CALLS NOTIFYLISTENERS
  Future<void> updateSettings(
    Location? newDefaultLocation,
    tz.Location? newDefaultTimeZone,
    bool? newTwelveHour,
    int? newDefaultYear,
    MyColorScheme? newColorScheme,
  ) async {
    if (newDefaultLocation == null && newDefaultTimeZone == null && newTwelveHour == null && newDefaultYear == null && newColorScheme == null) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newDefaultLocation ?? value?.defaultLocation,
      defaultTimeZone: newDefaultTimeZone ?? value?.defaultTimeZone,
      defaultYear: newDefaultYear ?? value?.defaultYear,
      twelveHour: newTwelveHour ?? value?.twelveHour,
      colorScheme: newColorScheme ?? value?.colorScheme,
    );
    if (value == settings) return;
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (newDefaultLocation != null) {
      await prefs.setString('default_solar_location', newDefaultLocation.toJSONString);
    }
    if (newDefaultTimeZone != null) {
      await prefs.setString('default_solar_timezone', newDefaultTimeZone.name);
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

  // Clear location and timezone
  Future<void> clearSettings() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: null,
      defaultTimeZone: null,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_location');
    await prefs.remove('default_solar_timezone');
    await prefs.remove('twelveHour');
    await prefs.remove('default_solar_year');
    await prefs.remove('colorScheme');
    print('just finished clearing saved settings, value: $value');
  }

  // Update location from the selection screen
  Future<void> updateLocation(Location newLocation) async {
    if (value?.defaultLocation == newLocation) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newLocation,
      defaultTimeZone: value?.defaultTimeZone,
      defaultYear: value?.defaultYear,
      twelveHour: value?.twelveHour,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_location', newLocation.toJSONString);
  }

  // Clear location
  Future<void> clearLocation() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: null,
      defaultTimeZone: value?.defaultTimeZone,
      defaultYear: value?.defaultYear,
      twelveHour: value?.twelveHour,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_location');
  }

  // Update timezone from the selection screen
  Future<void> updateTZ(tz.Location newTimeZone) async {
    if (value?.defaultTimeZone == newTimeZone) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: newTimeZone,
      defaultYear: value?.defaultYear,
      twelveHour: value?.twelveHour,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_timezone', newTimeZone.name);
  }

  // Clear timezone
  Future<void> clearTZ() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: null,
      defaultYear: value?.defaultYear,
      twelveHour: value?.twelveHour,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_timezone');
  }

  // Update twelveHour from the selection screen
  Future<void> updateTwelveHour(bool twelveHour) async {
    print('running updateTwelveHour with twelveHour: $twelveHour');
    if (value?.twelveHour == twelveHour) {
      print('inside updateTwelveHour, about to return because new value matches previous value');
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: value?.defaultTimeZone,
      twelveHour: twelveHour,
      defaultYear: value?.defaultYear,
      colorScheme: value?.colorScheme,
    );
    print('inside updateTwelveHour, previous value?.twelveHour: ${value?.twelveHour}, new settings: $settings');
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('twelveHour', twelveHour.toString());
  }

  // Clear twelveHour
  Future<void> clearTwelveHour() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: value?.defaultTimeZone,
      defaultYear: value?.defaultYear,
      colorScheme: value?.colorScheme,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('twelveHour');
  }

  // Update year from the selection screen
  Future<void> updateYear(int newYear) async {
    print('running updateYear with newYear: $newYear');
    if (value?.defaultYear == newYear) {
      print('inside updateYear, about to return because new value matches previous value');
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: value?.defaultTimeZone,
      twelveHour: value?.twelveHour,
      defaultYear: newYear,
      colorScheme: value?.colorScheme,
    );
    print('inside updateTwelveHour, previous value?.twelveHour: ${value?.twelveHour}, new settings: $settings');
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_year',newYear.toString());
  }

  // Clear year
  Future<void> clearYear() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: value?.defaultTimeZone,
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
      print('inside updateColorScheme, about to return because new value matches previous value');
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: value?.defaultTimeZone,
      twelveHour: value?.twelveHour,
      defaultYear: value?.defaultYear,
      colorScheme: newColorScheme,
    );
    print('inside updateColorScheme, previous value?.colorScheme.\$1: ${value?.colorScheme.$1}, new settings: $settings');
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorScheme', newColorScheme.$1);

  }

    Future<void> clearColorScheme() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      defaultTimeZone: value?.defaultTimeZone,
      twelveHour: value?.twelveHour,
      defaultYear: value?.defaultYear,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('colorScheme');}

  @override
  notifyListeners() {
    print('running SavedSettingsNotifier.notifyListeners()');
    super.notifyListeners();
  }
}
