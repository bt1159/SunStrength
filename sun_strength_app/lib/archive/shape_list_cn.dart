import 'package:flutter/material.dart';
import 'package:sun_strength_app/archive/shapes.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// {@template ShapeListCN}
///
/// [ChangeNotifier] that holds and manages the list of shapes, List of
/// [ThreeDShapeObject] used by the entire app.  This should be the
/// only/primary place where that list and the shapes inside it are modified,
/// managed, etc.
///
/// Since a [ChangeNotifierProvider] is placed near the top of the app, any
/// objects that need access to the full list or even just one shape can use
/// [Consumer] or [Selector] or any other type of [Listener] and therefore
/// always have the latest version.
///
/// One important note: at this time, [ThreeDShapeObject] is NOT immutable.
/// At this time, it seems like it may be useful to keep these shapes in memory
/// and use their id property to understand identity.  Also, those shapes are
/// passed this object's [ShapeListCN.notifyListeners] method.  That way,
/// whenever a shape is modified in a way that might require a re-build or
/// re-paint, that shape can for all listeners of this object.
///
/// With the mutability and this triggering, however, when a listener is
/// alerted to a change, it will already have access to the updated shape.
/// Remember that, when listening and using this list, the listeners are passed
/// a reference to the root object, not a copy of it.  This is not necessarily a
/// problem, and the listeners still need that trigger, otherwise, they will not
/// know that the shape has been changed and they need to rebuild.  The key is,
/// however, that if the listener does any kind of logic to check for what has
/// changed, and for instance, compares the new shape to the one it already has
/// in memory, they will match.  This could, if the code is written this way,
/// lead to the listener not being rebuilt even though it does actually need to.
///
/// All of the above is the reason for the [_stateVersion] property.  Since that
/// property is an [int], it cannot be passed by reference in Dart.  If any
/// listener, therefore, wants to check if it currently is built with the latest
/// version of the list/shape, it can check its [_stateVersion] against this
/// object's.  If they do not match, it should indeed rebuild.
///
/// Note that this object is completely unaware of which shape is selected.
/// That logic is held by [_VizPanelState].  When a shape's paint method is
/// called, a [bool] is passed indicating whether that shape is currently
/// selected.
///
/// {@endtemplate}
class ShapeListCN extends ChangeNotifier {
  /// {macro ShapeListCN}
  ///
  /// The default constructor requires an input list of shapes.  This could,
  /// however, be an empty but modifiable list.
  ShapeListCN({required List<ThreeDShapeObject> shapes}) : _shapes = shapes;

  /// {@macro ShapeListCN}
  ///
  /// This constructor is used where the [ShapeListCN] will always be built
  /// without any shapes yet.  This constructor automatically creates an empty,
  /// modifiable list.
  ShapeListCN.empty() : _shapes = <ThreeDShapeObject>[];

  final List<ThreeDShapeObject> _shapes;

  /// Tracks the version of all the data in this CN collectively.  Any change to
  /// that data should augment this value.
  ///
  /// See comments for class for more details
  int _stateVersion = 0;

  /// Tracks the version of all the data in this CN collectively.  Any change to
  /// that data should augment this value.
  ///
  /// See comments for class for more details
  int get stateVersion => _stateVersion;

  @override
  void notifyListeners() {
    print('running notifyListeners inside ShapeListCN');
    super.notifyListeners();
  }

  List<ThreeDShapeObject> get shapes => List.unmodifiable(_shapes);

  void updateCanvasOrientation(v.Quaternion newOrientation) {
    print(
      'inside ShapeListCN.updateCanvasOrientation, newOrientation: $newOrientation',
    );
    for (final ThreeDShapeObject shape in _shapes) {
      shape.updateCanvasRotSilently(newOrientation);
    }
    print(
      'inside ShapeListCN.updateCanvasOrientation, finished updating each shape',
    );
    resortList();
    _stateVersion++;
    notifyListeners();
    print(
      'inside ShapeListCN.updateCanvasOrientation, just augmented _stateVersion: $_stateVersion and called notifyListeners',
    );
  }

  void addShape(ThreeDShapeObject shape) {
    shape.bindNotifier(() {
      _stateVersion++;
      notifyListeners();
    });
    shape.bindSorter(resortList);
    _shapes.add(shape);
    resortList();
    _stateVersion++;
    notifyListeners();
  }

  void removeShape(Uuid id) {
    final index = _shapes.indexWhere((s) => s.id == id);
    if (index != -1) {
      _shapes[index].bindNotifier(() {}); // Unbind callback
      _shapes.removeAt(index);
      resortList();
      _stateVersion++;
      notifyListeners();
    }
  }

  void resortList() {
    _shapes.sort(
      (a, b) =>
          ((b as RectPrism).geoCenter.z - (a as RectPrism).geoCenter.z).toInt(),
    );
  }
}