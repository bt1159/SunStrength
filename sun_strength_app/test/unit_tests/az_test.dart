import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

// ==========================================
// MANDATORY ASTRONOMICAL CONSTANTS
// ==========================================

/// Mean anomaly of the Sun at J2000 epoch [radians].
/// Standard value is 357.529 degrees.
const double meanAnomalyJ2000 = 6.240059967;

/// Earth Rotation Angle at J2000 epoch [radians].
/// Calculated based on Greenwich Sidereal Time at J2000.
const double earthRotationAngleJ2000 = 4.894961213;

/// Hours per 1 complete orbit of the Sun (Tropical Year in hours).
/// 365.24219 days * 24 hours/day.
const double hoursPerOrbit = 8765.81256;

/// Radius of Earth's orbit at perihelion [km].
const double earthOrbitPerihelionKm = 147095000.0;

/// Radius of Earth's orbit at aphelion [km].
const double earthOrbitAphelionKm = 152100000.0;

/// Average radius of Earth (distance from center to surface) [km].
const double averageEarthRadiusKm = 6371.0084;

// ==========================================
// ADDITIONAL DERIVED TRACING CONSTANTS
// ==========================================

/// Mean anomaly progression rate per hour [radians/hour].
const double meanAnomalyRatePerHour = (2 * pi) / hoursPerOrbit;

/// Earth's axial tilt / obliquity of the ecliptic [radians].
/// Standard reference is 23.439 degrees.
const double obliquityOfEcliptic = 0.4090928;

/// Mean longitude of the Sun at J2000 epoch [radians].
/// Standard reference is 280.460 degrees.
const double meanLongitudeJ2000 = 4.89495042;

/// Mean motion of the Sun's longitude per hour [radians/hour].
const double meanLongitudeRatePerHour = (2 * pi) / hoursPerOrbit;

/// Earth rotation speed relative to stars/Sun per hour [radians/hour].
/// Evaluated as 15 degrees per hour in radians.
const double earthRotationRatePerHour = 0.2617993878;

// ==========================================
// CORE SOLAR AZIMUTH FUNCTION
// ==========================================

/// Calculates the solar azimuth angle in degrees relative to True North (0°).
///
/// Inputs:
/// - [hoursSinceJ2000]: Hours elapsed since Jan 1, 2000, 12:00 TT.
/// - [longitudeRad]: Longitude of observer in radians (East positive, West negative).
/// - [latitudeRad]: Latitude of observer in radians (North positive, South negative).
///
/// Output:
/// - Returns a double value between 0.0 and 360.0 degrees clockwise from North.
double calculateSolarAzimuth({
  required double hoursSinceJ2000,
  required double longitudeRad,
  required double latitudeRad,
}) {
  // 1. Calculate the Sun's Mean Anomaly
  final double meanAnomaly =
      meanAnomalyJ2000 + (meanAnomalyRatePerHour * hoursSinceJ2000);

  // 2. Calculate Ecliptic Longitude via Equation of Center approximation
  // Coefficients 0.033416 (1.915°) and 0.000349 (0.020°)
  final double meanLongitude =
      meanLongitudeJ2000 + (meanLongitudeRatePerHour * hoursSinceJ2000);
  final double eclipticLongitude =
      meanLongitude +
      (0.033416 * sin(meanAnomaly)) +
      (0.000349 * sin(2 * meanAnomaly));

  // 3. Compute Right Ascension (RA) and Declination (δ)
  final double numRA = cos(obliquityOfEcliptic) * sin(eclipticLongitude);
  final double denRA = cos(eclipticLongitude);
  double rightAscension = atan2(numRA, denRA);
  if (rightAscension < 0) {
    rightAscension += 2 * pi;
  }

  final double declination = asin(
    sin(obliquityOfEcliptic) * sin(eclipticLongitude),
  );

  // 4. Calculate Greenwich Mean Sidereal Time (GMST) / Hour Angle
  final double greenwichSiderealTime =
      earthRotationAngleJ2000 + (earthRotationRatePerHour * hoursSinceJ2000);

  final double localSiderealTime = greenwichSiderealTime + longitudeRad;
  final double hourAngle = localSiderealTime - rightAscension;

  // 5. Horizontal Coordinate Transformation (Azimuth Calculation)
  final double y = -sin(hourAngle);
  final double x =
      (tan(declination) * cos(latitudeRad)) -
      (sin(latitudeRad) * cos(hourAngle));

  // atan2 maps cleanly across all 4 quadrants (-pi to pi)
  double azimuthRad = atan2(y, x);

  // Normalize to a 0 to 2*pi domain
  if (azimuthRad < 0) {
    azimuthRad += 2 * pi;
  }

  // Convert radians to degrees (0° = North, 90° = East, 180° = South, 270° = West)
  final double azimuthDeg = azimuthRad * (180.0 / pi);

  return azimuthDeg;
}

void main() {
  setUp(() {});
  group('GROUP azimuth: ', () {
    test('TEST azimuth, London, J2000:', () {
      final double testAzimuth = calculateSolarAzimuth(
        hoursSinceJ2000: 0.0,
        longitudeRad: 0.0,
        latitudeRad: 51.5 / 180 * pi, //
      );
      print('Solar Azimuth Angle: ${testAzimuth.toStringAsFixed(2)} degrees.');
    });
    
    test('TEST azimuth, London, day of J2000:', () {
      
        final double longitudeRad = 0.0;
        final double latitudeRad = 51.5 / 180 * pi;
      final List<double> hourList = List.generate(24, (index) => -12.0 + index);
      final Iterable<(int, double)> testAzimuths = hourList.map((e) => (calculateSolarAzimuth(hoursSinceJ2000: e, longitudeRad: longitudeRad, latitudeRad: latitudeRad).round(), e));

      print('Solar Azimuth Angle: ${testAzimuths.toList()} degrees.');
    });
    
    test('TEST azimuth, London, day Jan 1 2026:', () {
      
        final double longitudeRad = 0.0;
        final double latitudeRad = 51.5 / 180 * pi;
      final List<double> hourList = List.generate(24, (index) => 52596.0 + index);
      final Iterable<(int, double)> testAzimuths = hourList.map((e) => (calculateSolarAzimuth(hoursSinceJ2000: e, longitudeRad: longitudeRad, latitudeRad: latitudeRad).round(), e));

      print('Solar Azimuth Angle: ${testAzimuths.toList()} degrees.');
    });
  });


  // 52596
}
