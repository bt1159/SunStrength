import 'package:vector_math/vector_math_64.dart' as v;
// import 'dart:developer';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:uuid/uuid.dart';

enum ShapeType {
  line('Line'),
  sphere('Sphere'),
  rectPrism('Rectangluar Prism');

  const ShapeType(this.typeName);

  final String typeName;

  @override
  String toString() => typeName;
}

v.Vector3 lightSource = v.Vector3(-0.5, -0.5, -1).normalized();
v.Vector3 outofScreen = v.Vector3(0, 0, -1);
Color defaultShapeColor = Color.fromARGB(255, 0, 0, 255);
Color highlightedColor = Color.fromARGB(255, 255, 255, 0);

// TODO: Currently, each shape is given _canvasRot.  Technically, this breaks
// "Don't repeat yourself", but it lets each shape calculate its vertices, and
// therefore faces inside the shape.  Otherwise, the shape would calculate its
// local vertices, and then those would get rotated again by the canvas.  My
// ASSUMPTION is that this is better performance.  This could be tested,
// becuase now when the canvasRot is updated, it has to trigger these recalc
// methods in each shape as opposed to doing all that math in one place.
abstract class ThreeDShapeObject {
  ThreeDShapeObject({
    required this.shapeType,
    v.Vector3? inputLocalRotAxis,
    double? inputLocalRotAngle,
    v.Vector3? inputCanvasRotAxis,
    double? inputCanvasRotAngle,
    v.Vector3? inputLoc,
    Color? inputColor,
  }) : id = Uuid(),
       _localRot =
           (inputLocalRotAxis == null ||
               inputLocalRotAngle == null ||
               inputLocalRotAngle.abs() < 1e-6 ||
               inputLocalRotAxis.length2 < 1e-6)
           ? v.Quaternion.identity()
           : v.Quaternion.axisAngle(inputLocalRotAxis, inputLocalRotAngle),
       _canvasRot =
           (inputCanvasRotAxis == null ||
               inputCanvasRotAngle == null ||
               inputCanvasRotAngle.abs() < 1e-6 ||
               inputCanvasRotAxis.length2 < 1e-6)
           ? v.Quaternion.identity()
           : v.Quaternion.axisAngle(inputCanvasRotAxis, inputCanvasRotAngle),
       _loc = inputLoc,
       _color = inputColor ?? defaultShapeColor;

  // static final Uuid _uuidGenerator = const Uuid();
  final Uuid id;
  final ShapeType shapeType;
  v.Quaternion _localRot;
  v.Quaternion _canvasRot;
  v.Vector3? _loc;
  Color? _color;
  void Function()? _onChanged;
  void Function()? _onNeedsSort;

  @mustCallSuper
  set color(Color input) {
    if (input == _color) return;
    _color = input;
    _onChanged?.call();
  }

  Color get color {
    _color ??= defaultShapeColor;
    return _color!;
  }

  @mustCallSuper
  set loc(v.Vector3 input) {
    if (input == _loc) return;
    _loc = input;
    _onNeedsSort?.call();
    _onChanged?.call();
  }

  v.Vector3 get loc {
    _loc ??= v.Vector3.zero();
    return _loc!;
  }

  @mustCallSuper
  set localRot(v.Quaternion input) {
    if (input == _localRot) return;
    _localRot = input;
    _onNeedsSort?.call();
    _onChanged?.call();
  }

  v.Quaternion get localRot {
    return _localRot;
  }

  @mustCallSuper
  set canvasRot(v.Quaternion input) {
    if (input == _canvasRot) return;
    _canvasRot = input;
    _onNeedsSort?.call();
    _onChanged?.call();
  }

  v.Quaternion get canvasRot {
    return _canvasRot;
  }

  @mustCallSuper
  void updateCanvasRotSilently(v.Quaternion input) {
    if (input == _canvasRot) {
      print(
        'inside shape.updateCanvasRotSilently, but input is the same as previous value',
      );
      return;
    }
    v.Quaternion clone = _canvasRot.clone();
    _canvasRot = input;
    print(
      'inside shape.updateCanvasRotSilently, and updated rotation.  was: $clone, now: $_canvasRot',
    );
  }

  v.Vector3 get geoCenter;

  void updateSettings(ShapeSettings settings);

  void bindNotifier(void Function() listener) {
    _onChanged = listener;
  }

  void bindSorter(void Function() sorter) {
    _onNeedsSort = sorter;
  }

  void paintShape({
    required Canvas canvas,
    required Offset flutterOffset,
    required double scale,
    required bool selected,
  });
}

class RectPrismSettings extends ShapeSettings {
  const RectPrismSettings({
    this.lengthX,
    this.loc,
    this.localRot,
    this.color,
    this.lengthY,
    this.lengthZ,
  });
  final double? lengthX;
  final double? lengthY;
  final double? lengthZ;
  final v.Vector3? loc;
  final v.Quaternion? localRot;
  final Color? color;
}

class RectPrism extends ThreeDShapeObject {
  RectPrism({
    v.Vector3? size,
    super.inputLocalRotAxis,
    super.inputLocalRotAngle,
    super.inputCanvasRotAxis,
    super.inputCanvasRotAngle,
    super.inputLoc,
    super.inputColor,
  }) : 
  _size = size,
  super(shapeType: ShapeType.rectPrism);

  double get lengthX => size.x;
  double get lengthY => size.y;
  double get lengthZ => size.z;

  v.Vector3? _size;

  set size(v.Vector3 input) {
    if (input == _size) return;
    _size = input;
    _onChanged?.call();
    _onNeedsSort?.call();
  }

  v.Vector3 get size {
    _size ??= v.Vector3.zero();
    return _size!;
  }

  set lengthX(double input) {
    if (input == lengthX) return;
    final v.Vector3 newSize = v.Vector3.copy(size);
    newSize.x = input;
    _size = newSize;
  }

  set lengthY(double input) {
    if (input == lengthY) return;
    final v.Vector3 newSize = v.Vector3.copy(size);
    newSize.y = input;
    _size = newSize;
  }

  set lengthZ(double input) {
    if (input == lengthZ) return;
    final v.Vector3 newSize = v.Vector3.copy(size);
    newSize.z = input;
    _size = newSize;
  }

  @override
  set loc(v.Vector3 input) {
    if (input == super.loc) return;
    markVerticesDirty();
    super.loc = input;
  }

  @override
  set localRot(v.Quaternion input) {
    if (localRot == input) return;
    markVerticesDirty();
    super.localRot = input;
  }

  @override
  set canvasRot(v.Quaternion input) {
    if (canvasRot == input) return;
    markVerticesDirty();
    super.canvasRot = input;
  }

  @override
  void updateCanvasRotSilently(v.Quaternion input) {
    markVerticesDirty();
    super.updateCanvasRotSilently(input);
  }

  void incrementRotGlobalX({required double rotationAngle}) {
    final v.Quaternion finalRot = v.Quaternion.axisAngle(
      v.Vector3(1, 0, 0),
      rotationAngle,
    );
    final v.Quaternion prevRot = localRot;
    localRot = prevRot * finalRot;
  }

  void incrementRotGlobalY({required double rotationAngle}) {
    final v.Quaternion finalRot = v.Quaternion.axisAngle(
      v.Vector3(0, 1, 0),
      rotationAngle,
    );
    final v.Quaternion prevRot = localRot;
    localRot = prevRot * finalRot;
  }

  void incrementRotGlobalZ({required double rotationAngle}) {
    final v.Quaternion finalRot = v.Quaternion.axisAngle(
      v.Vector3(0, 0, 1),
      rotationAngle,
    );
    final v.Quaternion prevRot = localRot;
    localRot = prevRot * finalRot;
  }

  @override
  void updateSettings(covariant RectPrismSettings settings) {
    print('starting RectPrism.updateSettings');
    bool changed = false;
    bool verticesNowDirty = false;

    if (settings.loc != null && settings.loc != loc) {
      print('settings.loc is not null and different.  About to update');
      _loc = settings.loc;
      changed = true;
      verticesNowDirty = true;
    }

    if (settings.lengthX != null ||
        settings.lengthY != null ||
        settings.lengthZ != null) {
      if (settings.lengthX != lengthX ||
          settings.lengthY != lengthY ||
          settings.lengthZ != lengthZ) {
        print(
          'at least one of settingss lengths is not null and is different.  About to update',
        );
        v.Vector3 newSize = v.Vector3(
          settings.lengthX ?? lengthX,
          settings.lengthY ?? lengthY,
          settings.lengthZ ?? lengthZ,
        );
        _size = newSize;
        changed = true;
        verticesNowDirty = true;
      }
    }

    if (settings.localRot != null && settings.localRot != localRot) {
      print('settings.localRot is not null and different.  About to update');
      _localRot = settings.localRot!;
      changed = true;
      verticesNowDirty = true;
    }

    if (settings.color != null && settings.color != color) {
      print('settings.color is not null and different.  About to update');
      _color = settings.color;
      changed = true;
    }

    if (changed) {
      if (verticesNowDirty) {
        print('in RectPrism.updateSettings, verticesNowDirty is true');
        markVerticesDirty();
        _onNeedsSort?.call();
      }
      print(
        'in RectPrism.updateSettings, changed is true, abgout to call onChanged()',
      );
      _onChanged?.call();
    }
  }

  v.Vector3? _vertex000;
  v.Vector3? _vertex100;
  v.Vector3? _vertex010;
  v.Vector3? _vertex110;
  v.Vector3? _vertex001;
  v.Vector3? _vertex101;
  v.Vector3? _vertex011;
  v.Vector3? _vertex111;

  v.Vector3 get vertex000 {
    if (_vertex000 == null) {
      _vertex000 = v.Vector3(-lengthX / 2, -lengthY / 2, -lengthZ / 2);
      _vertex000 = localRot.rotate(_vertex000!);
      _vertex000 = _vertex000! + loc;
      _vertex000 = canvasRot.rotate(_vertex000!);
    }
    return _vertex000!;
  }

  v.Vector3 get vertex100 {
    if (_vertex100 == null) {
      _vertex100 = v.Vector3(lengthX / 2, -lengthY / 2, -lengthZ / 2);
      _vertex100 = localRot.rotate(_vertex100!);
      _vertex100 = _vertex100! + loc;
      _vertex100 = canvasRot.rotate(_vertex100!);
    }
    return _vertex100!;
  }

  v.Vector3 get vertex010 {
    if (_vertex010 == null) {
      _vertex010 = v.Vector3(-lengthX / 2, lengthY / 2, -lengthZ / 2);
      _vertex010 = localRot.rotate(_vertex010!);
      _vertex010 = _vertex010! + loc;
      _vertex010 = canvasRot.rotate(_vertex010!);
    }
    return _vertex010!;
  }

  v.Vector3 get vertex110 {
    if (_vertex110 == null) {
      _vertex110 = v.Vector3(lengthX / 2, lengthY / 2, -lengthZ / 2);
      _vertex110 = localRot.rotate(_vertex110!);
      _vertex110 = _vertex110! + loc;
      _vertex110 = canvasRot.rotate(_vertex110!);
    }
    return _vertex110!;
  }

  v.Vector3 get vertex001 {
    if (_vertex001 == null) {
      _vertex001 = v.Vector3(-lengthX / 2, -lengthY / 2, lengthZ / 2);
      _vertex001 = localRot.rotate(_vertex001!);
      _vertex001 = _vertex001! + loc;
      _vertex001 = canvasRot.rotate(_vertex001!);
    }
    return _vertex001!;
  }

  v.Vector3 get vertex101 {
    if (_vertex101 == null) {
      _vertex101 = v.Vector3(lengthX / 2, -lengthY / 2, lengthZ / 2);
      _vertex101 = localRot.rotate(_vertex101!);
      _vertex101 = _vertex101! + loc;
      _vertex101 = canvasRot.rotate(_vertex101!);
    }
    return _vertex101!;
  }

  v.Vector3 get vertex011 {
    if (_vertex011 == null) {
      _vertex011 = v.Vector3(-lengthX / 2, lengthY / 2, lengthZ / 2);
      _vertex011 = localRot.rotate(_vertex011!);
      _vertex011 = _vertex011! + loc;
      _vertex011 = canvasRot.rotate(_vertex011!);
    }
    return _vertex011!;
  }

  v.Vector3 get vertex111 {
    if (_vertex111 == null) {
      _vertex111 = v.Vector3(lengthX / 2, lengthY / 2, lengthZ / 2);
      _vertex111 = localRot.rotate(_vertex111!);
      _vertex111 = _vertex111! + loc;
      _vertex111 = canvasRot.rotate(_vertex111!);
    }
    return _vertex111!;
  }

  List<v.Vector3> get vertices => [
    vertex000,
    vertex100,
    vertex010,
    vertex110,
    vertex001,
    vertex101,
    vertex011,
    vertex111,
  ];

  RectFace? _facePosX;
  RectFace? _faceNegX;
  RectFace? _facePosY;
  RectFace? _faceNegY;
  RectFace? _facePosZ;
  RectFace? _faceNegZ;

  RectFace get facePosX {
    _facePosX ??= RectFace(vertex100, vertex110, vertex111, vertex101);
    return _facePosX!;
  }

  RectFace get faceNegX {
    _faceNegX ??= RectFace(vertex000, vertex001, vertex011, vertex010);
    return _faceNegX!;
  }

  RectFace get facePosY {
    _facePosY ??= RectFace(vertex010, vertex011, vertex111, vertex110);
    return _facePosY!;
  }

  RectFace get faceNegY {
    _faceNegY ??= RectFace(vertex000, vertex100, vertex101, vertex001);
    return _faceNegY!;
  }

  RectFace get facePosZ {
    _facePosZ ??= RectFace(vertex001, vertex101, vertex111, vertex011);
    return _facePosZ!;
  }

  RectFace get faceNegZ {
    _faceNegZ ??= RectFace(vertex000, vertex010, vertex110, vertex100);
    return _faceNegZ!;
  }

  List<RectFace> get faces => [
    facePosX,
    faceNegX,
    facePosY,
    faceNegY,
    facePosZ,
    faceNegZ,
  ];

  @override
  v.Vector3 get geoCenter => (vertex000 + vertex100 + vertex111) / 3;

  void markFacesDirty() {
    print('marking faces dirty');
    _facePosX = null;
    _faceNegX = null;
    _facePosY = null;
    _faceNegY = null;
    _facePosZ = null;
    _faceNegZ = null;
  }

  void markVerticesDirty() {
    print('marking vertices dirty');
    _vertex000 = null;
    _vertex100 = null;
    _vertex010 = null;
    _vertex110 = null;
    _vertex001 = null;
    _vertex101 = null;
    _vertex011 = null;
    _vertex111 = null;
    markFacesDirty();
  }

  // Note: I am writing this in a way that assumes a convex shape.  I know that
  // a RectPrism is that, but if I adapt this for other shapes in the future, I
  // need to take that into account.
  @override
  void paintShape({
    required Canvas canvas,
    required Offset flutterOffset,
    required double scale,
    required bool selected,
  }) {
    final HSLColor baseColor = selected
        ? HSLColor.fromAHSL(1, 60, 1.0, 0.5)
        : HSLColor.fromColor(color);
    // Define the mininum HSL Lightness value
    final double ambient = 0.2;

    for (final RectFace face in faces) {
      final v.Vector3 normal = face.normal;
      final double intensity = v.dot3(lightSource, normal).clamp(0, 1);
      final bool visible = v.dot3(outofScreen, normal) > 0;
      if (!visible) continue;

      final double finalLightnessMultiplier =
          ambient + (intensity * (1 - ambient));
      final double finalLightness =
          (baseColor.lightness * finalLightnessMultiplier).clamp(0.0, 1.0);
      final double finalSaturation =
          (baseColor.saturation * (1.2 - (intensity * 0.2))).clamp(0.0, 1.0);
      final Color faceColor = baseColor
          .withLightness(finalLightness)
          .withSaturation(finalSaturation)
          .toColor();

      // Set the paint and draw the face path
      final paint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.fill;

      // 1. Initialize the path
      final Path localPath = Path();

      // 2. Define your 4 custom corners (clockwise or counter-clockwise)
      localPath.moveTo(face.p0.x, face.p0.y);
      localPath.lineTo(face.p1.x, face.p1.y);
      localPath.lineTo(face.p2.x, face.p2.y);
      localPath.lineTo(face.p3.x, face.p3.y);

      // 3. Close the path back to the starting point
      localPath.close();

      final Path globalPath = localPath.shift(flutterOffset);

      // 4. Draw it
      canvas.drawPath(globalPath, paint);
    }
  }
}

class RectFace {
  RectFace(this.p0, this.p1, this.p2, this.p3);

  v.Vector3 p0;
  v.Vector3 p1;
  v.Vector3 p2;
  v.Vector3 p3;

  v.Vector3 get normal {
    // Compute two spanning vectors
    final v1 = p1 - p0;
    final v2 = p2 - p0;
    final v.Vector3 output = (v1.cross(v2)).normalized();
    return output;
  }

  @override
  String toString() => 'p0: $p0, p1: $p1, p2: $p2, p3: $p3';
}

abstract class ShapeSettings {
  const ShapeSettings();
}