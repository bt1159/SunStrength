import 'dart:convert';
// import 'dart:ffi';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

typedef LocationCallback = void Function({required Location location});

class Location {
  const Location({required this.name, required this.lat, required this.lon});
  Location.fromMap({required Map<String, dynamic> inputMap})
    : name = inputMap['name'],
      lat = inputMap['lat'],
      lon = inputMap['lon'];

  Location.fromLatLng({required LatLng latLng, required this.name})
    : lat = latLng.latitude,
      lon = latLng.longitude;

  final String name;
  final num lat;
  final num lon;

  LatLng get latLng => LatLng(lat.toDouble(), lon.toDouble());

  Map<String, dynamic> get toMap => {'name': name, 'lat': lat, 'lon': lon};
  Map<String, Object> get toObjMap => {'name': name, 'lat': lat, 'lon': lon};
  String get toJSONString => jsonEncode(toMap);

  @override
  String toString() => 'name: $name, lat: $lat, lon: $lon';

  @override
  bool operator ==(Object other) {
    // 1. Check for reference identity
    if (identical(this, other)) return true;

    // 2. Check type, runtimeType, and property values
    return other is Location &&
        other.runtimeType == runtimeType &&
        other.name == name &&
        other.lat == lat &&
        other.lon == lon;
  }

  @override
  int get hashCode => Object.hash(name, lat, lon);
}

class CurrentChartSettings {
  const CurrentChartSettings({
    required this.location,
    required this.year,
    required this.timeZone,
  });

  final Location location;
  final int year;
  final tz.Location timeZone;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurrentChartSettings &&
        other.location == location &&
        other.year == year &&
        other.timeZone == timeZone;
  }

  @override
  int get hashCode => Object.hash(location, year, timeZone);
}

/// This class is a container for all the settings that a user will store between app sessions.  Keep in mind
/// that these are not necessarily the same as what is displayed in the chart currently.
class SavedAppSettings {
  SavedAppSettings({
    this.defaultLocation,
    this.defaultTimeZone,
    bool? twelveHour,
    int? defaultYear,
  }) : defaultYear = defaultYear ?? tz.TZDateTime.now(tz.UTC).year,
       twelveHour = twelveHour ?? true;

  factory SavedAppSettings.fromSaved(SharedPreferences prefs) {
    Location? newDefaultLocation;
    tz.Location? newTZoneInput;
    bool twelveHour = true;
    int? newDefaultYear;

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
      tz.initializeTimeZones();
      final String newTZoneInputString =
          jsonDecode(savedTZJsonString) as String;
      try {
        newTZoneInput = tz.getLocation(newTZoneInputString);
      } catch (error) {
        print(error);
        newTZoneInput = null;
      }
    }

    // Parse out twelveHour
    final String? savedTwelveHourJsonString = prefs.getString('twelveHour');
    if (savedTwelveHourJsonString != null) {
      twelveHour = jsonDecode(savedTwelveHourJsonString) as bool;
    }

    // Parse out year
    final String? savedYearJsonString = prefs.getString('default_solar_year');
    if (savedYearJsonString != null) {
      newDefaultYear = int.tryParse(savedYearJsonString);
    }

    return SavedAppSettings(
      defaultLocation: newDefaultLocation,
      defaultTimeZone: newTZoneInput,
      twelveHour: twelveHour,
      defaultYear: newDefaultYear,
    );
  }

  final Location? defaultLocation;
  final tz.Location? defaultTimeZone;
  final bool twelveHour;
  final int? defaultYear;

  @override
  String toString() =>
      'SavedAppSettings, defaultLocation: $defaultLocation, tZoneInput: $defaultTimeZone, twelveHour: $twelveHour, year: $defaultYear';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SavedAppSettings &&
        other.runtimeType == runtimeType &&
        other.defaultLocation?.name == defaultLocation?.name &&
        other.defaultLocation?.lat == defaultLocation?.lat &&
        other.defaultLocation?.lon == defaultLocation?.lon &&
        other.defaultTimeZone == defaultTimeZone &&
        other.twelveHour == twelveHour &&
        other.defaultYear == defaultYear;
  }

  @override
  int get hashCode =>
      Object.hash(defaultLocation, defaultTimeZone, twelveHour, defaultYear);
}

typedef TimedOrbitData = Iterable<({double earthRotationAngle, double trueAnomaly})>;