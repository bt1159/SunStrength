import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sun_strength_app/models/helpers.dart';

class SavedLocationProvider extends ValueNotifier<Location?> {
  // Initialize with null, meaning "we don't know the state yet"
  SavedLocationProvider() : super(null) {
    print('Starting SavedLocationProvider constructor');
    _loadLocationFromStorage();
    print('finished SavedLocationProvider constructor');
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Load from localStorage on boot
  Future<void> _loadLocationFromStorage() async {
    print('Starting SavedLocationProvider._loadLocationFromStorage');
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedJson = prefs.getString('default_solar_location');

      if (savedJson != null) {
        final Map<String, dynamic> valueJSON =
            jsonDecode(savedJson) as Map<String, dynamic>;
        value = Location.fromMap(inputMap: valueJSON);

        print(
          'In SavedLocationProvider._loadLocationFromStorage, just set value to new value, value?.name ${value?.name}',
        );
      }
    } catch (e) {
      debugPrint("Error reading storage: $e");
    } finally {
      _isInitialized = true;
      notifyListeners(); // Alert the UI that initialization is complete
      print(
        'In SavedLocationProvider._loadLocationFromStorage, just finished the finally statement and called NotifyListeners, potentially as a duplicate',
      );
      
    }

    print('Starting SavedLocationProvider._loadLocationFromStorage');
  }

  // Update location from the selection screen
  Future<void> updateLocation(Location newLocation) async {
    value = newLocation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_solar_location', newLocation.toJSONString);
  }

  // Clear location (if they want to reset defaults)
  Future<void> clearLocation() async {
    value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_solar_location');
  }
}
