import 'dart:math';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vector_math/vector_math_64.dart';

/// Angle of tilt of Earth's axis.  This is angle does not impact any calculations
/// of Earth's orbit (e.g., mean anomaly), its revolution.  It only impacts
/// calculations that take into account Earth's rotation around its own axis.  By
/// definition, the direction of this tilt is exactly 90 degrees from the Vernal
/// Equinox, and this is tied to the global coordinate system used in this app
/// with longitude/argument of periapsis.
const double tiltDeg = 23.44;
final double tilt = radians(tiltDeg);

/// Earth's orbital aphelion distance in km
const double rA = 152097701;

/// Earth's orbital perihelion distance in km
const double rP = 147098290;
final double eccen = (rA - rP) / (rA + rP);

/// Mean longitude of Earth at J2000 in degrees
const double lMeanDeg = 100.46435;

/// Mean longitude of Earth at J2000 in radians
final double lMean = radians(lMeanDeg);

/// Longitude of perihelion at J2000 in degrees
const double lPeriDeg = 102.93735;

/// Longitude of perihelion at J2000 in radians
final double lPeri = radians(lPeriDeg);

/// Mean anomaly at epoch in radians
final double tMeanAnomalyAtEpoch = lMean - lPeri;

/// Earth rotation angle at J2000 relative to Vernal Equinox in radians
final double eraJ2000VE = 4.89496121282376;

/// Earth's average radius in km
const double rEarth = 6371;

/// Technically, this is the number of days (i.e., 24 hour periods) it takes Earth to revolve one
/// complete rotation around the sun.  Note that, this is NOT the number of times the Earth has
/// actually rotated around its axis during that time.  That would be this number plus one.  This
/// is because we measure a 24 hour period as the time it takes a point on Earth's surface to
/// rotate such that the sun returns to the same point (or, technically right ascension), but
/// because of Earth's revolution, the Earth has already rotated more than one complete rotation
/// around its axis in that time.
const double yearLength = 365.242190402;

/// Elevation to use in calculations.  This could later be made dynamic and looked up by lat/lon.
const double h1 = 0;
final num maxRelativeSolarStrengthAtEquator = pow(0.7, pow(1, 0.678));

// /// J2000
// final tz.TZDateTime date0J2000 = tz.TZDateTime.utc(2000, 1, 1, 12, 0, 0);

/// Vector from center of the Earth to the North Pole.  Used to calculate solar azimuth angle.
final Vector3 reNorthPole = Vector3(rEarth * sin(tilt), 0, rEarth * cos(tilt));

Iterable<OrbitAndSolarValues> calculateOrbitAndSolarValuesIterable({
  required double k,
  required double h,
  required num lat,
  required num lon,
  required tz.Location timeZone,
  required int year,
}) {
  final DateTime t0 = DateTime.now();

  /// The convention should be that lat and lon are in degrees while latRad and lonRad are in radians
  final double latRad = radians(lat.toDouble());

  /// The convention should be that lat and lon are in degrees while latRad and lonRad are in radians
  final double lonRad = radians(lon.toDouble());

  /// Midnight Jan first in the year provided and the timezone provided.
  final tz.TZDateTime dateTime0 = tz.TZDateTime(timeZone, year, 1, 1, 0, 0, 0);


  /// Number of days in the year provided (i.e., is it a leap year)
  final int nDays = isLeapYear(year) ? 366 : 365;

  print(
    'inside calculateOrbitAndSolarValuesIterable(), nDays: $nDays, timeZone: ${timeZone.name}, year: $year, dateTime0: $dateTime0, other dateTime: ${dateTime0.copyWith(year: dateTime0.year + 1)}',
  );

  /// Number of hours between J2000 and dateTIme0
  final int initialHOffsetFromJ2000 = dateTime0.difference(date0J2000).inHours;

  /// List of offsets in hours from J2000 for each 15-minute interval of the year provided
  final Iterable<double> hOffsetsFromJ2000 = Iterable.generate(
    nDays * 24 * 4,
    (i) => initialHOffsetFromJ2000 + i / 4,
  );

  
  print(
    'inside calculateOrbitAndSolarValuesIterable(), hOffsetsFromJ2000: $hOffsetsFromJ2000',
  );

  /// A custom class containing all relevant data for all of the hour offsets
  final Iterable<OrbitAndSolarValues> output = hOffsetsFromJ2000.map((
    hOffsetFromJ2000,
  ) {
    final tz.TZDateTime tzDateTime = calculateTZDateTime(dateTime0, initialHOffsetFromJ2000, hOffsetFromJ2000);
    final double earthRotationAngle = calculateERA(hOffsetFromJ2000);
    final double meanAnomaly = calculateMeanAnomaly(hOffsetFromJ2000);
    final double eccentricAnomaly = calculateEccentricAnomaly(meanAnomaly);
    final double trueAnomaly = calculateTrueAnomaly(eccentricAnomaly);
    final double orbitalRadiusMag = calculateOrbitalRadiusMag(trueAnomaly);
    final Vector3 earthRadius = calculateEarthRadius(
      latRad: latRad,
      lonRad: lonRad,
      earthRotationAngle: earthRotationAngle,
    );
    final Vector3 orbitalRadius = calculateOrbitalRadius(trueAnomaly);
    final double solarElevationAngle = calculateSolarElevationAngle(
      latRad: latRad,
      lonRad: lonRad,
      earthRotationAngle: earthRotationAngle,
      trueAnomaly: trueAnomaly,
      orbitalRadiusMag: orbitalRadiusMag,
      orbitalRadius: orbitalRadius,
      earthRadius: earthRadius,
    );
    final double solarAzimuthAngle = calculateSolarAzimuthAngle(
      latRad: latRad,
      lonRad: lonRad,
      earthRotationAngle: earthRotationAngle,
      trueAnomaly: trueAnomaly,
      orbitalRadiusMag: orbitalRadiusMag,
      orbitalRadius: orbitalRadius,
      earthRadius: earthRadius,
    );
    final double solarStrengthsLocalRelativeToGlobalMax =
        calculateSolarStrengthRelativeToGlobalMax(
          solarElevationAngle: solarElevationAngle,
          k: k,
          h: h,
        );

    final OrbitAndSolarValues output = OrbitAndSolarValues(
      tzDateTime: tzDateTime,
      hOffsetFromJ2000: hOffsetFromJ2000,
      earthRotationAngle: earthRotationAngle,
      meanAnomaly: meanAnomaly,
      eccentricAnomaly: eccentricAnomaly,
      trueAnomaly: trueAnomaly,
      orbitalRadiusMag: orbitalRadiusMag,
      orbitalRadius: orbitalRadius,
      earthRadius: earthRadius,
      solarElevationAngle: solarElevationAngle,
      solarAzimuthAngle: solarAzimuthAngle,
      solarStrengthsLocalRelativeToGlobalMax:
          solarStrengthsLocalRelativeToGlobalMax,
    );
    return output;
  });
  final DateTime tFinal = DateTime.now();
  print(
    'just did all the orbit calcs, which took ${tFinal.difference(t0).inMilliseconds} milliseconds',
  );

  return output;
}

Iterable<OrbitAndSolarValues> recalculateOrbitAndSolarValuesIterableNewK({
  required double k,
  required double h,
  required Iterable<OrbitAndSolarValues> oldValues,
}) {
  final Iterable<OrbitAndSolarValues> newValues = oldValues.map((e) {
    final double updatedSolarStrengthRelativeToGlobalMax =
        calculateSolarStrengthRelativeToGlobalMax(
          k: k,
          solarElevationAngle: e.solarElevationAngle,
          h: h,
        );
    return e.copyWith(
      solarStrengthsLocalRelativeToGlobalMax:
          updatedSolarStrengthRelativeToGlobalMax,
    );
  });
  return newValues;
}

tz.TZDateTime calculateTZDateTime(tz.TZDateTime dateTime0, int initialHOffsetFromJ2000, double hOffsetFromJ2000, ) {
  final double thisHOffset = hOffsetFromJ2000 - initialHOffsetFromJ2000;
  final int thisHOffsetHours = thisHOffset.toInt();
  final int thisHOffsetMinutes = ((thisHOffset - thisHOffsetHours) * 60).toInt();
  final int thisHOffsetSeconds = ((thisHOffset - thisHOffsetHours - (thisHOffsetMinutes / 60)) * 3600).toInt();
  return dateTime0.add(Duration(hours: thisHOffsetHours, minutes: thisHOffsetMinutes, seconds: thisHOffsetSeconds));
}


double calculateERA(double hOffsetFromJ2000) =>
    (2 * pi * (yearLength + 1) / yearLength * (hOffsetFromJ2000 / 24) +
            eraJ2000VE -
            lPeri)
        .remainder(2 * pi);

double calculateMeanAnomaly(double hOffsetFromJ2000) =>
    (tMeanAnomalyAtEpoch + (2 * pi) * (hOffsetFromJ2000 / (yearLength * 24)))
        .remainder(2 * pi);

double calculateEccentricAnomaly(double meanAnomaly) => newtonRaphson(
  func: (guess) => guess - eccen * sin(guess) - meanAnomaly,
  funcPrime: (guess) => 1 - eccen * cos(guess),
  initialGuess: meanAnomaly,
);

double calculateTrueAnomaly(double eccentricAnomaly) =>
    2 * atan(sqrt(rA / rP) * tan(eccentricAnomaly / 2));

double calculateOrbitalRadiusMag(double trueAnomaly) =>
    2 * rA * rP / (rA * (1 + cos(trueAnomaly)) + rP * (1 - cos(trueAnomaly)));

Vector3 calculateEarthRadius({
  required double latRad,
  required double lonRad,
  required double earthRotationAngle,
}) => Vector3(
  rEarth * cos(latRad) * cos(tilt) * cos(earthRotationAngle + lonRad) +
      rEarth * sin(latRad) * sin(tilt),
  rEarth * cos(latRad) * sin(earthRotationAngle + lonRad),
  -rEarth * cos(latRad) * sin(tilt) * cos(earthRotationAngle + lonRad) +
      rEarth * sin(latRad) * cos(tilt),
);

Vector3 calculateOrbitalRadius(double trueAnomaly) => Vector3(
  ((rA + rP) / 2) * cos(trueAnomaly) - ((rA - rP) / 2),
  sqrt(rA * rP) * sin(trueAnomaly),
  0,
);

double calculateSolarElevationAngleTrig({
  required double latRad,
  required double lonRad,
  required double earthRotationAngle,
  required double trueAnomaly,
  required double orbitalRadiusMag,
}) {
  final double intermediateTerm =
      orbitalRadiusMag *
      ((sin(lPeri) * cos(trueAnomaly) + cos(lPeri) * sin(trueAnomaly)) *
              (cos(latRad) * cos(tilt) * cos(earthRotationAngle + lonRad) +
                  sin(latRad) * sin(tilt)) +
          (-cos(lPeri) * cos(trueAnomaly) + sin(lPeri) * sin(trueAnomaly)) *
              (cos(latRad) * sin(earthRotationAngle + lonRad)));
  final double output = -asin(
    (rEarth + intermediateTerm) /
        sqrt(
          pow(rEarth, 2) +
              pow(orbitalRadiusMag, 2) +
              2 * rEarth * intermediateTerm,
        ),
  );
  return output;
}

double calculateSolarElevationAngle({
  required double latRad,
  required double lonRad,
  required double earthRotationAngle,
  required double trueAnomaly,
  required double orbitalRadiusMag,
  required Vector3 orbitalRadius,
  required Vector3 earthRadius,
}) {
  final double oPDotRe = orbitalRadius.dot(earthRadius);
  final double sinTheta =
      (pow(rEarth, 2) - oPDotRe) /
      (rEarth * sqrt(pow(rEarth, 2) + pow(orbitalRadiusMag, 2) - 2 * oPDotRe));
  final double theta = asin(sinTheta.clamp(-1.0, 1.0));
  return theta;
}

double calculateSolarAzimuthAngle({
  required double latRad,
  required double lonRad,
  required double earthRotationAngle,
  required double trueAnomaly,
  required double orbitalRadiusMag,
  required Vector3 orbitalRadius,
  required Vector3 earthRadius,
}) {
  final Vector3 opNeg = -orbitalRadius;
  final Vector3 rN = reNorthPole - earthRadius;
  final Vector3 rNTang =
      rN - earthRadius * earthRadius.dot(rN) / pow(rEarth, 2).toDouble();
  final double cosAlpha =
      (rEarth * opNeg.dot(rNTang)) /
      (sqrt(
            pow(rEarth, 2) * pow(orbitalRadiusMag, 2) -
                pow(earthRadius.dot(opNeg), 2),
          ) *
          rNTang.length);
  final double alphaRaw = acos(cosAlpha.clamp(-1.0, 1.0));

  // Since cosine is symmetrical about x = 0, if we stopped here and used
  // alphaRaw, we would only get results between 0 and 180.  Instead, we use
  // sign to determine whether the angle should be 0 to 180 or 180 to 360.
  final double sign =
      earthRadius.x * (rNTang.y * opNeg.z - rNTang.z * opNeg.y) +
      earthRadius.y * (rNTang.z * opNeg.x - rNTang.x * opNeg.z) +
      earthRadius.z * (rNTang.x * opNeg.y - rNTang.y * opNeg.x);
  final double alpha;
  if (sign < 0) {
    alpha = 2 * pi - alphaRaw;
  } else {
    alpha = alphaRaw;
  }

  return alpha;
}

double calculateSolarStrengthRelativeToGlobalMax({
  required double solarElevationAngle,
  required double k,
  required double h,
}) {
  if (solarElevationAngle <= 0) return 0;
  final double airMassSeaLevel =
      1 /
      (cos(pi / 2 - solarElevationAngle) +
          0.50572 *
              pow(96.07995 - degrees(pi / 2 - solarElevationAngle), -1.6364));
  final double localSolarStrengthFactor = airMassSeaLevel >= 38
      ? 0
      : exp(-k * airMassSeaLevel * exp(-h / 8.5));
  final double globalMax = exp(-k);
  final double solarStrengthsLocalRelativeToGlobalMax =
      localSolarStrengthFactor / globalMax;
  return solarStrengthsLocalRelativeToGlobalMax;
}

// This is super dangerous because I am creating a loop that will NEVER end if no root is found.  I am intententionally letting this go here and intend to protect against this with at a higher level somehow.  Since this is going to run SO MUCH, I want to keep this is light as possible.
// Performance improvement would be to code the function and prime function right in instead of passing them.
double newtonRaphson({
  required double Function(double) func,
  required double Function(double) funcPrime,
  double? initialGuess,
}) {
  double currentGuess = initialGuess ?? 0;

  //For now, use this checking logic, but I can probably just pick a constant number of times to run this and get a good enough value.
  while (true) {
    final double prevGuess = currentGuess;
    currentGuess =
        currentGuess - (func(currentGuess) / funcPrime(currentGuess));
    if ((currentGuess - prevGuess).abs() <= 0.000001) break;
  }

  return currentGuess;
}
