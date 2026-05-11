import 'dart:math';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;




const kDebugMode = true;

void test() {
  if (kDebugMode) {
    print('yup, this worked');
  }
}

double interpolate(double ind0,double dep0,double ind1,double dep1,double ind2) {
  return (dep1-dep0)/(ind1-ind0)*(ind2-ind0)+dep0;
}

double  radians(double deg) {
  return deg*pi/180;
}

double  degrees(double rad) {
  return rad*180/pi;
}


const double tiltDeg = 23.44;
final double title = radians(tiltDeg);
const double rA = 152097701;  // Earth's orbital aphelion distance in km
const double rP = 147098290;  // Earth's orbital perihelion distance in km
const double lMeanDeg = 100.46435;  // Mean longitude of Earth at J2000 in degrees
final double lMean = radians(lMeanDeg);  // Mean longitude of Earth at J2000 in radians
const double lPeriDeg = 102.93735;  // Longitude of perihelion at J2000 in degrees
final double lPeri = radians(lPeriDeg);  // Longitude of perihelion at J2000 in radians
final double tMeanAnomalyAtEpoch = lMean - lPeri;  // Mean anomaly at epoch in radians
const double rEarth = 6371;  // Earth's radius in km
const double yearLength = 365.242190402;    
const double h1 = 0.048006;  // Elevation to use for now


void getChartData() {
  print('started');
  
final int yearInput = 2026;
final double latInput = 42.6424568895893;
final double longInput = -71.3833058055504;
final String tzoneInput = "America/New_York";
final double p1 = radians(latInput);
final double l1 = radians(longInput);
  
  tz.initializeTimeZones();
final tz.Location localTZ = tz.getLocation(tzoneInput);
  final tz.TZDateTime  date0J2000 = tz.TZDateTime.utc(2000, 1, 1, 12, 0, 0);
  final tz.TZDateTime date0 = tz.TZDateTime(localTZ,yearInput,1,1,0,0,0);
  final int nDays = date0.copyWith(year: date0.year + 1).difference(date0J2000).inDays;
  final initialOffsetHours = date0.difference(date0J2000).inHours;

  final List<double> yearJ2000OffsetsHours = List.generate(nDays * 24 * 4, (i) => initialOffsetHours + i/4); // List of offsets in hours from J2000 for each 15-minute interval of the year
  final List<double> yearMeanAnomalies = yearJ2000OffsetsHours.map((offset) => (tMeanAnomalyAtEpoch + (2 * pi) * (offset / (yearLength * 24))).remainder(2 * pi)).toList();
  print(yearMeanAnomalies); // Mean anomaly for each time step
}