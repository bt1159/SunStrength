// ^\s*print\([\s\S]*?\);\r?\n?
// flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sun_strength_app/archive/shape_render.dart';
import 'package:sun_strength_app/archive/shapes.dart';
import 'package:sun_strength_app/archive/shape_list_cn.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    print('running build in MyApp');
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const ShapeListExposer(),
    );
  }
}

class ShapeListExposer extends StatelessWidget {
  const ShapeListExposer({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ShapeListCN>(
      create: (context) => ShapeListCN.empty(),
      child: _VizPanel(),
    );
  }
}

class _VizPanel extends StatefulWidget {
  const _VizPanel();

  @override
  State<_VizPanel> createState() => _VizPanelState();
}

class _VizPanelState extends State<_VizPanel> {
  // List<ThreeDShapeObject> shapes = <ThreeDShapeObject>[];
  double nextX = 0;
  double nextAngle = 0; // 1. Store the cumulative rotation of your 3D world
  v.Quaternion _canvasOrientation = v.Quaternion.identity();
  late v.Quaternion _startOrientation;
  bool _isMenuOpen = false;
  Uuid? _selectedShapeID;

  v.Quaternion get __canvasOrientation => _canvasOrientation;

  set __canvasOrientation(v.Quaternion input) {
    if (input == __canvasOrientation) {
      print('in __canvasOrientation setter, input is the same');
      return;
    }
    final v.Quaternion clone = __canvasOrientation.clone();
    _canvasOrientation = input;
    context.read<ShapeListCN>().updateCanvasOrientation(input);
    print(
      'finished __canvasOrientation setter with a new value.  was: $clone, now $_canvasOrientation',
    );
  }

  ThreeDShapeObject get _selectedShape => context
      .read<ShapeListCN>()
      .shapes
      .firstWhere((element) => element.id == _selectedShapeID);

  // These state variables store information about the current drag event.
  // Every time a new drag starts, these are overwritten.
  Offset? _dragStartPointHidden;
  Offset? get _dragStartPoint => _dragStartPointHidden;
  set _dragStartPoint(Offset? input) {
    if (input == _dragStartPoint) return;
    _dragStartPointHidden = input;
    if (_canvasSize != null && _dragStartPointHidden != null) {
      vecStart = _projectToSphere(input!, _canvasSize!);
    }
  }

  Size? _canvasSizeHidden;
  Size? get _canvasSize => _canvasSizeHidden;
  set _canvasSize(Size? input) {
    if (input == _canvasSize || input == null) return;
    _canvasSizeHidden = input;
    if (_canvasSizeHidden != null && _dragStartPoint != null) {
      vecStart = _projectToSphere(_dragStartPoint!, input);
    }
  }

  v.Vector3? vecStart;

  // Helper: Map 2D screen coordinate to 3D unit vector on your virtual sphere
  v.Vector3 _projectToSphere(Offset localPosition, Size canvasSize) {
    // Standardize coordinates so center of canvas is (0,0) and radius is 1.0
    final double x =
        (2.0 * localPosition.dx - canvasSize.width) / canvasSize.width;
    final double y =
        (2.0 * localPosition.dy - canvasSize.height) /
        canvasSize.height; // Invert Y

    final double lengthSquared = x * x + y * y;

    if (lengthSquared <= 1.0) {
      // Point is inside the sphere
      return v.Vector3(x, y, sqrt(1.0 - lengthSquared));
    } else {
      // Point is outside the sphere, project to closest edge
      final double length = sqrt(lengthSquared);
      return v.Vector3(x / length, y / length, 0.0);
    }
  }

  void _addRectPrism() {
    final RectPrism newRect = RectPrism(
      size: v.Vector3(100, 100, 100),
      inputLoc: v.Vector3(nextX, 0, 0),
      inputCanvasRotAxis: __canvasOrientation.axis,
      inputCanvasRotAngle: __canvasOrientation.radians,
    );
    print(
      'just created shape, but have not added to shapes yet.  in new shape, canvasRot: ${newRect.canvasRot}',
    );
    context.read<ShapeListCN>().addShape(newRect);
  }

  void updateSelectedShapeID(Uuid? newID, {bool queue = false}) =>
      setState(() => _selectedShapeID = newID);

  void updateSelectedShapeColor(Color newColor, {bool queue = false}) {
    _selectedShape.color = newColor;
  }

  @override
  void initState() {
    super.initState();

    // Since calling _addRectPrism will trigger ShapeListCN's notifyListeners()
    // method, and that will mark all this dirty, that cannot be done WHILE this
    // frame is building.  The fix, as you see below, is the register the call
    // to be done immediately after this frame is finished building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addRectPrism();
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
      'running build in _MyHomePageState, shapes.length: ${context.read<ShapeListCN>().shapes.length}',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('3D Visualization'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _isMenuOpen = !_isMenuOpen;
            });
          },
        ),
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _isMenuOpen ? 240.0 : 0.0,
            child: ClipRect(
              // Prevents text overflow during animation
              child: OverflowBox(
                alignment: Alignment.topRight,
                minWidth: 240.0,
                maxWidth: 240.0,
                child: Material(
                  color: Colors.grey[200],
                  child: Consumer<ShapeListCN>(
                    builder: (context, shapeListCN, child) => ListView(
                      children: [
                        ExpansionTile(
                          title: Text('Shape list'),
                          children: [
                            for (final ThreeDShapeObject shape
                                in shapeListCN.shapes)
                              ShapeListItem(
                                shape: shape,
                                updateSelectedShapeID: updateSelectedShapeID,
                              ),
                          ],
                        ),
                        ExpansionTile(
                          title: Text('Add a shape'),
                          children: [
                            TextButton(
                              onPressed: () {
                                final shape = RectPrism(
                                  size: v.Vector3(100, 100, 100),
                                  inputLoc: v.Vector3(0, 0, 0),
                                  inputCanvasRotAxis: __canvasOrientation.axis,
                                  inputCanvasRotAngle:
                                      __canvasOrientation.radians,
                                );
                                showDialog(
                                  context: context,
                                  barrierDismissible:
                                      true, // Allows clicking outside to close
                                  builder: (BuildContext dialogContext) =>
                                      RectPrismSettingsDialog(
                                        shape: shape,
                                        newShape: true,
                                      ),
                                );
                                context.read<ShapeListCN>().addShape(shape);
                              },
                              child: Text('Add a Rectangular Prism'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // Container(
                //   height: 50,
                // ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    _canvasSize = Size(constraints.maxWidth, 800);
                    print('_canvasSize: $_canvasSize');

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => print('triggered onTap'),
                      // A. User clicks down: Record the initial "from" point
                      onPanStart: (details) {
                        print('running onPanStart');
                        _dragStartPoint = details.localPosition;
                        _startOrientation = __canvasOrientation.clone();
                      },

                      // B. User drags: Calculate delta rotation and update the "from" point
                      onPanUpdate: (details) {
                        print('running onPanUpdate');
                        if (_dragStartPoint == null || vecStart == null) return;

                        final Offset currentPoint = details.localPosition;
                        final v.Vector3 vecCurrent = _projectToSphere(
                          currentPoint,
                          _canvasSize!,
                        );

                        // Calculate rotation directly from the start point to the current point
                        final v.Quaternion deltaRotation =
                            v.Quaternion.fromTwoVectors(vecStart!, vecCurrent);

                        print(
                          'inside onPanUpdate.  About to set a new value for __canvasOrientation.  Current value: $__canvasOrientation, current stateVersion, ${context.read<ShapeListCN>().stateVersion}',
                        );
                        // setState(() {
                        // Pre-multiply to rotate relative to the camera/screen space
                        __canvasOrientation =
                            (_startOrientation * deltaRotation).normalized();

                        print(
                          'inside onPanUpdate.  New value: $__canvasOrientation, current stateVersion, ${context.read<ShapeListCN>().stateVersion}',
                        );
                        // });
                      },

                      // C. User lets go: Clear the tracking point
                      onPanEnd: (_) {
                        _dragStartPoint = null;
                      },
                      onPanCancel: () {
                        _dragStartPoint = null;
                      },
                      child: Consumer<ShapeListCN>(
                        builder: (context, shapeListCN, child) {
                          print(
                            'about to Create CanvasWidget with stateVersion: ${shapeListCN.stateVersion}',
                          );
                          return CanvasWidget(
                            shapes: shapeListCN.shapes,
                            selectedShapeID: _selectedShapeID,
                            shapeListVersion: shapeListCN.stateVersion,
                          );
                        },
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AutoRepeatButton(
                      onStep: () {
                        print('running onStep');
                        final ThreeDShapeObject shape = context
                            .read<ShapeListCN>()
                            .shapes
                            .first;
                        if (shape is RectPrism) {
                          shape.incrementRotGlobalX(
                            rotationAngle: -5 * (pi / 180),
                          );
                        }
                      },
                      child: Text('Rotate cube down a little'),
                    ),
                    AutoRepeatButton(
                      onStep: () {
                        print('running onStep');
                        final ThreeDShapeObject shape = context
                            .read<ShapeListCN>()
                            .shapes
                            .first;
                        if (shape is RectPrism) {
                          shape.incrementRotGlobalY(
                            rotationAngle: 5 * (pi / 180),
                          );
                        }
                      },
                      child: Text('Rotate cube left a little'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        print('running onStep');
                        final ThreeDShapeObject shape = context
                            .read<ShapeListCN>()
                            .shapes
                            .first;
                        if (shape is RectPrism) {
                          shape.localRot = v.Quaternion.axisAngle(
                            v.Vector3(1, 1, 1).normalized(),
                            0,
                          );
                        }
                      },
                      child: Text('Reset cube'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // setState(() {
                        __canvasOrientation = v
                            .Quaternion.identity(); // Prevent floating-point drift over time
                        // });
                      },
                      child: Text('Reset view'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShapeListItem extends StatelessWidget {
  const ShapeListItem({
    super.key,
    required this.shape,
    required this.updateSelectedShapeID,
  });

  final ThreeDShapeObject shape;
  final void Function(Uuid? newID) updateSelectedShapeID;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        return updateSelectedShapeID(shape.id);
      },
      onExit: (_) => updateSelectedShapeID(null),
      child: ListTile(
        leading: Icon(Icons.square, color: shape.color),
        title: Text(shape.shapeType.toString()),
        onTap: () => showDialog(
          context: context,
          barrierDismissible: true, // Allows clicking outside to close
          builder: (BuildContext dialogContext) => shape is RectPrism
              ? RectPrismSettingsDialog(
                  shape: shape as RectPrism,
                  newShape: false,
                )
              : Text(
                  'Shape is not RectPrism, which means it does not yet have a settings window created',
                ),
        ),
      ),
    );
  }
}

// TODO: This is actually only built for a RectPrism.  That needs to get fixed
// at some point
class RectPrismSettingsDialog extends StatefulWidget {
  const RectPrismSettingsDialog({
    super.key,
    required this.shape,
    required this.newShape,
  });

  final RectPrism shape;
  final bool newShape;

  @override
  State<RectPrismSettingsDialog> createState() =>
      _RectPrismSettingsDialogState();
}

// TODO: Change default values for X, Y, and Z editor fields so that they show
//the current shape's size istead of looking blank.
class _RectPrismSettingsDialogState extends State<RectPrismSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  double? _sliderValue;
  double? _lengthX;
  double? _lengthY;
  double? _lengthZ;
  double? _locX;
  double? _locY;
  double? _locZ;

  String? _validateSize(String? value) {
    print('running validator with value: $value');
    if (value == null || value.isEmpty) {
      print('value is null or field is empty.  That is ok');
      return null;
    }
    print('about to try to parse as double');
    final double? n = double.tryParse(value);
    if (n == null || n <= 0) {
      print('value not parsed or parsed at or below 0');
      return 'Must be > 0';
    }
    print('value parsed to positive double.  all good.');
    return null; // Return null means the input is perfectly valid
  }

  String? _validateLocation(String? value) {
    print('running validator with value: $value');
    if (value == null || value.isEmpty) {
      print('value is null or field is empty.  That is ok');
      return null;
    }
    print('about to try to parse as double');
    final double? n = double.tryParse(value);
    if (n == null) {
      print('value not parsed');
      return 'Must be > 0';
    }
    print('value parsed to positive double.  all good.');
    return null; // Return null means the input is perfectly valid
  }

  void _submitData() {
    print('starting submitData');
    final FormState? form = _formKey.currentState;
    print('about to check if form is non-null and then if validation passes');
    if (form != null && form.validate()) {
      print('validation passed.  now about to save');
      // Trigger 'onSaved' on every FormField inside the form
      form.save();

      v.Vector3? newLoc;

      if ((_locX ?? _locY ?? _locZ) != null) {
        final v.Vector3 currentLoc = widget.shape.loc;
        newLoc = v.Vector3(
          _locX ?? currentLoc.x,
          _locY ?? currentLoc.y,
          _locZ ?? currentLoc.z,
        );
        if (newLoc == currentLoc) newLoc = null;
      }

      final RectPrismSettings settings = RectPrismSettings(
        lengthX: _lengthX,
        lengthY: _lengthY,
        lengthZ: _lengthZ,
        loc: newLoc,
        color: _sliderValue == null
            ? null
            : HSLColor.fromAHSL(1, _sliderValue!, 1, 0.5).toColor(),
      );
      widget.shape.updateSettings(settings);
    }
  }

  @override
  Widget build(BuildContext setDialogState) {
    print('building _RectPrismSettingsDialogState');
    return AlertDialog(
      title: Text('${widget.shape.shapeType.typeName} Settings'),
      content: SizedBox(
        width: 400, // Sets a fixed width so it doesn't span the screen
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize
                .min, // Forces the dialog to wrap height-wise around content
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Size',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Row(
                children: [
                  // X Dimension
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.shape.size.x.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Length X',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        signed: false,
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) => _validateSize(value),
                      onSaved: (value) {
                        if (value == null) {
                          _lengthX = null;
                        } else {
                          _lengthX = double.tryParse(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12), // Space between boxes
                  // Y Dimension
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.shape.size.y.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Length Y',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        signed: false,
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) => _validateSize(value),
                      onSaved: (value) {
                        if (value == null) {
                          _lengthY = null;
                        } else {
                          _lengthY = double.tryParse(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Z Dimension
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.shape.size.z.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Length Z',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        signed: false,
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) => _validateSize(value),
                      onSaved: (value) {
                        if (value == null) {
                          _lengthZ = null;
                        } else {
                          _lengthZ = double.tryParse(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Row(
                children: [
                  // X Location
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.shape.loc.x.toString(),
                      decoration: const InputDecoration(
                        labelText: 'X',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
                      ],
                      validator: (value) => _validateLocation(value),
                      onSaved: (value) {
                        if (value == null) {
                          _locX = null;
                        } else {
                          _locX = double.tryParse(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12), // Space between boxes
                  // Y Location
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.shape.loc.y.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Y',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
                      ],
                      validator: (value) => _validateLocation(value),
                      onSaved: (value) {
                        if (value == null) {
                          _locY = null;
                        } else {
                          _locY = double.tryParse(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Z Location
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.shape.loc.z.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Z',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
                      ],
                      validator: (value) => _validateLocation(value),
                      onSaved: (value) {
                        if (value == null) {
                          _locZ = null;
                        } else {
                          _locZ = double.tryParse(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              FormField<double>(
                initialValue: HSLColor.fromColor(widget.shape.color).hue,
                validator: (value) {
                  if (value == null || value < 0 || value > 360) {
                    return 'Value must be between 0 and 360';
                  }
                  return null;
                },
                onSaved: (value) {
                  if (value != null) {
                    _sliderValue = value; // Saves straight into your variable
                  }
                },
                builder: (FormFieldState<double> sliderState) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackShape: const RectangularSliderTrackShape(),
                                trackHeight: 6.0,
                                activeTrackColor: Colors.grey[300],
                                inactiveTrackColor: Colors.grey[300],
                              ),
                              child: Slider(
                                min: 0,
                                value: sliderState.value ?? 0.0,
                                max: 360,
                                onChanged: (newValue) =>
                                    sliderState.didChange(newValue),
                              ),
                            ),
                            if (sliderState.hasError)
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Text(
                                  sliderState.errorText ?? '',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Container(
                          decoration: BoxDecoration(
                            color: HSLColor.fromAHSL(
                              1,
                              sliderState.value ?? 0,
                              1,
                              0.5,
                            ).toColor(),
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // Optional rounded corners
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1,
                            ), // Optional border outline
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => _formKey.currentState?.reset(),
          child: const Text('Reset all'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(), // Closes the modal
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            _submitData();
            Navigator.of(context).pop();
          },
          child: widget.newShape
              ? const Text('Add Shape')
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

class AutoRepeatButton extends StatefulWidget {
  final VoidCallback onStep; // Called on single click & each repeat step
  final Widget child;

  const AutoRepeatButton({
    super.key,
    required this.onStep,
    required this.child,
  });

  @override
  State<AutoRepeatButton> createState() => _AutoRepeatButtonState();
}

class _AutoRepeatButtonState extends State<AutoRepeatButton> {
  Timer? _delayTimer;
  Timer? _periodicTimer;

  // Configuration variables
  final Duration _initialDelay = const Duration(milliseconds: 500); // Wait 0.5s
  final Duration _repeatInterval = const Duration(
    milliseconds: 16,
  ); // ~60 FPS ticks

  void _startPress() {
    print('running _startPress');
    // 1. Immediately do one single step
    widget.onStep();

    // 2. Schedule the delay before auto-repeating begins
    _delayTimer = Timer(_initialDelay, () {
      print('started _intialDelay');
      // 3. Start the continuous loop
      _periodicTimer = Timer.periodic(_repeatInterval, (timer) {
        print('started _periodicTimer');
        widget.onStep();
      });
    });
  }

  void _stopPress() {
    print('running _stopPress');
    // Clean up all active timers to prevent memory leaks or running in background
    _delayTimer?.cancel();
    _periodicTimer?.cancel();
  }

  @override
  void dispose() {
    _stopPress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _startPress(),
      onPointerUp: (_) => _stopPress(),
      onPointerCancel: (_) => _stopPress(),
      child: Material(
        // 1. Give it elevation & a physical shadow
        elevation: 2.0,
        // 2. Color of an ElevatedButton (Standard Indigo/Primary)
        color: Theme.of(context).colorScheme.primary,
        // 3. Rounded corners standard to ElevatedButton
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          // We use InkWell purely for the press ripple effect
          borderRadius: BorderRadius.circular(20),
          onTap: () {}, // Empty tap callback so the ripple triggers
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: DefaultTextStyle(
              style: TextStyle(
                // White/onPrimary text color
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}