import 'dart:math';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
final num maxRelativeSolarStrengthAtEquator = pow(0.7,pow(1, 0.678));

// void main() {
//   getChartData();
// }
final double latInput = 42.6424568895893;
final double longInput = -71.3833058055504;
final double p1 = radians(latInput);
final double l1 = radians(longInput);

Iterable<({double earthRotationAngle, double trueAnomaly})> getYearTrueAnomalies({
  int yearInput = 2026,
  String tZoneInput = "America/New_York",
}) {
  print('started getChartData');

  tz.initializeTimeZones();
  final tz.Location localTZ = tz.getLocation(tZoneInput);
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
  final Iterable<({double earthRotationAngle, double meanAnomaly})> yearMeanAnomalies =
      yearJ2000OffsetsHours.map(
        (offset) => (
          earthRotationAngle: (2 * pi * (0.779057273264 + 1.00273781191135 * (offset / 24)) - pi / 2).remainder(2 * pi),
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
  final Iterable<({double earthRotationAngle, double trueAnomaly})> yearTrueAnomalies =
      yearEccentricAnomalies.map(
        (anomaly) => (
          earthRotationAngle: anomaly.earthRotationAngle,
          trueAnomaly:
              2 * atan(sqrt(rA / rP) * tan(anomaly.eccentricAnomaly / 2)),
        ),
      );

  return yearTrueAnomalies;
}

Iterable<double> getYearSolarElevationAngles(Iterable<({double earthRotationAngle, double trueAnomaly})> inputData) {
  final Iterable<double> output = inputData.map((({double earthRotationAngle, double trueAnomaly}) inputDataPoint) {
    final double orbitalRadius = 2 * rA * rP / (rA * (1 + cos(inputDataPoint.trueAnomaly)) + rP * (1 - cos(inputDataPoint.trueAnomaly)));
    final double intermediateTerm = orbitalRadius * (
      (
        sin(lPeri) * cos(inputDataPoint.trueAnomaly) + 
        cos(lPeri) * sin(inputDataPoint.trueAnomaly)
      ) *
      (
        cos(p1) * cos(tilt) * cos(inputDataPoint.earthRotationAngle + l1) + 
        sin(p1) * sin(tilt)
      ) + 
      (
        -cos(lPeri) * cos(inputDataPoint.trueAnomaly) + 
        sin(lPeri) * sin(inputDataPoint.trueAnomaly)
      ) *
      (
        cos(p1) * sin(inputDataPoint.earthRotationAngle + l1)
      )
    );
    final double output = -asin(
      (rEarth + intermediateTerm) / 
      sqrt(pow(rEarth, 2) + pow(orbitalRadius, 2) + 2 * rEarth * intermediateTerm)
    );
    return output;
  });
  
  return output;
}

Iterable<double> getYearSolarStrengthsLocalRelativeToGlobal(Iterable<double> yearSolarElevationAngles) {
// maxRelativeSolarStrengthAtEquator
  final Iterable<double> yearAirMass = yearSolarElevationAngles.map((elev) => elev <= 0 ? 0 : 1 / (cos(pi/2 - elev) + 0.50572*pow(96.07995 - degrees(pi/2 - elev),-1.6364)));
  final Iterable<double> yearSolarStrengthsLocal = yearAirMass.map((aM) => h1/7.1 + ((1-h1/7.1)*pow(0.7,pow(aM,0.678))));
  final Iterable<double> yearSolarStrengthsLocalRelativeToGlobal = yearSolarStrengthsLocal.map((strength) => strength / maxRelativeSolarStrengthAtEquator);
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
