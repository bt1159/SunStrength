// import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:color_map/color_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'dart:ffi';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
// import 'dart:math';
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

final Colormap constColorMap = Colormaps.magma;
// final Colormap colormap = Colormaps.inferno;

/// Outputs a vector with four [double] values from 0 to 255 representing r, g, b, a.  [strength] must be between 0 and 1, inclusive.
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

Iterable<Iterable<double>> createRawMatrixData({
  required Iterable<double> valueIterable,
  required int nDays,
}) {
  final int nTimes = (valueIterable.length / nDays).toInt();
  final Iterable<Iterable<double>> output = Iterable.generate(nDays, (
    dayIndex,
  ) {
    final int start = dayIndex * nTimes;
    final int end = start + nTimes;
    return valueIterable.toList().sublist(start, end).reversed;
  });
  return output;
}

/// [Future] function that actually generates the sun strength chart image given the data point.  That image is actually returned
/// inside of an [ChartImageContainer].  This [Future] is called, received, and handled by [HeatMap].
///
/// The main work of this function is to receive the long, one-dimensional list of [double] sun strength values, reshape them into
/// the correct rows and columns, then convert them into the correct color bytes, and then create an [ui.Image] from that
/// two-dimensional list of color bytes.
///
/// Note: [orbitAndSolarValuesList] should be order as if it were a Iterable&ltIterable&ltdouble&gt&gt that has been flattened where each
/// inner list is a vertical column of pixels.  In those vertical lists of pixels, the bottom-most pixel is first.  The left-most
/// column of pixels is first.  This ordering is driven by the calculation of solar strength where the morning is at the bottom of
/// the chart.
Future<({ui.Image image, List<List<double>> rawMatrixData})>
generateColorImage({
  required List<OrbitAndSolarValues> orbitAndSolarValuesList,
  required int pixelWidth,
  Colormap? colormap,
  bool debug = false,
  bool chart = false,
}) async {
  print(
    'running generateColorMapImage, chronologicalSunStrength.length: ${orbitAndSolarValuesList.length}, pixelWidth: $pixelWidth, colormap: ${colormap == null ? 'null' : ColorMapPicker.getName(colormap)}}',
  );

  const int bytesPerPixel = 4; // RGBA
  final int pixelHeight = (orbitAndSolarValuesList.length / pixelWidth).toInt();

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
  for (final OrbitAndSolarValues orbitAndSolarValues in orbitAndSolarValuesList) {
    final double strength = orbitAndSolarValues.solarStrengthsLocalRelativeToGlobalMax;
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

  return (image: frame.image, rawMatrixData: rawMatrixData);
}

Future<ChartImageContainer> generateColorImageInContainer({
  required List<OrbitAndSolarValues> orbitAndSolarValuesList,
  required int pixelWidth,
  Colormap? colormap,
}) async {
  if (orbitAndSolarValuesList.length % pixelWidth != 0) {
    throw InvalidPixelWidth(
      pixelWidth: pixelWidth,
      iterableLength: orbitAndSolarValuesList.length,
    );
  }

  print('running generateColorImageInContainer, colormap: ${colormap == null ? 'null' : ColorMapPicker.getName(colormap)}}');

  final (:image, :rawMatrixData) = await generateColorImage(
    orbitAndSolarValuesList: orbitAndSolarValuesList,
    pixelWidth: pixelWidth,
    chart: true,
    colormap: colormap,
  );
  final ChartImageContainer output = ChartImageContainer(
    image: image,
    leapYear: pixelWidth == 366,
    rawMatrixData: rawMatrixData,
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
    required this.orbitalRadiusMag,
    required this.orbitalRadius,
    required this.earthRadius,
    required this.solarElevationAngle,
    required this.solarAzimuthAngle,
    required this.solarStrengthsLocalRelativeToGlobalMax,
  });

  OrbitAndSolarValues.strengthOnly({required this.solarStrengthsLocalRelativeToGlobalMax}):
    hOffsetFromJ2000 = 0,
    earthRotationAngle = 0,
    meanAnomaly = 0,
    eccentricAnomaly = 0,
    trueAnomaly = 0,
    orbitalRadiusMag = 0,
    orbitalRadius = Vector3.zero(),
    earthRadius = Vector3.zero(),
    solarElevationAngle = 0,
    solarAzimuthAngle = 0;

  final double hOffsetFromJ2000;
  final double earthRotationAngle;
  final double meanAnomaly;
  final double eccentricAnomaly;
  final double trueAnomaly;
  final double orbitalRadiusMag;
  final Vector3 orbitalRadius;
  final Vector3 earthRadius;
  final double solarElevationAngle;
  final double solarAzimuthAngle;
  final double solarStrengthsLocalRelativeToGlobalMax;
}

class DayIndexNotifier extends ValueNotifier<int?> {
  DayIndexNotifier(super.value);
}

/// {@template ImagePainter}
///
/// This widget takes an [ui.Image] object as an input actually "paints" that into a widget.
/// This way, this widget is given a canvas and a size and applies the [image] to that.
///
/// {@endtemplate}
class ImagePainter extends CustomPainter {
  final ui.Image? image;

  /// {@macro ImagePainter}
  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      // 1. Define the full bounds of the raw source image pixels
      final Rect src = Rect.fromLTWH(
        0,
        0,
        image!.width.toDouble(),
        image!.height.toDouble(),
      );

      // 2. Define the full layout bounds allocated to your CustomPaint (600x300)
      final Rect dst = Rect.fromLTWH(0, 0, size.width, size.height);

      // 3. Create a paint object.
      // Optional: Set filterQuality to determine how pixels blend when stretched
      final Paint paint = Paint()
        ..filterQuality = FilterQuality
            .medium; // Use .none for crisp pixel blocks, .medium for smooth blending

      // 4. Draw it stretched!
      canvas.drawImageRect(image!, src, dst, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    // Optimization: Only repaint if the image object has actually changed
    return oldDelegate.image != image;
  }
}

class CustomPathRibbonPainter extends CustomPainter {
  final List<Offset> points;
  final List<double> positiveStrengths;
  final Colormap colormap;
  final double strokeWidth;

  CustomPathRibbonPainter({
    required this.points,
    required this.colormap,
    required this.positiveStrengths,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('Running paint in CustomPathRibbonPainter, colormap: $colormap');
    if (points.length < 2) return;

    final double boundingCircleRadius = min(size.width, size.height) / 2;
    final Offset centerOffset = Offset(size.width / 2, size.height / 2);
    final List<Offset> vertices = [];
    final List<Color> vertexColors = [];

    final halfWidth = strokeWidth / 2;

    final List<Color> colors = positiveStrengths.map((strength) {
      final Vector4 colorVector = colorValuesFromMap(strength, false, colormap);
      final Color color = Color.fromARGB(
        colorVector.w.toInt(),
        colorVector.x.toInt(),
        colorVector.y.toInt(),
        colorVector.z.toInt(),
      );
      return color;
    }).toList();

    for (int i = 0; i < points.length - 1; i++) {
      // size
      final Offset p1 = (points[i]) * boundingCircleRadius + centerOffset;
      final Offset p2 = (points[i + 1]) * boundingCircleRadius + centerOffset;

      // Calculate direction and perpendicular unit normal vector
      final Offset dir = p2 - p1;
      final double dist = dir.distance;
      if (dist == 0) continue;

      final Offset normal = Offset(-dir.dy / dist, dir.dx / dist) * halfWidth;

      // Calculate 4 corners of the ribbon segment quad
      final Offset p1Left = p1 + normal;
      final Offset p1Right = p1 - normal;
      final Offset p2Left = p2 + normal;
      final Offset p2Right = p2 - normal;

      // Add 2 triangles for the quad (p1L, p1R, p2L) and (p2L, p1R, p2R)
      vertices.addAll([p1Left, p1Right, p2Left, p2Left, p1Right, p2Right]);

      // Assign colors corresponding to points i and i+1
      final Color c1 = colors[i];
      final Color c2 = colors[i + 1];
      vertexColors.addAll([c1, c1, c2, c2, c1, c2]);
    }

    final ui.Vertices rawVertices = ui.Vertices(
      VertexMode.triangles,
      vertices,
      colors: vertexColors,
    );

    // Single GPU draw call for the whole ribbon
    canvas.drawVertices(rawVertices, BlendMode.srcOver, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPathRibbonPainter oldDelegate) => true;
}

class OrbitAndSolarValuesListNotifier
    extends ValueNotifier<List<OrbitAndSolarValues>> {
  OrbitAndSolarValuesListNotifier(super.value);
}

const List<int> leapYears = [1996, 2004, 2008, 2012, 2016, 2020, 2024, 2028];

/// {@template PathMetricsGradientPainter}
/// CustomPainter that paints the multi-colored line for solar azimuth and strength.
///
/// Note: make sure to filter the path and strengths so that only positive strengths
/// and their associated paths are sent.  Otherwise, no error will occur, but it will
/// be inefficient.
///
/// {@endtemplate}
class PathMetricsGradientPainter extends CustomPainter {
  final Path path;
  final List<double> positiveStrengths;
  final Colormap colormap;

  PathMetricsGradientPainter({
    required this.path,
    required this.colormap,
    required this.positiveStrengths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final PathMetrics metrics = path.computeMetrics();

    // Loop though each contour where a contour goes from one time data point to the next
    for (final PathMetric metric in metrics) {
      final double startingStrength = positiveStrengths[metric.contourIndex];
      final double endingStrength = positiveStrengths[metric.contourIndex + 1];

      if (startingStrength < 0 && endingStrength < 0) continue;

      final double totalLength = metric.length;
      final double step = 2.0; // Resolution: 2px per step

      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..strokeCap = StrokeCap.round;

      // Loop through however many steps make up a single countour.  Each step will have a
      // constant color based on the fraction of the length of this contour of the start
      // of this step.
      for (double d = 0; d < totalLength; d += step) {
        final double nextD = (d + step).clamp(0.0, totalLength);

        // Calculate normalized fraction [0.0 to 1.0] along the curve length
        final double fraction = d / totalLength;
        final double strengthAtStep =
            lerpDouble(startingStrength, endingStrength, fraction) ??
            startingStrength;

        if (strengthAtStep < 0) continue;

        final Vector4 colorVector = colorValuesFromMap(strengthAtStep, false, colormap);
        final Color color = Color.fromARGB(
          colorVector.w.toInt(),
          colorVector.x.toInt(),
          colorVector.y.toInt(),
          colorVector.z.toInt(),
        );

        paint.color = color;

        // Extract segment geometry
        final Path segmentPath = metric.extractPath(d, nextD);
        canvas.drawPath(segmentPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PathMetricsGradientPainter oldDelegate) {
    // Optimization: Only repaint if the image object has actually changed
    final bool hasAnythingChanged =
        path != oldDelegate.path ||
        positiveStrengths != oldDelegate.positiveStrengths ||
        colormap != oldDelegate.colormap;
    return hasAnythingChanged;
  }
}

typedef TooltipInfo = ({
  Offset hoverBoxPosition,
  String tooltipText12,
  String tooltipText24,
});

class KNotifier extends ValueNotifier<double> {
  KNotifier([super.value = 2]);
}