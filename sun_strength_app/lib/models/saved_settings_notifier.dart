import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sun_strength_app/models/helpers.dart';

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
        'In SavedSettingsNotifier._loadSettingsFromStorage, just set value to new value, value!.defaultLocation?.name ${value!.defaultLocation?.name} and value!.tZoneInput: ${value!.tZoneInput}',
      );
    } catch (e) {
      debugPrint("Error reading storage: $e");
      _isInitialized = true;
    }

    print('Finished SavedSettingsNotifier._loadSettingsFromStorage');
  }

  // Update location and/or timezone from the selection screen.  NOTE: a null passed for either input will NOT setting the setting to null.  Instead, it will skip that setting.
  Future<void> updateSettings(
    Location? newLocation,
    String? newTZString,
  ) async {
    if (newLocation == null && newTZString == null) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newLocation ?? value?.defaultLocation,
      tZoneInput: newTZString ?? value?.tZoneInput,
    );
    if (value == settings) return;
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (newLocation != null) {
      await prefs.setString('default_solar_location', newLocation.toJSONString);
    }
    if (newTZString != null) {
      await prefs.setString('default_solar_timezone', newTZString);
    }
  }

  // Clear location and timezone
  Future<void> clearSettings() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: null,
      tZoneInput: null,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_location');
    await prefs.remove('default_solar_timezone');
  }

  // Update location from the selection screen
  Future<void> updateLocation(Location newLocation) async {
    if (value?.defaultLocation == newLocation) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: newLocation,
      tZoneInput: value?.tZoneInput,
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_location', newLocation.toJSONString);
  }

  // Clear location
  Future<void> clearLocation() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: null,
      tZoneInput: value?.tZoneInput,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_location');
  }

  // Update timezone from the selection screen
  Future<void> updateTZ(String newTZString) async {
    if (value?.tZoneInput == newTZString) return;
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      tZoneInput: newTZString,
    );
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_timezone', newTZString);
  }

  // Clear timezone
  Future<void> clearTZ() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      tZoneInput: null,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_timezone');
  }

  // Update location from the selection screen
  Future<void> updateTwelveHour(bool twelveHour) async {
    print('running updateTwelveHour with twelveHour: $twelveHour');
    if (value?.twelveHour == twelveHour) {
      print('inside updateTwelveHour, about to return because new value matches previous value');
      return;
    }
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      tZoneInput: value?.tZoneInput,
      twelveHour: twelveHour,
    );
    print('inside updateTwelveHour, previous value?.twelveHour: ${value?.twelveHour}, new settings: $settings');
    value = settings;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('twelveHour', twelveHour.toString());
  }

  // Clear location
  Future<void> clearTwelveHour() async {
    final SavedAppSettings settings = SavedAppSettings(
      defaultLocation: value?.defaultLocation,
      tZoneInput: value?.tZoneInput,
    );
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('twelveHour');
  }

  @override
  notifyListeners() {
    print('running SavedSettingsNotifier.notifyListeners()');
    super.notifyListeners();
  }
}

class SavedAppSettings {
  SavedAppSettings({
    this.defaultLocation,
    this.tZoneInput,
    this.twelveHour = true,
  });

  factory SavedAppSettings.fromSaved(SharedPreferences prefs) {
    Location? newDefaultLocation;
    String? newTZoneInput;
    bool twelveHour = true;

    // Parse out location
    final String? savedLocJsonString = prefs.getString(
      'default_solar_location',
    );
    if (savedLocJsonString != null) {
      final Map<String, dynamic> savedLocJson =
          jsonDecode(savedLocJsonString) as Map<String, dynamic>;
      newDefaultLocation = Location.fromMap(inputMap: savedLocJson);
    }

    // Parse out time zone
    final String? savedTZJsonString = prefs.getString('default_solar_timezone');
    if (savedTZJsonString != null) {
      newTZoneInput = jsonDecode(savedTZJsonString) as String;
    }

    // Parse out twelveHour
    final String? savedTwelveHourJsonString = prefs.getString('twelveHour');
    if (savedTwelveHourJsonString != null) {
      twelveHour = jsonDecode(savedTwelveHourJsonString) as bool;
    }

    return SavedAppSettings(
      defaultLocation: newDefaultLocation,
      tZoneInput: newTZoneInput,
      twelveHour: twelveHour,
    );
  }

  final Location? defaultLocation;
  final String? tZoneInput;
  final bool twelveHour;

  @override
  String toString() => 'SavedAppSettings, defaultLocation: $defaultLocation, tZoneInput: $tZoneInput, twelveHour: $twelveHour';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SavedAppSettings &&
        other.runtimeType == runtimeType &&
        other.defaultLocation?.name == defaultLocation?.name &&
        other.defaultLocation?.lat == defaultLocation?.lat &&
        other.defaultLocation?.lon == defaultLocation?.lon &&
        other.tZoneInput == tZoneInput &&
        other.twelveHour == twelveHour;
  }

  @override
  int get hashCode => Object.hash(defaultLocation, tZoneInput, twelveHour);
}
