import 'dart:math';
// import 'package:flutter/gestures.dart';
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

/// J2000
final tz.TZDateTime date0J2000 = tz.TZDateTime.utc(2000, 1, 1, 12, 0, 0);

/// Vector from center of the Earth to the North Pole.  Used to calculate solar azimuth angle.
final Vector3 reNorthPole = Vector3(rEarth * sin(tilt), 0, rEarth * cos(tilt));

// /// Function called by widget tree to generate a 1D Iterable of data points that are a year's
// /// worth of solar strengths.
// ///
// /// Note: the data ALWAYS starts at 12am 01 Jan local time, but the timezone of that start time is
// /// determined inside this function from the lat and lon given.
// Iterable<double> masterFunctionSolarStrengthArray({
//   required double k,
//   required double h,
//   required num lat,
//   required num lon,
//   required tz.Location timeZone,
//   required int year,
// }) {
//   print('running masterFunctionSolarStrengthArray');
//   final TimedOrbitData yearTrueAnomalies = getYearTrueAnomalies(
//     timeZone: timeZone,
//     yearInput: year,
//   );
//   final Iterable<double> yearSolarElevationAngles = getYearSolarElevationAngles(
//     inputData: yearTrueAnomalies,
//     lat: lat,
//     lon: lon,
//   );
//   // TODO: Check if this is actually relative to local or to global.
//   final Iterable<double> yearSolarStrengthsLocalRelative =
//       getYearSolarStrengthsLocalRelativeToGlobal(
//         h: h,
//         k: k,
//         yearSolarElevationAngles: yearSolarElevationAngles,
//       );
//   return yearSolarStrengthsLocalRelative;
// }

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
  final int nDays = dateTime0
      .copyWith(year: dateTime0.year + 1)
      .difference(dateTime0)
      .inDays;

  /// Number of hours between J2000 and dateTIme0
  final initialHOffsetFromJ2000 = dateTime0.difference(date0J2000).inHours;

  /// List of offsets in hours from J2000 for each 15-minute interval of the year provided
  final Iterable<double> hOffsetsFromJ2000 = Iterable.generate(
    nDays * 24 * 4,
    (i) => initialHOffsetFromJ2000 + i / 4,
  );

  /// A custom class containing all relevant data for all of the hour offsets
  final Iterable<OrbitAndSolarValues> output = hOffsetsFromJ2000.map((
    hOffsetFromJ2000,
  ) {
    final double earthRotationAngle = calculateERA(hOffsetFromJ2000);
    final double meanAnomaly = calculateMeanAnomaly(hOffsetFromJ2000);
    final double eccentricAnomaly = calculateEccentricAnomaly(meanAnomaly);
    final double trueAnomaly = calculateTrueAnomaly(eccentricAnomaly);
    final double orbitalRadius = calculateOrbitalRadius(trueAnomaly);
    final double solarElevationAngle = calculateSolarElevationAngle(
      latRad: latRad,
      lonRad: lonRad,
      earthRotationAngle: earthRotationAngle,
      trueAnomaly: trueAnomaly,
      orbitalRadius: orbitalRadius,
    );
    final double solarAzimuthAngle = calculateSolarAzimuthAngle(
      latRad: latRad,
      lonRad: lonRad,
      earthRotationAngle: earthRotationAngle,
      trueAnomaly: trueAnomaly,
      orbitalRadius: orbitalRadius,
    );
    final double solarStrengthsLocalRelativeToGlobalMax =
        calculateSolarStrengthRelativeToGlobalMax(
          solarElevationAngle: solarElevationAngle,
          k: k,
          h: h,
        );

    final OrbitAndSolarValues output = OrbitAndSolarValues(
      hOffsetFromJ2000: hOffsetFromJ2000,
      earthRotationAngle: earthRotationAngle,
      meanAnomaly: meanAnomaly,
      eccentricAnomaly: eccentricAnomaly,
      trueAnomaly: trueAnomaly,
      orbitalRadius: orbitalRadius,
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

double calculateOrbitalRadius(double trueAnomaly) =>
    2 * rA * rP / (rA * (1 + cos(trueAnomaly)) + rP * (1 - cos(trueAnomaly)));

double calculateSolarElevationAngle({
  required double latRad,
  required double lonRad,
  required double earthRotationAngle,
  required double trueAnomaly,
  required double orbitalRadius,
}) {
  final double intermediateTerm =
      orbitalRadius *
      ((sin(lPeri) * cos(trueAnomaly) + cos(lPeri) * sin(trueAnomaly)) *
              (cos(latRad) * cos(tilt) * cos(earthRotationAngle + lonRad) +
                  sin(latRad) * sin(tilt)) +
          (-cos(lPeri) * cos(trueAnomaly) + sin(lPeri) * sin(trueAnomaly)) *
              (cos(latRad) * sin(earthRotationAngle + lonRad)));
  final double output = -asin(
    (rEarth + intermediateTerm) /
        sqrt(
          pow(rEarth, 2) +
              pow(orbitalRadius, 2) +
              2 * rEarth * intermediateTerm,
        ),
  );
  return output;
}

double calculateSolarAzimuthAngle({
  required double latRad,
  required double lonRad,
  required double earthRotationAngle,
  required double trueAnomaly,
  required double orbitalRadius,
}) {
  final Vector3 opNeg = Vector3(
    -(rA + rP) / 2 * cos(trueAnomaly) + (rA - rP) / 2,
    -sqrt(rA * rP) * sin(trueAnomaly),
    0,
  );
  final Vector3 re = Vector3(
    rEarth * cos(latRad) * cos(tilt) * cos(earthRotationAngle + lonRad) +
        rEarth * sin(latRad) * sin(tilt),
    rEarth * cos(latRad) * sin(earthRotationAngle + lonRad),
    -rEarth * cos(latRad) * sin(tilt) * cos(earthRotationAngle + lonRad) +
        rEarth * sin(latRad) * cos(tilt),
  );
  final Vector3 rN = reNorthPole - re;
  final Vector3 rNTang = rN - re * re.dot(rN) / re.length2;
  final double cosAlpha =
      (rEarth * opNeg.dot(rNTang)) /
      (sqrt(pow(rEarth, 2) * pow(orbitalRadius, 2) - pow(re.dot(opNeg), 2)) *
          rNTang.length);
  final double alpha = acos(cosAlpha.clamp(-1.0, 1.0));
  return alpha;

  // Compute O_perp without allocating extra vectors for cross products
  // O_perp = O - ( (O . E) / (E . E) ) * E
  // final double scale = opNeg.dot(re) / eDotE;
  // final Vector3 oPerp = Vector3(
  //   opNeg.x - re.x * scale,
  //   opNeg.y - re.y * scale,
  //   opNeg.z - re.z * scale,
  // );

  // final double oPerpSq = oPerp.dot(oPerp);
  // final double nSq = rNTang.dot(rNTang);

  // final double denSq = oPerpSq * nSq;
  // if (denSq < 1e-24) return 0.0; // O is parallel to E, or N is zero

  // // Single sqrt call via combined denominator
  // final double cosTheta = oPerp.dot(rNTang) / sqrt(denSq);

  // // Clamp to prevent precision errors returning > 1.0 or < -1.0
  // return cosTheta.clamp(-1.0, 1.0);
}

double calculateSolarStrengthRelativeToGlobalMax({
  required double solarElevationAngle,
  required double k,
  required double h,
}) {
  if (solarElevationAngle <= 0) return 0;
  final double airMassSeaLevel = 1 /
            (cos(pi / 2 - solarElevationAngle) +
                0.50572 *
                    pow(
                      96.07995 - degrees(pi / 2 - solarElevationAngle),
                      -1.6364,
                    ));
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

// /// Function to output the earth rotation angle and true anomaly that will be used to calculate each
// /// solar strength data point.  time zone is an input here so that actual offset from J2000 to 12am
// /// Jan 01 at this time zone and with the given year can be calculated
// Iterable<({double earthRotationAngle, double trueAnomaly})>
// getYearTrueAnomalies({required int yearInput, required tz.Location timeZone}) {
//   print(
//     'started getYearTrueAnomalies for year: $yearInput and tZoneInput before null assign: ${timeZone.name}',
//   );

//   final tz.TZDateTime date0 = tz.TZDateTime(timeZone, yearInput, 1, 1, 0, 0, 0);
//   final int nDays = date0
//       .copyWith(year: date0.year + 1)
//       .difference(date0)
//       .inDays;
//   final initialOffsetHours = date0.difference(date0J2000).inHours;

//   final Iterable<double> yearJ2000OffsetsHours = Iterable.generate(
//     nDays * 24 * 4,
//     (i) => initialOffsetHours + i / 4,
//   ); // List of offsets in hours from J2000 for each 15-minute interval of the year

//   print('timeStampBeforeMean: ${tz.TZDateTime.now(tz.UTC)}');
//   final Iterable<({double earthRotationAngle, double meanAnomaly})>
//   yearMeanAnomalies = yearJ2000OffsetsHours.map(
//     (offset) => (
//       earthRotationAngle:
//           (2 * pi * (0.779057273264 + 1.00273781191135 * (offset / 24)) -
//                   pi / 2)
//               .remainder(2 * pi),
//       meanAnomaly:
//           (tMeanAnomalyAtEpoch + (2 * pi) * (offset / (yearLength * 24)))
//               .remainder(2 * pi),
//     ),
//   );
//   double rootFunc(double guess, double meanAnomaly) =>
//       guess - eccen * sin(guess) - meanAnomaly;
//   double rootPrimeFunc(double guess, double meanAnomaly) =>
//       1 - eccen * cos(guess);
//   print('timeStampBeforeEccentric: ${tz.TZDateTime.now(tz.UTC)}');
//   final Iterable<({double earthRotationAngle, double eccentricAnomaly})>
//   yearEccentricAnomalies = yearMeanAnomalies.map(
//     (anomaly) => (
//       earthRotationAngle: anomaly.earthRotationAngle,
//       eccentricAnomaly: newtonRaphson(
//         (double guess) => rootFunc(guess, anomaly.meanAnomaly),
//         (double guess) => rootPrimeFunc(guess, anomaly.meanAnomaly),
//         anomaly.meanAnomaly,
//       ),
//     ),
//   );

//   print('timeStampBeforeTrue: ${tz.TZDateTime.now(tz.UTC)}');
//   final Iterable<({double earthRotationAngle, double trueAnomaly})>
//   yearTrueAnomalies = yearEccentricAnomalies.map(
//     (anomaly) => (
//       earthRotationAngle: anomaly.earthRotationAngle,
//       trueAnomaly: 2 * atan(sqrt(rA / rP) * tan(anomaly.eccentricAnomaly / 2)),
//     ),
//   );

//   return yearTrueAnomalies;
// }

// /// Uses the list of earth rotation angles and true anomalies, and the local lat & lon, to calculate
// /// the angle of the sun at that location for each ERA & true anomaly.  Time zone is no longer needed as
// /// an input since we are just using the ERAs and true anomalies.
// Iterable<double> getYearSolarElevationAngles({
//   required Iterable<({double earthRotationAngle, double trueAnomaly})>
//   inputData,
//   required num lat,
//   required num lon,
// }) {
//   final double p1 = radians(lat.toDouble());
//   final double l1 = radians(lon.toDouble());
//   final Iterable<double> output = inputData.map((
//     ({double earthRotationAngle, double trueAnomaly}) inputDataPoint,
//   ) {
//     final double orbitalRadius =
//         2 *
//         rA *
//         rP /
//         (rA * (1 + cos(inputDataPoint.trueAnomaly)) +
//             rP * (1 - cos(inputDataPoint.trueAnomaly)));
//     final double intermediateTerm =
//         orbitalRadius *
//         ((sin(lPeri) * cos(inputDataPoint.trueAnomaly) +
//                     cos(lPeri) * sin(inputDataPoint.trueAnomaly)) *
//                 (cos(p1) *
//                         cos(tilt) *
//                         cos(inputDataPoint.earthRotationAngle + l1) +
//                     sin(p1) * sin(tilt)) +
//             (-cos(lPeri) * cos(inputDataPoint.trueAnomaly) +
//                     sin(lPeri) * sin(inputDataPoint.trueAnomaly)) *
//                 (cos(p1) * sin(inputDataPoint.earthRotationAngle + l1)));
//     final double output = -asin(
//       (rEarth + intermediateTerm) /
//           sqrt(
//             pow(rEarth, 2) +
//                 pow(orbitalRadius, 2) +
//                 2 * rEarth * intermediateTerm,
//           ),
//     );
//     return output;
//   });

//   return output.map((e) => max(0, e));
// }

// /// Function that convers the angle of the sun for each data point to the relative solar strength.  Time
// /// zone is not needed as an input because this calculation is independent of time.
// Iterable<double> getYearSolarStrengthsLocalRelativeToGlobal({
//   required Iterable<double> yearSolarElevationAngles,
//   required double k,
//   required double h,
// }) {
//   // maxRelativeSolarStrengthAtEquator
//   final Iterable<double> yearAirMassSeaLevel = yearSolarElevationAngles.map(
//     (elevAngle) => elevAngle <= 0
//         ? 38
//         : 1 /
//               (cos(pi / 2 - elevAngle) +
//                   0.50572 *
//                       pow(96.07995 - degrees(pi / 2 - elevAngle), -1.6364)),
//   );
//   final Iterable<double> yearLocalSolarStrengthFactors = yearAirMassSeaLevel
//       .map((aM) => aM >= 38 ? 0 : exp(-k * aM * exp(-h / 8.5)));
//   final double globalMax = exp(-k);
//   final Iterable<double> yearSolarStrengthsLocalRelativeToGlobal =
//       yearLocalSolarStrengthFactors.map((factor) => factor / globalMax);

//   // final Iterable<double> yearSolarStrengthsLocal = yearAirMass.map((aM) => h1/7.1 + ((1-h1/7.1)*pow(0.7,pow(aM,0.678))));
//   // final Iterable<double> yearSolarStrengthsLocalRelativeToGlobal = yearSolarStrengthsLocal.map((strength) => strength / maxRelativeSolarStrengthAtEquator);
//   return yearSolarStrengthsLocalRelativeToGlobal;
// }

// // This is super dangerous because I am creating a loop that will NEVER end if no root is found.  I am intententionally letting this go here and intend to protect against this with at a higher level somehow.  Since this is going to run SO MUCH, I want to keep this is light as possible.
// // Performance improvement would be to code the function and prime function right in instead of passing them.
// double newtonRaphsonOld(
//   double Function(double) funcNum,
//   double Function(double) funcPrimeNum, [
//   double? initialGuess,
// ]) {
//   double currentGuess = initialGuess ?? 0;
//   // double nextGuess() {
//   //   return currentGuess - funcNum(currentGuess)/funcPrimeNum(currentGuess);
//   // }

//   //For now, use this checking logic, but I can probably just pick a constant number of times to run this and get a good enough value.
//   while (true) {
//     final double prevGuess = currentGuess;
//     currentGuess =
//         currentGuess - (funcNum(currentGuess) / funcPrimeNum(currentGuess));
//     if ((currentGuess - prevGuess).abs() <= 0.000001) break;
//   }

//   return currentGuess;
// }
