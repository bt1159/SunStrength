// flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
import 'dart:core';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// {@template PublicChartRenderObjectWidget}
/// Public Widget that constains the a [_ChartRenderObjectWidget] and also super imposes the hover tooltip when showing.
/// {@endtemplate}
class PublicChartRenderObjectWidget extends StatefulWidget {
  /// {@macro PublicChartRenderObjectWidget}
  const PublicChartRenderObjectWidget({
    super.key,
    required this.chartArrayWidget,
    required this.nXAxisBuckets,
    required this.nYAxisBuckets,
    required this.leapYear,
    required this.rawMatrixData,
  }) : nDays = (leapYear ? 366 : 365);

  final Widget chartArrayWidget;
  final int nXAxisBuckets;
  final int nYAxisBuckets;
  final bool leapYear;
  final List<List<double>> rawMatrixData;
  final int nDays;

  @override
  State<PublicChartRenderObjectWidget> createState() =>
      _PublicChartRenderObjectWidgetState();
}

class _PublicChartRenderObjectWidgetState
    extends State<PublicChartRenderObjectWidget> {
  // Tooltip State Variables
  Offset? _hoverBoxPosition;
  String? _tooltipText12;
  String? _tooltipText24;

  void _handleChartHover(
    Offset chartTextLocalPosition,
    Size chartSize,
    Offset chartWidgetOffsetToParent,
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
    final double value = widget.rawMatrixData[dayIndex][timeIndex];

    final int yearInput = 2026;
    final String tZoneInput = "America/New_York";
    final tz.Location localTZ = tz.getLocation(tZoneInput);
    final int datetimeDelta =
        (((dayIndex * 24 * 60) + 15 * timeIndex) * 60 * 1000);
    final tz.TZDateTime hoverDateTimeRaw = tz.TZDateTime(
      localTZ,
      yearInput,
    ).add(Duration(milliseconds: datetimeDelta));

    setState(() {
      _hoverBoxPosition = chartTextLocalPosition + chartWidgetOffsetToParent;
      _tooltipText12 = '${DateFormat('d MMM yyyy h:mm a').format(hoverDateTimeRaw)}\nValue: ${value.toStringAsFixed(2)}';
      _tooltipText24 = '${ DateFormat('d MMM yyyy HH:mm').format(hoverDateTimeRaw)}\nValue: ${value.toStringAsFixed(2)}';
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
    print('running _PublicChartRenderObjectWidgetState.build, ${_hoverBoxPosition == null ? '_hoverBoxPosition is null' : '_hoverBoxPosition is not null'}');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _ChartRenderObjectWidget(
          nXAxisBuckets: widget.nXAxisBuckets,
          nYAxisBuckets: widget.nYAxisBuckets,
          leapYear: widget.leapYear,
          chartArrayWidget: Builder(
            builder: (context) {
              return MouseRegion(
                onHover: (event) {
                  // Find the rendering size of the canvas dynamically
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final BoxParentData? boxParentData =
                      box.parentData as BoxParentData?;
                  _handleChartHover(
                    event.localPosition,
                    box.size,
                    boxParentData?.offset ?? Offset(0, 0),
                  );
                },
                onExit: (_) => _hideTooltip(),
                child: widget.chartArrayWidget,
              );
            },
          ),
        ),
        // 2. The Floating Tooltip Popup Layer
        if (_hoverBoxPosition != null && _tooltipText12 != null && _tooltipText24 != null)
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
                  selector: (_, savedSettingsNotifier) => savedSettingsNotifier.value?.twelveHour ?? true,
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
  });

  final Widget chartArrayWidget;
  final int nXAxisBuckets;
  final int nYAxisBuckets;
  final bool leapYear;

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
          TimeLabelList.fromCount(nYAxisBuckets)?.labelList[slot.index!] ??
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
          width: min(600, constraints.maxWidth - maxYAxisLabelWidth),
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
      final Size chartSize = chartCanvas.size; // This will be your (600, 300)

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
  twentyfour(24, [
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
  twelve(12, [
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
  eight(8, [
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
  six(6, [
    '12:00 AM',
    '4:00 AM',
    '8:00 AM',
    '12:00 PM',
    '4:00 PM',
    '8:00 PM',
    '12:00 AM',
  ]),
  four(4, ['12:00 AM', '6:00 AM', '12:00 PM', '6:00 PM', '12:00 AM']),
  three(3, ['12:00 AM', '8:00 AM', '4:00 PM', '12:00 AM']),
  two(2, ['12:00 AM', '12:00 PM', '12:00 AM']),
  one(1, ['12:00 AM', '12:00 AM']);

  const TimeLabelList(this.count, this.labelList);

  final List<String> labelList;

  /// This is the number of spans the day is cut into.  The actual number of ticks will be one more than that.
  final int count;

  /// [count] is the number of spans the day is cut into.  The actual number of ticks will be one more than that.
  static TimeLabelList? fromCount(int count) {
    for (var value in TimeLabelList.values) {
      if (value.count == count) return value;
    }
    return null; // Handle invalid numbers safely
  }
}
