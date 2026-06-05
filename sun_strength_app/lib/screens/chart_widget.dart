// flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
import 'dart:core';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
// import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/rendering.dart';


/// {@template PublicChartRenderObjectWidget}
/// Public Widget that just constains the a [_ChartRenderObjectWidget].
/// {@endtemplate}
class PublicChartRenderObjectWidget extends StatelessWidget {
  /// {@macro PublicChartRenderObjectWidget}
  const PublicChartRenderObjectWidget({
    super.key,
    required this.chartArrayWidget,
    required this.nXAxisBuckets,
    required this.nYAxisBuckets,
  });

  final Widget chartArrayWidget;
  final int nXAxisBuckets;
  final int nYAxisBuckets;

  @override
  Widget build(BuildContext context) {
    return _ChartRenderObjectWidget(
      chartArrayWidget: chartArrayWidget,
      nXAxisBuckets: nXAxisBuckets,
      nYAxisBuckets: nYAxisBuckets,
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
  });

  final Widget chartArrayWidget;
  final int nXAxisBuckets;
  final int nYAxisBuckets;


  @override
  Iterable<ChartSlot> get slots {
    return [
      ChartSlot.chartArray,
      ...Iterable.generate(nYAxisBuckets + 1, (i) => ChartSlot.yAxisLabel(i)),
      // Dynamically add a slot for every label provided
      ...Iterable.generate(nXAxisBuckets, (i) => ChartSlot.xAxisLabel(i)),
    ];
  }

  @override
  Widget childForSlot(ChartSlot slot) {
    if (slot == ChartSlot.chartArray) return chartArrayWidget;

    // Return a text widget for the specific index
    if (slot.id == 'yAxisLabel') {
      final String labelText =
          TimeLabelList.fromCount(nYAxisBuckets)?.labelList[slot.index!] ??
          'BadYAxisCount';
      return Text(labelText);
    }

    // Return a text widget for the specific index
    if (slot.id == 'xAxisLabel') {
      final String labelText =
          MonthLabelList.fromCount(nXAxisBuckets)?.labelList[slot.index!] ??
          'BadXAxisCount';
      return Text(labelText);
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
  }) : _nXAxisBuckets = nXAxisBuckets,
       _nYAxisBuckets = nYAxisBuckets;

  int _nXAxisBuckets;
  int _nYAxisBuckets;

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
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    bool childrenHitTestBool = false;
    for (final RenderBox child in children) {
      final BoxParentData childParentData = child.parentData as BoxParentData;
      childrenHitTestBool =
          childrenHitTestBool ||
          child.hitTest(result, position: position - childParentData.offset);
    }
    return childrenHitTestBool;
  }

  /// Consider added efficiency by calculating the maxes of the axis once and then storing them.  Then,
  /// before using, check [markNeedsLayout] tag thing.
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    double maxYAxisLabelWidth = _yAxisLabels
        .map((e) => e?.getDryLayout(constraints.loosen()).width ?? 0)
        .toList()
        .max
        .toDouble();
    double maxXAxisLabelHeight = _xAxisLabels
        .map((e) => e?.getDryLayout(constraints.loosen()).height ?? 0)
        .toList()
        .max
        .toDouble();
    Size chartSize = _chartArray?.getDryLayout(constraints.loosen()) ?? Size(0, 0);
    Size drySize = Size(
      maxYAxisLabelWidth + chartSize.width,
      maxXAxisLabelHeight + chartSize.height,
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

    // For now, I am going to make the Y axis values NOT centered correctly vertically.  I'll tweak that later.
    _yAxisLabels.toList().reversed.forEachIndexed((index, child) {
      
      if (child == null) return;
      child.layout(constraints.loosen(), parentUsesSize: true);
      final BoxParentData childParentData = child.parentData as BoxParentData;
      if (index == _nYAxisBuckets) {
        childParentData.offset = Offset(
          0,
          index * heatMapHeight / _nYAxisBuckets - child.size.height,
        );
      } else {
        childParentData.offset = Offset(
          0,
          index * heatMapHeight / _nYAxisBuckets,
        );
      }
    });

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
      childParentData.offset = Offset(maxYAxisLabelWidth, 0);

    }

    final double heatMapWidth = _chartArray?.size.width ?? 0;

    double maxXAxisLabelHeight = 0;
    _xAxisLabels.forEachIndexed((index, child) {
      if (child == null) return;
      child.layout(constraints.loosen(), parentUsesSize: true);
      final BoxParentData childParentData = child.parentData as BoxParentData;
      int monthsPerLabel = (12 / _nXAxisBuckets).toInt();
      double idealHOffset =
          ((monthsPerLabel * index) + 0.5) * (heatMapWidth / 12) - child.size.width / 2;
      if (child.size.width / 2 > idealHOffset) {
        idealHOffset = child.size.width / 2;
      }
      if (heatMapWidth - idealHOffset < child.size.width / 2) {
        idealHOffset = heatMapWidth - child.size.width / 2;
      }
      childParentData.offset = Offset(
        maxYAxisLabelWidth + idealHOffset,
        heatMapHeight,
      );
      maxXAxisLabelHeight = max(maxXAxisLabelHeight, child.size.height);
    });
    size = Size(
      maxYAxisLabelWidth + heatMapWidth,
      heatMapHeight + maxXAxisLabelHeight,
    );

  }

  @override
  void paint(PaintingContext context, Offset offset) {

    // Loop through all non-null children active in your slots
    for (final RenderBox child in children) {
      final BoxParentData childParentData = child.parentData as BoxParentData;

      // Paint each child at its layout offset, adjusted by the global screen offset
      context.paintChild(child, childParentData.offset + offset);
    }

    // FUTURE ME: Add background grids, borders, or dividers here!
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
  eight(6, [
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
