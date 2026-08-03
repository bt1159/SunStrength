import 'dart:math';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;

const kDebugMode = true;

//flutter run -d web-server
// kill ports with: pkill -f flutter
// launch with specific port with: flutter run -d web-server --web-port=8080

double interpolate(
  double ind0,
  double dep0,
  double ind1,
  double dep1,
  double ind2,
) {
  return (dep1 - dep0) / (ind1 - ind0) * (ind2 - ind0) + dep0;
}

double radians(double deg) {
  return deg * pi / 180;
}

double degrees(double rad) {
  return rad * 180 / pi;
}

const double tiltDeg = 23.44;
final double tilt = radians(tiltDeg);
const double rA = 152097701; // Earth's orbital aphelion distance in km
const double rP = 147098290; // Earth's orbital perihelion distance in km
final double eccen = (rA - rP) / (rA + rP);
const double lMeanDeg =
    100.46435; // Mean longitude of Earth at J2000 in degrees
final double lMean = radians(
  lMeanDeg,
); // Mean longitude of Earth at J2000 in radians
const double lPeriDeg =
    102.93735; // Longitude of perihelion at J2000 in degrees
final double lPeri = radians(
  lPeriDeg,
); // Longitude of perihelion at J2000 in radians
final double tMeanAnomalyAtEpoch =
    lMean - lPeri; // Mean anomaly at epoch in radians
const double rEarth = 6371; // Earth's radius in km
const double yearLength = 365.242190402;
// const double h1 = 0.048006; // Elevation to use for now
const double h1 = 0;
final num maxRelativeSolarStrengthAtEquator = pow(0.7, pow(1, 0.678));

// void main() {
//   getChartData();
// }
// final double latInput = 42.6424568895893;
// final double latInput = 25;
// final double longInput = -71.3833058055504;

/// Function called by widget tree to generate the actual data points used to make the chart.
///
/// Note: the data ALWAYS starts at 12am 01 Jan, but the timezone of that start time is
/// determined inside this function from the lat and lon given.
Iterable<double> masterFunctionSolarStrengthArray({
  required double k,
  required double h,
  required num lat,
  required num lon,
}) {
  print('running masterFunctionSolarStrengthArray');
  final String timeZoneName = tzmap.latLngToTimezoneString(lat, lon);
  final Iterable<({double earthRotationAngle, double trueAnomaly})>
  yearTrueAnomalies = getYearTrueAnomalies(
    tZoneInput: timeZoneName == 'unknown' ? null : timeZoneName,
  );
  final Iterable<double> yearSolarElevationAngles = getYearSolarElevationAngles(
    inputData: yearTrueAnomalies,
    lat: lat,
    lon: lon,
  );
  final Iterable<double> yearSolarStrengthsLocalRelative =
      getYearSolarStrengthsLocalRelativeToGlobal(
        h: h,
        k: k,
        yearSolarElevationAngles: yearSolarElevationAngles,
      );
  return yearSolarStrengthsLocalRelative;
}

/// Function to output the earth rotation angle and true anomaly that will be used to calculate each
/// solar strength data point.  time zone is an input here so that actual offset from J2000 to 12am
/// Jan 01 at this time zone and with the given year can be calculated
Iterable<({double earthRotationAngle, double trueAnomaly})>
getYearTrueAnomalies({int yearInput = 2026, String? tZoneInput}) {
  print(
    'started getYearTrueAnomalies for year: $yearInput and tZoneInput before null assign: $tZoneInput',
  );

  tZoneInput ??= "America/New_York";

  tz.initializeTimeZones();

  tz.Location localTZ;

  try {
    localTZ = tz.getLocation(tZoneInput);
    print(
      'inside getYearTrueAnomalies, trying to see if tZoneInput was used correctly.  locatTZ: $localTZ',
    );
  } catch (error) {
    print(error);
    localTZ = tz.getLocation("America/New_York");
  }

  final tz.TZDateTime date0J2000 = tz.TZDateTime.utc(2000, 1, 1, 12, 0, 0);
  final tz.TZDateTime date0 = tz.TZDateTime(localTZ, yearInput, 1, 1, 0, 0, 0);
  final int nDays = date0
      .copyWith(year: date0.year + 1)
      .difference(date0)
      .inDays;
  final initialOffsetHours = date0.difference(date0J2000).inHours;

  final Iterable<double> yearJ2000OffsetsHours = Iterable.generate(
    nDays * 24 * 4,
    (i) => initialOffsetHours + i / 4,
  ); // List of offsets in hours from J2000 for each 15-minute interval of the year

  print('timeStampBeforeMean: ${tz.TZDateTime.now(tz.UTC)}');
  final Iterable<({double earthRotationAngle, double meanAnomaly})>
  yearMeanAnomalies = yearJ2000OffsetsHours.map(
    (offset) => (
      earthRotationAngle:
          (2 * pi * (0.779057273264 + 1.00273781191135 * (offset / 24)) -
                  pi / 2)
              .remainder(2 * pi),
      meanAnomaly:
          (tMeanAnomalyAtEpoch + (2 * pi) * (offset / (yearLength * 24)))
              .remainder(2 * pi),
    ),
  );
  double rootFunc(double guess, double meanAnomaly) =>
      guess - eccen * sin(guess) - meanAnomaly;
  double rootPrimeFunc(double guess, double meanAnomaly) =>
      1 - eccen * cos(guess);
  print('timeStampBeforeEccentric: ${tz.TZDateTime.now(tz.UTC)}');
  final Iterable<({double earthRotationAngle, double eccentricAnomaly})>
  yearEccentricAnomalies = yearMeanAnomalies.map(
    (anomaly) => (
      earthRotationAngle: anomaly.earthRotationAngle,
      eccentricAnomaly: newtonRaphson(
        (double guess) => rootFunc(guess, anomaly.meanAnomaly),
        (double guess) => rootPrimeFunc(guess, anomaly.meanAnomaly),
        anomaly.meanAnomaly,
      ),
    ),
  );

  print('timeStampBeforeTrue: ${tz.TZDateTime.now(tz.UTC)}');
  final Iterable<({double earthRotationAngle, double trueAnomaly})>
  yearTrueAnomalies = yearEccentricAnomalies.map(
    (anomaly) => (
      earthRotationAngle: anomaly.earthRotationAngle,
      trueAnomaly: 2 * atan(sqrt(rA / rP) * tan(anomaly.eccentricAnomaly / 2)),
    ),
  );

  return yearTrueAnomalies;
}

/// Uses the list of earth rotation angles and true anomalies, and the local lat & lon, to calculate
/// the angle of the sun at that location for each ERA & true anomaly.  Time zone is no longer needed as
/// an input since we are just using the ERAs and true anomalies.
Iterable<double> getYearSolarElevationAngles({
  required Iterable<({double earthRotationAngle, double trueAnomaly})>
  inputData,
  required num lat,
  required num lon,
}) {
  final double p1 = radians(lat.toDouble());
  final double l1 = radians(lon.toDouble());
  final Iterable<double> output = inputData.map((
    ({double earthRotationAngle, double trueAnomaly}) inputDataPoint,
  ) {
    final double orbitalRadius =
        2 *
        rA *
        rP /
        (rA * (1 + cos(inputDataPoint.trueAnomaly)) +
            rP * (1 - cos(inputDataPoint.trueAnomaly)));
    final double intermediateTerm =
        orbitalRadius *
        ((sin(lPeri) * cos(inputDataPoint.trueAnomaly) +
                    cos(lPeri) * sin(inputDataPoint.trueAnomaly)) *
                (cos(p1) *
                        cos(tilt) *
                        cos(inputDataPoint.earthRotationAngle + l1) +
                    sin(p1) * sin(tilt)) +
            (-cos(lPeri) * cos(inputDataPoint.trueAnomaly) +
                    sin(lPeri) * sin(inputDataPoint.trueAnomaly)) *
                (cos(p1) * sin(inputDataPoint.earthRotationAngle + l1)));
    final double output = -asin(
      (rEarth + intermediateTerm) /
          sqrt(
            pow(rEarth, 2) +
                pow(orbitalRadius, 2) +
                2 * rEarth * intermediateTerm,
          ),
    );
    return output;
  });

  return output.map((e) => max(0, e));
}

/// Function that convers the angle of the sun for each data point to the relative solar strength.  Time
/// zone is not needed as an input because this calculation is independent of time.
Iterable<double> getYearSolarStrengthsLocalRelativeToGlobal({
  required Iterable<double> yearSolarElevationAngles,
  required double k,
  required double h,
}) {
  // maxRelativeSolarStrengthAtEquator
  final Iterable<double> yearAirMassSeaLevel = yearSolarElevationAngles.map(
    (elevAngle) => elevAngle <= 0
        ? 38
        : 1 /
              (cos(pi / 2 - elevAngle) +
                  0.50572 *
                      pow(96.07995 - degrees(pi / 2 - elevAngle), -1.6364)),
  );
  final Iterable<double> yearLocalSolarStrengthFactors = yearAirMassSeaLevel
      .map((aM) => aM >= 38 ? 0 : exp(-k * aM * exp(-h / 8.5)));
  final double globalMax = exp(-k);
  final Iterable<double> yearSolarStrengthsLocalRelativeToGlobal =
      yearLocalSolarStrengthFactors.map((factor) => factor / globalMax);

  // final Iterable<double> yearSolarStrengthsLocal = yearAirMass.map((aM) => h1/7.1 + ((1-h1/7.1)*pow(0.7,pow(aM,0.678))));
  // final Iterable<double> yearSolarStrengthsLocalRelativeToGlobal = yearSolarStrengthsLocal.map((strength) => strength / maxRelativeSolarStrengthAtEquator);
  return yearSolarStrengthsLocalRelativeToGlobal;
}

// This is super dangerous because I am creating a loop that will NEVER end if no root is found.  I am intententionally letting this go here and intend to protect against this with at a higher level somehow.  Since this is going to run SO MUCH, I want to keep this is light as possible.
// Performance improvement would be to code the function and prime function right in instead of passing them.
double newtonRaphson(
  double Function(double) funcNum,
  double Function(double) funcPrimeNum, [
  double? initialGuess,
]) {
  double currentGuess = initialGuess ?? 0;
  // double nextGuess() {
  //   return currentGuess - funcNum(currentGuess)/funcPrimeNum(currentGuess);
  // }

  //For now, use this checking logic, but I can probably just pick a constant number of times to run this and get a good enough value.
  while (true) {
    final double prevGuess = currentGuess;
    currentGuess =
        currentGuess - (funcNum(currentGuess) / funcPrimeNum(currentGuess));
    if ((currentGuess - prevGuess).abs() <= 0.000001) break;
  }

  return currentGuess;
}
