// import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:color_map/color_map.dart';
import 'package:flutter/foundation.dart';
// import 'dart:ffi';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:math';
import 'package:sun_strength_app/models/errors.dart';

const kDebugMode = true;

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

final Colormap constColorMap = Colormaps.magma;
// final Colormap colormap = Colormaps.inferno;

// Outputs a vector with four [double] values from 0 to 255 representing r, g, b, a
Vector4 colorValuesFromMap(
  double strength, [
  bool debug = false,
  Colormap? colormap,
]) {
  // void colorTest(double strength) {
  final Colormap localColorMap = colormap ?? constColorMap;
  final Vector4 vector = localColorMap(strength);
  final double r = vector.x * 255;
  final double g = vector.y * 255;
  final double b = vector.z * 255;
  final double a = vector.w * 255;
  final Vector4 output = Vector4(r, g, b, a);
  if (debug) {
    print('a: $a');
    print('r: $r');
    print('g: $g');
    print('b: $b');
    print('output: $output');
  }
  return output;
}

Uint8List pixelByte(double strength, Colormap? colormap, [bool debug = false]) {
  if (debug) {
    print('starting color work for next pixel');
  }
  final Vector4 vector = colorValuesFromMap(strength, debug, colormap);
  if (debug) {
    print('vector: $vector');
  }
  final Uint8List output = Uint8List(4);
  final int r = vector.x.toInt(); // R
  final int g = vector.y.toInt(); // G
  final int b = vector.z.toInt(); // B
  if (debug) {
    print('r:$r');
    print('g:$g');
    print('b:$b');
  }

  output[0] = r; // R
  output[1] = g; // G
  output[2] = b; // B
  output[3] = 255; // A (Opaque)
  if (debug) {
    print('output: $output');
  }
  return output;
}

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
    MyColorScheme? colorScheme,
  }) : defaultYear = defaultYear ?? tz.TZDateTime.now(tz.UTC).year,
       twelveHour = twelveHour ?? true,
       colorScheme = colorScheme ?? colorSchemes.first;

  factory SavedAppSettings.fromSaved(SharedPreferences prefs) {
    Location? newDefaultLocation;
    tz.Location? newTZoneInput;
    bool twelveHour = true;
    int? newDefaultYear;
    MyColorScheme? newColorScheme;

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

    // Parse out colorScheme
    final String? savedColorSchemeJsonString = prefs.getString('colorScheme');
    if (savedColorSchemeJsonString != null) {
      newColorScheme = colorSchemes.firstWhereOrNull(
        (element) => element.$1 == savedColorSchemeJsonString,
      );
    }

    return SavedAppSettings(
      defaultLocation: newDefaultLocation,
      defaultTimeZone: newTZoneInput,
      twelveHour: twelveHour,
      defaultYear: newDefaultYear,
      colorScheme: newColorScheme,
    );
  }

  final Location? defaultLocation;
  final tz.Location? defaultTimeZone;
  final bool twelveHour;
  final int? defaultYear;
  final MyColorScheme colorScheme;

  @override
  String toString() =>
      'SavedAppSettings, defaultLocation: $defaultLocation, tZoneInput: $defaultTimeZone, twelveHour: $twelveHour, year: $defaultYear, colorScheme: $colorScheme)';

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
        other.defaultYear == defaultYear &&
        other.colorScheme == colorScheme;
  }

  @override
  int get hashCode => Object.hash(
    defaultLocation,
    defaultTimeZone,
    twelveHour,
    defaultYear,
    colorScheme,
  );
}

typedef TimedOrbitData =
    Iterable<({double earthRotationAngle, double trueAnomaly})>;

/// [Future] function that actually generates the sun strength chart image given the data point.  That image is actually returned
/// inside of an [ChartImageContainer].  This [Future] is called, received, and handled by [HeatMap].
///
/// The main work of this function is to receive the long, one-dimensional list of [double] sun strength values, reshape them into
/// the correct rows and columns, then convert them into the correct color bytes, and then create an [ui.Image] from that
/// two-dimensional list of color bytes.
///
/// Note: [valueIterable] should be order as if it were a Iterable&ltIterable&ltdouble&gt&gt that has been flattened where each
/// inner list is a vertical column of pixels.  In those vertical lists of pixels, the bottom-most pixel is first.  The left-most
/// column of pixels is first.  This ordering is driven by the calculation of solar strength where the morning is at the bottom of
/// the chart.
Future<ui.Image> generateColorImage({
  required Iterable<double> valueIterable,
  required int pixelWidth,
  Colormap? colormap,
  bool debug = false,
  bool chart = false,
}) async {
  final DateTime t0 = DateTime.now();
  print(
    'running generateColorMapImage, chronologicalSunStrength.length: ${valueIterable.length}, pixelWidth: $pixelWidth',
  );

  const int bytesPerPixel = 4; // RGBA
  final int pixelHeight = (valueIterable.length / pixelWidth).toInt();

  // 1. Allocate the final flat byte buffer upfront.
  final Uint8List pixelBuffer = Uint8List(
    pixelWidth * pixelHeight * bytesPerPixel,
  );
  print(
    'inside generateColorMap, just created pixelBuffer with length, ${pixelBuffer.length}',
  );
  final List<List<double>> rawMatrixData = List.generate(
    pixelWidth,
    (_) => List.filled(pixelHeight, 0.0),
  );
  print(
    'inside generateColorMap, just created rawMatrixData with length, ${rawMatrixData.length} and inside legnth: ${rawMatrixData.first.length}',
  );

  int horIndex = -1;
  int vertIndex = 0;

  // 2. Iterate once. This triggers the lazy evaluation item-by-item.
  // Memory overhead remains incredibly low because we don't store intermediate lists.
  for (double strength in valueIterable) {
    // For rawMatrixData, x will index the outer list, or day, and y will index each inner list, or time.
    if (vertIndex == 0) {
      horIndex++;
    }

    // Invert Y because ui.decodeImageFromPixels expects Y=0 at the TOP,
    // but your math treats midnight morning as the BOTTOM.
    int vertIndexReversed = pixelHeight - 1 - vertIndex;

    // Calculate the exact target starting byte in row-major order
    int targetByteIndex = (vertIndexReversed * pixelWidth + horIndex) * 4;
    // final bool debug = horIndex == (pixelWidth / 2).toInt();

    if (debug) {
      print(
        'about to overwrite pixels, strength: $strength, starting at targetByteIndex: $targetByteIndex',
      );
      print('about to setRange');
    }
    pixelBuffer.setRange(
      targetByteIndex,
      targetByteIndex + 4,
      pixelByte(strength, colormap, debug),
    );
    if (debug) {
      print('just setRange');
    }

    rawMatrixData[horIndex][vertIndexReversed] = strength;

    vertIndex++;

    if (vertIndex == pixelHeight) {
      vertIndex = 0;
    }
  }

  print(
    'inside generateColorMap, just finished assigning data to rawMatrixData and pixelBuffer',
  );

  // 3. Hand the perfectly ordered buffer over to the engine
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    pixelBuffer,
  );
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: pixelWidth,
    height: pixelHeight,
    pixelFormat: ui.PixelFormat.rgba8888,
  );

  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();

  // final DateTime t0 = DateTime.now();
  final DateTime tFinal = DateTime.now();
  print(
    'just finished generateColorImage${chart ? ' for the chart' : ''}, which took ${tFinal.difference(t0).inMilliseconds} milliseconds and started at $t0',
  );
  return frame.image;
}

Future<ChartImageContainer> generateColorImageInContainer({
  required Iterable<double> valueIterable,
  required int pixelWidth,
  Colormap? colormap,
}) async {
  final DateTime t0 = DateTime.now();
  if (valueIterable.length % pixelWidth != 0) {
    throw InvalidPixelWidth(
      pixelWidth: pixelWidth,
      iterableLength: valueIterable.length,
    );
  }
  final int cols = (valueIterable.length / pixelWidth).toInt();

  final ui.Image image = await generateColorImage(
    valueIterable: valueIterable,
    pixelWidth: pixelWidth,
    chart: true,
  );
  final DateTime t1 = DateTime.now();
  final List<List<double>> rawMatrixData = List.generate(
    pixelWidth,
    (i) => valueIterable.toList().sublist(i * cols, (i + 1) * cols),
  );
  // TODO: Something is wrong here.  The step above is taking a stupid 
  // long amount of time.  Like 14 seconds.  I don't know if it is the
  // whole subList() that is a problem or maybe the way I am setting 
  // up the Iterable.  I suspect that I am passing the full, 
  // uncalculated Iterable, then running through it to pull out solar
  // strength, then breaking it up.  I have to find a better way of 
  // doing that.  Although, even that shouldn't take this long.  It 
  // only takes about a second or so do the all the orbit and solar
  // calcs this first time!
  final DateTime t2 = DateTime.now();
  final ChartImageContainer output = ChartImageContainer(
    image: image,
    leapYear: pixelWidth == 366,
    rawMatrixData: rawMatrixData,
  );
  // final DateTime t0 = DateTime.now();
  final DateTime tFinal = DateTime.now();
  print(
    'just finished generateColorImageInContainer, which took ${tFinal.difference(t0).inMilliseconds} milliseconds and started at $t0.  t1: $t1, t2: $t2, tFinal: $tFinal',
  );
  return output;
}

// /// {@template ImageContainer}
// ///
// /// Lightweight wrapper widget that pairs an [ui.Image], [image], along with the data explaining whether
// /// this image is of a leap year, [leapYear], and also along with the raw data points, [rawMatrixData].
// ///
// /// [image] will get used by the [HeatMapPainter].  [rawMatrixData] will get passed to
// /// [ChartWidget] and used to fill out the hover text.
// ///
// /// {@endtemplate}
// class BasicImageContainer {
//   /// {@macro ImageContainer}
//   BasicImageContainer({
//     required this.image,
//   });

//   final ui.Image image;
// }

/// {@template ImageContainer}
///
/// Lightweight wrapper widget that pairs an [ui.Image], [image], along with the data explaining whether
/// this image is of a leap year, [leapYear], and also along with the raw data points, [rawMatrixData].
///
/// [image] will get used by the [HeatMapPainter].  [rawMatrixData] will get passed to
/// [ChartWidget] and used to fill out the hover text.
///
/// {@endtemplate}
class ChartImageContainer {
  /// {@macro ImageContainer}
  ChartImageContainer({
    required this.image,
    required this.leapYear,
    required this.rawMatrixData,
  });

  final ui.Image image;
  final bool leapYear;
  final List<List<double>> rawMatrixData;
}

abstract class ColorMapPicker {
  ColorMapPicker();

  static String getName(Colormap colormap) => colorSchemes
      .firstWhere(
        (element) => element.$2 == colormap,
        orElse: () => ('turbo', Colormaps.turbo),
      )
      .$1;

  static Colormap getMap(String? name) => colorSchemes
      .firstWhere(
        (element) => element.$1 == name,
        orElse: () => ('turbo', Colormaps.turbo),
      )
      .$2;
}

typedef MyColorScheme = (String name, Colormap colormap);
typedef MyColorSchemes = List<MyColorScheme>;
final MyColorSchemes colorSchemes = [
  ('turbo', Colormaps.turbo),
  ('gist_heat', Colormaps.gist_heat),
  ('hot', Colormaps.hot),
];

class CurrentIndexNotifier extends ValueNotifier<int> {
  CurrentIndexNotifier() : super(0);

  bool savedSettingsIsInitialized = false;

  @override
  set value(int newValue) => super.value = newValue.clamp(0, 1);
}

class OrbitAndSolarValues {
  const OrbitAndSolarValues({
    required this.hOffsetFromJ2000,
    required this.earthRotationAngle,
    required this.meanAnomaly,
    required this.eccentricAnomaly,
    required this.trueAnomaly,
    required this.orbitalRadius,
    required this.solarElevationAngle,
    required this.solarAzimuthAngle,
    required this.solarStrengthsLocalRelativeToGlobalMax,
  });

  final double hOffsetFromJ2000;
  final double earthRotationAngle;
  final double meanAnomaly;
  final double eccentricAnomaly;
  final double trueAnomaly;
  final double orbitalRadius;
  final double solarElevationAngle;
  final double solarAzimuthAngle;
  final double solarStrengthsLocalRelativeToGlobalMax;
}
