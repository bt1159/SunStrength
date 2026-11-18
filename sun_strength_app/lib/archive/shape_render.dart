import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:sun_strength_app/archive/shapes.dart';

class CanvasWidget extends LeafRenderObjectWidget {
  final List<ThreeDShapeObject> _shapes;
  final int _shapeListVersion;
  final Uuid? selectedShapeID;

  const CanvasWidget({
    super.key,
    required List<ThreeDShapeObject> shapes,
    required  int shapeListVersion,
    this.selectedShapeID,
  }) : _shapes = shapes,
  _shapeListVersion = shapeListVersion;

  @override
  Render3DCanvas createRenderObject(BuildContext context) {
    print('running createRenderObject');
    return Render3DCanvas(
      shapes: _shapes,
      selectedShapeID: selectedShapeID,
      shapeListVersion: _shapeListVersion,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant Render3DCanvas renderObject,
  ) {
    print('running updateRenderObject');
    renderObject.selectedShapeID = selectedShapeID;
    if (renderObject.shapeListVersion != _shapeListVersion) {
      print(
        'inside updateRenderObject and shapeListVersion is different, so render object will get new shapes list',
      );
      renderObject.replaceShapeList(
        newShapeListVersion: _shapeListVersion,
        newShapes: [..._shapes],
      );
    }
  }
}

class Render3DCanvas extends RenderBox {
  List<ThreeDShapeObject> _shapes;
  Uuid? _selectedShapeID;
  int _shapeListVersion;

  Render3DCanvas({
    required List<ThreeDShapeObject> shapes,
    Uuid? selectedShapeID,
    required int shapeListVersion,
  }) : _shapes = shapes,
  _selectedShapeID = selectedShapeID,
  _shapeListVersion = shapeListVersion;

  int get shapeListVersion => _shapeListVersion;

  List<ThreeDShapeObject> replaceShapeList({
    required int newShapeListVersion,
    required List<ThreeDShapeObject> newShapes,
  }) {
    if (newShapeListVersion == _shapeListVersion) return _shapes;
    _shapes = newShapes;
    _shapeListVersion = newShapeListVersion;
    markNeedsPaint();
    return _shapes;
  }

  set selectedShapeID(Uuid? newID) {
    if (_selectedShapeID == newID) return;
    _selectedShapeID = newID;
    markNeedsPaint();
  }

  @override
  void markNeedsPaint() {
    print('Render Object is running markNeedsPaint');
    super.markNeedsPaint();
  }

  @override
  double computeMinIntrinsicWidth(double height) => height;

  @override
  double computeMaxIntrinsicWidth(double height) => height;

  @override
  double computeMinIntrinsicHeight(double width) => width;

  @override
  double computeMaxIntrinsicHeight(double width) => width;

  @override
  void performLayout() {
    // 1. Grab the incoming constraints
    final BoxConstraints constraints = this.constraints;

    // 2. Determine your width based on constraints.
    // If width is infinite (unlikely in a standard column), fallback to a default (e.g., 200).
    double width = constraints.hasBoundedWidth ? constraints.maxWidth : 800.0;

    // 3. Force a 1:1 Aspect Ratio
    double height = 800;

    // 4. Handle the "Infinite Height" problem from the Column.
    // If the parent restricts height (e.g., maxHeight is 300, but our width was 500),
    // we must shrink to fit the smaller dimension to maintain 1:1 without overflowing.
    if (constraints.hasBoundedHeight && height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height; // Keep it 1:1
    }

    // 5. Use constraints.constrain() to ensure we respect min/max bounds perfectly
    size = constraints.constrain(Size(width, height));

    // 6. IMPORTANT: If your render object has children, layout them here!
    // child?.layout(BoxConstraints.tight(size), parentUsesSize: false);
  }

  // TODO: Add true 3D splitting or similar to correctly handle z-order
  @override
  void paint(PaintingContext context, Offset offset) {
    print('running paint');
    final canvas = context.canvas;

    final Offset flutterOffset = offset.translate(
      size.width / 2,
      size.height / 2,
    );

    //starting with no change in orientation
    for (final ThreeDShapeObject shape in _shapes) {
      // Currently not doing anything about z order
      if (shape is RectPrism) {
        shape.paintShape(
          canvas: canvas,
          flutterOffset: flutterOffset,
          scale: 1,
          selected: shape.id == _selectedShapeID,
        );
        print(
          'just painted a shape with canvas orientation: ${shape.canvasRot} and color: ${shape.color}',
        );
      } else {}
    }
  }
}