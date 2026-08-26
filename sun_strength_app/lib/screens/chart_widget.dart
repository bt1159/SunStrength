// flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
import 'dart:core';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sun_strength_app/models/errors.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:color_map/color_map.dart';

/// {@template PublicChartRenderObjectWidget}
/// Public Widget that constains the a [_ChartRenderObjectWidget] and also super imposes the hover tooltip when showing.
/// {@endtemplate}
class ChartWidget extends StatefulWidget {
  /// {@macro PublicChartRenderObjectWidget}
  const ChartWidget({
    super.key,
    required this.nXAxisBuckets,
    required this.nYAxisBuckets,
    required this.year,
    required this.timeZone,
  });

  final int nXAxisBuckets;
  final int nYAxisBuckets;
  final int year;
  final tz.Location timeZone;
  bool get leapYear => leapYears.contains(year);
  int get nDays => leapYear ? 366 : 365;

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  // Tooltip State Variables
  Offset? _hoverBoxPosition;
  String? _tooltipText12;
  String? _tooltipText24;
  static const Offset toolTipFormattingOffset = Offset(20, 20);

  void _handleChartHover(
    Offset chartTextLocalPosition,
    Size chartSize,
    Offset chartWidgetOffsetToParent,
    final Iterable<Iterable<double>> rawMatrixData,
  ) {
    final double x = chartTextLocalPosition.dx;
    final double y = chartTextLocalPosition.dy;

    // Calculate grid cell dimensions dynamically based on current layout size
    final double pxWidth = chartSize.width / widget.nDays;
    final double pxHeight = chartSize.height / 96;

    // Determine the exact row and column indices
    final int dayIndex = (x / pxWidth).floor().clamp(0, widget.nDays - 1);
    final int timeIndex = (96 - 1) - (y / pxHeight).floor().clamp(0, 96 - 1);

    // Look up data parameters safely.  First index is day, then time
    final double value = rawMatrixData.toList()[dayIndex].toList()[timeIndex];

    final int datetimeDelta =
        (((dayIndex * 24 * 60) + 15 * timeIndex) * 60 * 1000);
    final tz.TZDateTime hoverDateTimeRaw = tz.TZDateTime(
      widget.timeZone,
      widget.year,
    ).add(Duration(milliseconds: datetimeDelta));

    setState(() {
      _hoverBoxPosition =
          chartTextLocalPosition +
          chartWidgetOffsetToParent +
          toolTipFormattingOffset;
      _tooltipText12 =
          '${DateFormat('d MMM yyyy h:mm a').format(hoverDateTimeRaw)}\nValue: ${value.toStringAsFixed(2)}';
      _tooltipText24 =
          '${DateFormat('d MMM yyyy HH:mm').format(hoverDateTimeRaw)}\nValue: ${value.toStringAsFixed(2)}';
    });
  }

  void _hideTooltip() {
    if (_hoverBoxPosition != null) {
      setState(() {
        _hoverBoxPosition = null;
        _tooltipText12 = null;
        _tooltipText24 = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      'running _PublicChartRenderObjectWidgetState.build, ${_hoverBoxPosition == null ? '_hoverBoxPosition is null' : '_hoverBoxPosition is not null'}',
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Selector<SavedSettingsNotifier, bool>(
          selector: (_, savedSettingsNotifier) =>
              savedSettingsNotifier.value?.twelveHour ?? true,
          builder: (context, twelveHour, selectorSavedSettingsNotifierChild) =>
              _ChartRenderObjectWidget(
                nXAxisBuckets: widget.nXAxisBuckets,
                nYAxisBuckets: widget.nYAxisBuckets,
                twelveHour: twelveHour,
                leapYear: widget.leapYear,
                chartArrayWidget: selectorSavedSettingsNotifierChild!,
              ),
          child: GestureDetector(
            // onTapDown: (details) =>  ,
            onTapUp: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final double pxWidth = box.size.width / widget.nDays;
              final int dayIndex = (details.localPosition.dx / pxWidth)
                  .floor()
                  .clamp(0, widget.nDays - 1);
              context.read<DayIndexNotifier>().value = dayIndex;
            },
            child: Consumer<OrbitAndSolarValuesListNotifier>(
              builder: (context, orbitAndSolarValuesListNotifier, child) {
                return Selector<SavedSettingsNotifier, Colormap?>(
                  selector: (_, savedAppSettingsNotifier) =>
                      savedAppSettingsNotifier.value?.colorScheme.$2,
                  builder: (context, colormap, child) {
                    final Iterable<double> valueIterable =
                        orbitAndSolarValuesListNotifier.value.map(
                          (e) => e.solarStrengthsLocalRelativeToGlobalMax,
                        );
                    final int nDays = (valueIterable.length / 96).toInt();
                    final Iterable<Iterable<double>> rawMatrixData =
                        createRawMatrixData(
                          nDays: nDays,
                          valueIterable: valueIterable,
                        );
                    return MouseRegion(
                      onHover: (event) {
                        // Find the rendering size of the canvas dynamically
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final BoxParentData? boxParentData =
                            box.parentData as BoxParentData?;
                        _handleChartHover(
                          event.localPosition,
                          box.size,
                          boxParentData?.offset ?? Offset(0, 0),
                          rawMatrixData,
                        );
                      },
                      onExit: (_) => _hideTooltip(),
                      // child: widget.chartArrayWidget,
                      child: FutureBuilderChartImage(
                        orbitAndSolarValuesIterable:
                            orbitAndSolarValuesListNotifier.value,
                        colormap: colormap,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        // 2. The Floating Tooltip Popup Layer
        if (_hoverBoxPosition != null &&
            _tooltipText12 != null &&
            _tooltipText24 != null)
          Positioned(
            // Position it dynamically relative to the cursor position!
            left: _hoverBoxPosition!
                .dx, // Offset slightly to clear the cursor graphic
            top: _hoverBoxPosition!.dy,
            child: IgnorePointer(
              // Prevents the tooltip box from stealing mouse focus
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Selector<SavedSettingsNotifier, bool>(
                  selector: (_, savedSettingsNotifier) =>
                      savedSettingsNotifier.value?.twelveHour ?? true,
                  builder: (_, twelveHour, _) => Text(
                    twelveHour ? _tooltipText12! : _tooltipText24!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class FutureBuilderChartImage extends StatefulWidget {
  const FutureBuilderChartImage({
    super.key,
    required this.orbitAndSolarValuesIterable,
    this.colormap,
  });

  final List<OrbitAndSolarValues> orbitAndSolarValuesIterable;
  final Colormap? colormap;

  @override
  State<FutureBuilderChartImage> createState() =>
      _FutureBuilderChartImageState();
}

class _FutureBuilderChartImageState extends State<FutureBuilderChartImage> {
  late Future<ChartImageContainer> futureChartImage;

  /// The function that actually creates the 2D array of solar strength bytes.
  ///
  /// Note: k is the value that determines what wavelength of sunlight you are looking at:
  /// Visible: 0.22 <= k <= 0.36
  /// UV-A: 0.36 <= k <= 0.92
  /// UV-C: 2.3 <= k <= 4.6
  Future<ChartImageContainer> createChartImage() async {
    final int pixelH = 96;
    if (widget.orbitAndSolarValuesIterable.length % pixelH != 0) {
      throw InvalidPixelWidth(
        pixelWidth: pixelH,
        iterableLength: widget.orbitAndSolarValuesIterable.length,
      );
    }
    final int pixelW = (widget.orbitAndSolarValuesIterable.length / pixelH)
        .toInt();
    final Future<ChartImageContainer> output = generateColorImageInContainer(
      valueIterable: widget.orbitAndSolarValuesIterable.map(
        (e) => e.solarStrengthsLocalRelativeToGlobalMax,
      ),
      pixelWidth: pixelW,
      colormap: widget.colormap,
    );
    print('about to finish createImage');
    return output;
  }

  @override
  void initState() {
    super.initState();
    futureChartImage = createChartImage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChartImageContainer>(
      future: futureChartImage,
      builder:
          (BuildContext context, AsyncSnapshot<ChartImageContainer> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(), // Your spinner
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Snapshot Error: ${snapshot.error}'));
            }
            if (snapshot.hasData) {
              return CustomPaint(painter: ImagePainter(snapshot.data!.image));
            }
            if (snapshot.data == null) {
              return const Center(child: Text('No location selected'));
            } else {
              return const Center(child: Text('No Image'));
            }
          },
    );
  }
}

/// {@template PrivateChartRenderObjectWidget}
/// Widget that holds the solar strength chart including the 2D array and also the axis labels, gridlines, etc.
///
/// This is custom widget creats an element, [_ChartRenderObjectElement], and
/// a render object, [_ChartRenderObject].
///
/// [chartArrayWidget] is the Widget that contains just the 2D bit array.  [nXAxisBuckets] and [nYAxisBuckets]
/// are the number of buckets that the x and y axes are split into.  Note that there will be the same number of
/// x axis labels as buckets but the y axis will have one more label than bucket.
/// {@endtemplate}
class _ChartRenderObjectWidget
    extends SlottedMultiChildRenderObjectWidget<ChartSlot, RenderBox> {
  /// {@macro PrivateChartRenderObjectWidget}
  const _ChartRenderObjectWidget({
    required this.chartArrayWidget,
    required this.nXAxisBuckets,
    required this.nYAxisBuckets,
    required this.leapYear,
    required this.twelveHour,
  });

  final Widget chartArrayWidget;
  final int nXAxisBuckets;
  final int nYAxisBuckets;
  final bool leapYear;
  final bool twelveHour;

  @override
  Iterable<ChartSlot> get slots {
    return [
      ChartSlot.chartArray,
      ...Iterable.generate(nYAxisBuckets + 1, (i) => ChartSlot.yAxisLabel(i)),
      // Dynamically add a slot for every label provided
      ...Iterable.generate(nXAxisBuckets, (i) => ChartSlot.xAxisLabel(i)),
    ];
  }

  /// This is the method that ACTUALLY creates the widgets that get insterted into the tree.
  @override
  Widget childForSlot(ChartSlot slot) {
    if (slot == ChartSlot.chartArray) return chartArrayWidget;

    // Return a text widget for the specific index
    if (slot.id == 'yAxisLabel') {
      final String labelText =
          TimeLabelList.fromCountAndTwelveHour(
            nYAxisBuckets,
            twelveHour,
          )?.labelList[slot.index!] ??
          'BadYAxisCount';
      return Text(labelText, textAlign: TextAlign.right);
    }

    // Return a text widget for the specific index
    if (slot.id == 'xAxisLabel') {
      final String labelText =
          MonthLabelList.fromCount(nXAxisBuckets)?.labelList[slot.index!] ??
          'BadXAxisCount';
      return Text(labelText, textAlign: TextAlign.center);
    }

    throw ArgumentError('Unknown slot');
  }

  /// The [createRenderObject] and [updateRenderObject] methods configure the
  /// [RenderObject] backing this widget with the configuration of the widget.
  /// They do not need to do anything with the children of the widget, though.
  /// The children of the widget are automatically configured on the
  /// [RenderObject] by [SlottedRenderObjectElement.mount] and
  /// [SlottedRenderObjectElement.update].
  @override
  _ChartRenderObject createRenderObject(BuildContext context) {
    return _ChartRenderObject(
      nXAxisBuckets: nXAxisBuckets,
      nYAxisBuckets: nYAxisBuckets,
      leapYear: leapYear,
    );
  }

  /// The [createRenderObject] and [updateRenderObject] methods configure the
  /// [RenderObject] backing this widget with the configuration of the widget.
  /// They do not need to do anything with the children of the widget, though.
  /// The children of the widget are automatically configured on the
  /// [RenderObject] by [SlottedRenderObjectElement.mount] and
  /// [SlottedRenderObjectElement.update].
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ChartRenderObject renderObject,
  ) {
    renderObject.nXAxisBuckets = nXAxisBuckets;
    renderObject.nYAxisBuckets = nYAxisBuckets;
    renderObject.leapYear = leapYear;
  }

  @override
  _ChartRenderObjectElement createElement() {
    return _ChartRenderObjectElement(this);
  }
}

class _ChartRenderObjectElement
    extends SlottedRenderObjectElement<ChartSlot, RenderBox> {
  _ChartRenderObjectElement(_ChartRenderObjectWidget super.widget);

  @override
  void update(_ChartRenderObjectWidget newWidget) {
    super.update(newWidget);
  }
}

/// A custom [RenderBox] that is tied to a [_ChartRenderObjectWidget].
///
/// This RenderBox is the entire reason for this dart file.  It makes it possible to
/// compute the layouts for the various chart elements in parallel, making it much easier,
/// or even possible, to make the y axis labels line up correctly with the data, for instance.
/// Same with the x axis labels, and so on.
class _ChartRenderObject extends RenderBox
    with
        SlottedContainerRenderObjectMixin<ChartSlot, RenderBox>,
        DebugOverflowIndicatorMixin {
  _ChartRenderObject({
    required int nXAxisBuckets,
    required int nYAxisBuckets,
    required bool leapYear,
  }) : _nXAxisBuckets = nXAxisBuckets,
       _nYAxisBuckets = nYAxisBuckets,
       _leapYear = leapYear;

  int _nXAxisBuckets;
  int _nYAxisBuckets;
  bool _leapYear;
  List<int> _bomIndices = [
    0,
    31,
    59,
    90,
    120,
    151,
    181,
    212,
    243,
    273,
    304,
    334,
    365,
  ];

  /// A setter function that [_ChartRenderObjectWidget.updateRenderObject] uses when
  /// it needs to change the value for [nXAxisBuckets]
  set nXAxisBuckets(int value) {
    if (_nXAxisBuckets == value) return;
    _nXAxisBuckets = value;
    markNeedsLayout(); // Tell Flutter to re-run performLayout()
  }

  /// A setter function that [_ChartRenderObjectWidget.updateRenderObject] uses when
  /// it needs to change the value for [nYAxisBuckets]
  set nYAxisBuckets(int value) {
    if (_nYAxisBuckets == value) return;
    _nYAxisBuckets = value;
    markNeedsLayout(); // Tell Flutter to re-run performLayout()
  }

  /// A setter function that [_ChartRenderObjectWidget.updateRenderObject] uses when
  /// it needs to change the value for [leapYear]
  set leapYear(bool value) {
    if (_leapYear == value) return;
    _leapYear = value;
    if (_leapYear) {
      _bomIndices = [
        0,
        31,
        60,
        91,
        121,
        152,
        182,
        213,
        244,
        274,
        305,
        335,
        366,
      ];
    } else {
      _bomIndices = [
        0,
        31,
        59,
        90,
        120,
        151,
        181,
        212,
        243,
        273,
        304,
        334,
        365,
      ];
    }
    markNeedsLayout(); // Tell Flutter to re-run performLayout()
  }

  RenderBox? get _chartArray => childForSlot(ChartSlot.chartArray);
  Iterable<RenderBox?> get _xAxisLabels => Iterable.generate(
    _nXAxisBuckets,
    (index) => childForSlot(ChartSlot.xAxisLabel(index)),
  );
  Iterable<RenderBox?> get _yAxisLabels => Iterable.generate(
    _nYAxisBuckets + 1,
    (index) => childForSlot(ChartSlot.yAxisLabel(index)),
  );

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  /// The position here is not limited to the extent of this
  /// RenderPlayerCombined, but it is relative to its top-right corner.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      if (hitTestChildren(result, position: position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return false;
  }

  /// This could be simplified if I knew that no widgets would overlap.  In that case, as soon as it is true, I could exit.
  /// The problem is, if there was any overlap, I would need to make sure of the order I am checking in.
  ///
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Loop through children in reverse order (top-to-bottom visually)
    // so items rendered on top catch the mouse events first!
    for (final RenderBox child in children.toList().reversed) {
      final BoxParentData childParentData = child.parentData as BoxParentData;

      // Use Flutter's matrix helper instead of manual subtraction
      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformedPosition) {
          return child.hitTest(result, position: transformedPosition);
        },
      );

      // As soon as a child claims the hit test, stop checking others
      if (isHit) return true;
    }

    return false;
  }

  /// Consider added efficiency by calculating the maxes of the axis once and then storing them.  Then,
  /// before using, check [markNeedsLayout] tag thing.
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final double maxYAxisLabelWidth = _yAxisLabels
        .map((e) => e?.getDryLayout(constraints.loosen()).width ?? 0)
        .toList()
        .max
        .toDouble();
    final double maxXAxisLabelHeight = _xAxisLabels
        .map((e) => e?.getDryLayout(constraints.loosen()).height ?? 0)
        .toList()
        .max
        .toDouble();
    final Size chartSize =
        _chartArray?.getDryLayout(constraints.loosen()) ?? Size(0, 0);
    final double typicalYAxisLabelHeight =
        _yAxisLabels.first?.getDryLayout(constraints.loosen()).height ?? 0;
    final Size drySize = Size(
      maxYAxisLabelWidth + chartSize.width,
      maxXAxisLabelHeight + chartSize.height + typicalYAxisLabelHeight / 2,
    );
    return constraints.constrain(drySize);
  }

  @override
  void performLayout() {
    double maxYAxisLabelWidth = _yAxisLabels
        .map((e) => e?.getDryLayout(constraints.loosen()).width ?? 0)
        .toList()
        .max
        .toDouble();

    final double heatMapHeight = 300;

    _yAxisLabels.toList().reversed.forEachIndexed((index, child) {
      if (child == null) return;
      child.layout(
        constraints.loosen().tighten(width: maxYAxisLabelWidth),
        parentUsesSize: true,
      );
      final BoxParentData childParentData = child.parentData as BoxParentData;
      childParentData.offset = Offset(
        0,
        index * heatMapHeight / _nYAxisBuckets,
      );
    });

    final double typicalYAxisLabelHeight = _yAxisLabels.first?.size.height ?? 0;
    if (_chartArray != null) {
      _chartArray!.layout(
        BoxConstraints.tightFor(
          // width: min(600, constraints.maxWidth - maxYAxisLabelWidth),
          width: constraints.maxWidth - maxYAxisLabelWidth,
          height: heatMapHeight,
        ),
        parentUsesSize: true,
      );
      final BoxParentData childParentData =
          _chartArray!.parentData as BoxParentData;
      childParentData.offset = Offset(
        maxYAxisLabelWidth,
        typicalYAxisLabelHeight / 2,
      );
    }

    final double heatMapWidth = _chartArray?.size.width ?? 0;

    double maxXAxisLabelHeight = 0;
    _xAxisLabels.forEachIndexed((index, child) {
      if (child == null) return;
      child.layout(constraints.loosen(), parentUsesSize: true);
      final BoxParentData childParentData = child.parentData as BoxParentData;

      int monthsPerLabel = (12 / _nXAxisBuckets).toInt();
      final int nDays = _leapYear ? 366 : 365;
      final double xPerDay = heatMapWidth / nDays;
      final double x0 = (_bomIndices[index * monthsPerLabel] * xPerDay);
      final double x1 = (_bomIndices[(index * monthsPerLabel) + 1] * xPerDay);

      double idealHOffset = (x0 + x1) / 2 - child.size.width / 2;
      // Handle if first month label's width would cause an overlap on left end
      if (child.size.width / 2 > idealHOffset) {
        idealHOffset = child.size.width / 2;
      }
      // Handle if last month label's width would cause an overlap on right end
      if (heatMapWidth - idealHOffset < child.size.width / 2) {
        idealHOffset = heatMapWidth - child.size.width / 2;
      }
      childParentData.offset = Offset(
        maxYAxisLabelWidth + idealHOffset,
        heatMapHeight + typicalYAxisLabelHeight / 2,
      );
      maxXAxisLabelHeight = max(maxXAxisLabelHeight, child.size.height);
    });
    size = Size(
      maxYAxisLabelWidth + heatMapWidth,
      typicalYAxisLabelHeight / 2 + heatMapHeight + maxXAxisLabelHeight,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint each child
    for (final RenderBox child in children) {
      final BoxParentData childParentData = child.parentData as BoxParentData;
      context.paintChild(child, childParentData.offset + offset);
    }

    // 2. Safely grab your heatmap canvas child to find its dimensions and location
    final RenderBox? chartCanvas = _chartArray;
    if (chartCanvas != null) {
      final BoxParentData chartParentData =
          chartCanvas.parentData as BoxParentData;

      // 3. Calculate the absolute pixel origin of the heatmap on the screen
      final Offset canvasOrigin = offset + chartParentData.offset;
      final Size chartSize = chartCanvas.size;

      // 4. Set up your thin grid paint styling
      final Paint gridPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;

      // 5. Draw Vertical Grid Lines (X-Axis Dividers)
      final int nDays = _leapYear ? 366 : 365;
      final double xPerDay = chartSize.width / nDays;
      for (int i = 1; i < 12; i++) {
        final double x = canvasOrigin.dx + (_bomIndices[i] * xPerDay);
        context.canvas.drawLine(
          Offset(x, canvasOrigin.dy),
          Offset(x, canvasOrigin.dy + chartSize.height),
          gridPaint,
        );
      }

      // 6. Draw Horizontal Grid Lines (Y-Axis Dividers)
      final double rowHeight = chartSize.height / _nYAxisBuckets;
      for (int j = 1; j < _nYAxisBuckets; j++) {
        final double y = canvasOrigin.dy + (j * rowHeight);
        context.canvas.drawLine(
          Offset(canvasOrigin.dx, y),
          Offset(canvasOrigin.dx + chartSize.width, y),
          gridPaint,
        );
      }
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final BoxParentData childParentData = child.parentData as BoxParentData;
    transform.translateByDouble(
      childParentData.offset.dx,
      childParentData.offset.dy,
      0,
      1.0,
    );
  }
}

class ChartSlot {
  final String id;
  final int?
  index; // Allows us to dynamically generate as many slots for each String id as we need

  const ChartSlot._(this.id, [this.index]);

  static const ChartSlot chartArray = ChartSlot._('chartArray');

  // A factory to generate unique slots for each X-axis label dynamically
  factory ChartSlot.xAxisLabel(int index) => ChartSlot._('xAxisLabel', index);
  factory ChartSlot.yAxisLabel(int index) => ChartSlot._('yAxisLabel', index);

  @override
  bool operator ==(Object other) =>
      other is ChartSlot && other.id == id && other.index == index;

  @override
  int get hashCode => Object.hash(id, index);
}

enum MonthLabelList {
  twelve(12, [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ]),
  six(6, ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov']),
  four(4, ['Jan', 'Apr', 'Jul', 'Oct']),
  three(3, ['Jan', 'May', 'Sep']),
  two(2, ['Jan', 'Jul']);

  const MonthLabelList(this.count, this.labelList);

  final List<String> labelList;
  final int count;

  static MonthLabelList? fromCount(int count) {
    for (var value in MonthLabelList.values) {
      if (value.count == count) return value;
    }
    return null; // Handle invalid numbers safely
  }
}

enum TimeLabelList {
  twentyfourT(24, true, [
    '12:00 AM',
    '1:00 AM',
    '2:00 AM',
    '3:00 AM',
    '4:00 AM',
    '5:00 AM',
    '6:00 AM',
    '7:00 AM',
    '8:00 AM',
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM',
    '6:00 PM',
    '7:00 PM',
    '8:00 PM',
    '9:00 PM',
    '10:00 PM',
    '11:00 PM',
    '12:00 AM',
  ]),
  twelveT(12, true, [
    '12:00 AM',
    '2:00 AM',
    '4:00 AM',
    '6:00 AM',
    '8:00 AM',
    '10:00 AM',
    '12:00 PM',
    '2:00 PM',
    '4:00 PM',
    '6:00 PM',
    '8:00 PM',
    '10:00 PM',
    '12:00 AM',
  ]),
  eightT(8, true, [
    '12:00 AM',
    '3:00 AM',
    '6:00 AM',
    '9:00 AM',
    '12:00 PM',
    '3:00 PM',
    '6:00 PM',
    '9:00 PM',
    '12:00 AM',
  ]),
  sixT(6, true, [
    '12:00 AM',
    '4:00 AM',
    '8:00 AM',
    '12:00 PM',
    '4:00 PM',
    '8:00 PM',
    '12:00 AM',
  ]),
  fourT(4, true, ['12:00 AM', '6:00 AM', '12:00 PM', '6:00 PM', '12:00 AM']),
  threeT(3, true, ['12:00 AM', '8:00 AM', '4:00 PM', '12:00 AM']),
  twoT(2, true, ['12:00 AM', '12:00 PM', '12:00 AM']),
  oneT(1, true, ['12:00 AM', '12:00 AM']),
  twentyfourF(24, false, [
    '0:00',
    '1:00',
    '2:00',
    '3:00',
    '4:00',
    '5:00',
    '6:00',
    '7:00',
    '8:00',
    '9:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00',
    '24:00',
  ]),
  twelveF(12, false, [
    '0:00',
    '2:00',
    '4:00',
    '6:00',
    '8:00',
    '10:00',
    '12:00',
    '14:00',
    '16:00',
    '18:00',
    '20:00',
    '22:00',
    '24:00',
  ]),
  eightF(8, false, [
    '0:00',
    '3:00',
    '6:00',
    '9:00',
    '12:00',
    '15:00',
    '18:00',
    '21:00',
    '24:00',
  ]),
  sixF(6, false, ['0:00', '4:00', '8:00', '12:00', '16:00', '20:00', '24:00']),
  fourF(4, false, ['0:00', '6:00', '12:00', '18:00', '24:00']),
  threeF(3, false, ['0:00', '8:00', '16:00', '24:00']),
  twoF(2, false, ['0:00', '12:00', '24:00']),
  oneF(1, false, ['0:00', '24:00']);

  const TimeLabelList(this.count, this.twelveHour, this.labelList);

  final List<String> labelList;
  final bool twelveHour;

  /// This is the number of spans the day is cut into.  The actual number of ticks will be one more than that.
  final int count;

  /// [count] is the number of spans the day is cut into.  The actual number of ticks will be one more than that.
  static TimeLabelList? fromCountAndTwelveHour(int count, bool twelveHour) {
    for (var value in TimeLabelList.values) {
      if (value.count == count && value.twelveHour == twelveHour) return value;
    }
    return null; // Handle invalid numbers safely
  }
}
