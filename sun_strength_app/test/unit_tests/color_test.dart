// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:color_map/color_map.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:vector_math/vector_math_64.dart';

void main() {
  // The function passed to setUp will be run one time before each test().
  // If it is called within a group, it applies only to tests within that group.
  // I'm not sure if that means that it is only called once per group or not.
  // It seems likely.  Also, the body will always be called AFTER anything in
  // the top level and anything in a parent group.
  setUp(() {});

  // A group of tests.  First parameter is any object used as a description.
  // Second is the function body of the group of tests.  if skip is a string,
  // the group will be skipped and it will do something with that string.
  // It must print it or log it or something.  So, skip should be an explanation
  // for why it skipped.  If skip is a bool, true, it will skip without logging.
  // If it is anything else, it will not skip.  IT IS NOT TREATED AS TRUTHY.
  // Retry is an int that defines the number of times to retry the group before
  // considering it a failure.
  group('Color map test group:', () {
//     Color colorTest(double strength) {
//       final Colormap colorMap = Colormaps.inferno;
//       final Vector4 vector = colorMap(strength);
//       final double ad = vector.w;
//       final double rd = vector.x;
//       final double gd = vector.y;
//       final double bd = vector.z;
//       final int a = (vector.w * 255).toInt();
//       final int r = (vector.x * 255).toInt();
//       final int g = (vector.y * 255).toInt();
//       final int b = (vector.z * 255).toInt();
//       final Color output = Color.fromARGB(
//         vector.w.toInt(),
//         vector.x.toInt(),
//         vector.y.toInt(),
//         vector.z.toInt(),
//       );

//       expect(a, isA<int>());
//       expect(r, isA<int>());
//       expect(g, isA<int>());
//       expect(b, isA<int>());
//       expect(output, isA<Color>());

//       expect(a >= 0 && a <= 255, isTrue);
//       expect(r >= 0 && a <= 255, isTrue);
//       expect(g >= 0 && a <= 255, isTrue);
//       expect(b >= 0 && a <= 255, isTrue);
//       print('ad: $ad');
//       print('rd: $rd');
//       print('gd: $gd');
//       print('bd: $bd');
//       print('a: $a');
//       print('r: $r');
//       print('g: $g');
//       print('b: $b');
//       print('output: $output');
//       return output;
//     }

// Uint8List pixelByte(double strength) {
//   final Color color = colorTest(strength);
//   print('color: $color');
//   final Uint8List output = Uint8List(4);
//   final int r = color.r.toInt(); // R
//   final int g = color.g.toInt(); // G
//   final int b = color.b.toInt();

//   print('r:$r');
//   print('g:$g');
//   print('b:$b');

//   output[0] = color.r.toInt(); // R
//   output[1] = color.g.toInt(); // G
//   output[2] = color.b.toInt(); // B
//   output[3] = 255; // A (Opaque)
//   print('output: $output');
//   return output;
// }

    // An actual test to run.  First is description, like for group().  Next is
    // the test body, like for group().  It also has named skip and retry, like
    // for group, but I am not taking the time to define those here.
    // test('**Color map values 0.25**', () => colorTest(0.25));
    // test('**Color map values 0.5**', () => colorTest(0.5));
    // test('**Color map values 0.75**', () => colorTest(0.75));
//     test('**color map test 0.5**', () {
// pixelByte(0.5, true);
//       expect(true, isTrue);
//       return true;
//     });
  });
}
