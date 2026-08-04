// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/timezone.dart' as tz;

/// This Notifier is a bit different from typical.  It is NOT intended to alert the widget
/// tree when the current value of a parameter has been updated.  It does indeed keep the
/// current value, but when the current value is changed, it DOES NOT call notifyListeners().
/// Instead, notifyListeners() is ONLY CALLED when SharedPreferences.getInstance() is loaded
/// and the saved values are retreived.  From that point on, when any settings like default
/// location are updated, this Notifier handles the process of updating the saved
/// SharedPreferences.  It just doesn't call notifyListeners() when it does it.  That is
/// mainly because any time the current value of saved location is changed, the widget tree
/// doesn't actually need to know.  Anything needing that value can just look it up when
/// needed.
// TODO: I wrote the above because of the note on AppGateway, but since this is a ValueNotifier,
// it WILL actually call notifyListeners() when a setting is cleared or overwritten.  Should I
// change this?
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
  Future<void> _loadSettingsFromStorage() async {
    print('Starting SavedSettingsNotifier._loadSettingsFromStorage');
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      value = SavedAppSettings.fromSaved(prefs);
      print(
        'In SavedSettingsNotifier._loadSettingsFromStorage, just set value to new value, value!.defaultLocation?.name ${value!.defaultLocation?.name} and value!.tZoneInput: ${value!.defaultTimeZone}',
      );
    } catch (e) {
      debugPrint("Error reading storage: $e");
      _isInitialized = true;
    }

    print('Finished SavedSettingsNotifier._loadSettingsFromStorage');
  }

  // Update location and/or timezone from the selection screen.  NOTE: a null passed for either input will NOT setting the setting to null.  Instead, it will skip that setting.
  Future<void> updateSettings(
    Location? newDefaultLocation,
    tz.Location? newDefaultTimeZone,
    bool? newTwelveHour,
    int? newDefaultYear,
  ) async {
    if (newDefaultLocation == null && newDefaultTimeZone == null && newTwelveHour == null && newDefaultYear == null) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newDefaultLocation ?? value?.defaultLocation,
      defaultTimeZone: newDefaultTimeZone ?? value?.defaultTimeZone,
      defaultYear: newDefaultYear ?? value?.defaultYear,
      twelveHour: newTwelveHour ?? value?.twelveHour,
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
  }

  // Update location from the selection screen
  Future<void> updateLocation(Location newLocation) async {
    if (value?.defaultLocation == newLocation) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newLocation,
      defaultTimeZone: value?.defaultTimeZone,
      defaultYear: value?.defaultYear,
      twelveHour: value?.twelveHour,
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
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_year');
  }

  @override
  notifyListeners() {
    print('running SavedSettingsNotifier.notifyListeners()');
    super.notifyListeners();
  }
}
