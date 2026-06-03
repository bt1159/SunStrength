import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
// import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/rendering.dart';

// enum ChartSlot { chartArray, yAxisColumn, xAxisRow }

/// {@template PublicChartRenderObjectWidget}
/// Public Widget that just constains the a [_ChartRenderObjectWidget].
/// {@endtemplate}
class PublicChartRenderObjectWidget extends StatelessWidget {
  const PublicChartRenderObjectWidget({
    super.key,
    required this.chartArray,
    required this.nXAxisTicks,
    required this.nYAxisTicks,
  });

  final Widget chartArray;
  final int nXAxisTicks;
  final int nYAxisTicks;

  @override
  Widget build(BuildContext context) {
    return _ChartRenderObjectWidget(
      chartArray: chartArray,
      nXAxisTicks: nXAxisTicks,
      nYAxisTicks: nYAxisTicks,
    );
  }
}

/// {@template PrivateChartRenderObjectWidget}
/// Widget that holds the entire solar strength chart, including all the components
///
/// This is a custom widget creats an element, [_ChartRenderObjectElement], and
/// a render object, [_ChartRenderObject].
/// {@endtemplate}
class _ChartRenderObjectWidget
    extends SlottedMultiChildRenderObjectWidget<ChartSlot, RenderBox> {
  /// {@macro PrivateChartRenderObjectWidget}
  const _ChartRenderObjectWidget({
    required this.chartArray,
    required this.nXAxisTicks,
    required this.nYAxisTicks,
  });

  final Widget chartArray;
  final int nXAxisTicks;
  final int nYAxisTicks;

  // final Widget xAxisColumn = Row(
  //   mainAxisSize: MainAxisSize.max,
  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //   children: [Text('Jan'),Text('May'),Text('Sep')],);

  @override
  Iterable<ChartSlot> get slots {
    return [
      ChartSlot.chartArray,
      ...Iterable.generate(nYAxisTicks, (i) => ChartSlot.yAxisLabel(i)),
      // Dynamically add a slot for every label provided
      ...Iterable.generate(nXAxisTicks, (i) => ChartSlot.xAxisLabel(i)),
    ];
  }

  @override
  Widget childForSlot(ChartSlot slot) {
    if (slot == ChartSlot.chartArray) return chartArray;

    // Return a text widget for the specific index
    if (slot.id == 'yAxisLabel') {
      final String labelText =
          TimeLabelList.fromCount(nYAxisTicks)?.labelList[slot.index!] ??
          'BadXAxisCount';
      return Text(labelText);
    }

    // Return a text widget for the specific index
    if (slot.id == 'xAxisLabel') {
      final String labelText =
          MonthLabelList.fromCount(nXAxisTicks)?.labelList[slot.index!] ??
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
      xAxisLabelCount: nXAxisTicks,
      yAxisLabelCount: nYAxisTicks + 1,
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
    renderObject.xAxisLabelCount = nXAxisTicks;
    renderObject.yAxisLabelCount = nYAxisTicks;
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

class _ChartRenderObject extends RenderBox
    with
        SlottedContainerRenderObjectMixin<ChartSlot, RenderBox>,
        DebugOverflowIndicatorMixin {
  _ChartRenderObject({
    required int xAxisLabelCount,
    required int yAxisLabelCount,
  }) : _xAxisLabelCount = xAxisLabelCount,
       _yAxisLabelCount = yAxisLabelCount;

  int _xAxisLabelCount;
  int _yAxisLabelCount;

  set xAxisLabelCount(int value) {
    if (_xAxisLabelCount == value) return;
    _xAxisLabelCount = value;
    markNeedsLayout(); // Tell Flutter to re-run performLayout()
  }

  set yAxisLabelCount(int value) {
    if (_yAxisLabelCount == value) return;
    _yAxisLabelCount = value;
    markNeedsLayout(); // Tell Flutter to re-run performLayout()
  }

  RenderBox? get _chartArray => childForSlot(ChartSlot.chartArray);
  Iterable<RenderBox?> get _xAxisLabels => Iterable.generate(
    _xAxisLabelCount,
    (index) => childForSlot(ChartSlot.xAxisLabel(index)),
  );
  Iterable<RenderBox?> get _yAxisLabels => Iterable.generate(
    _yAxisLabelCount,
    (index) => childForSlot(ChartSlot.yAxisLabel(index)),
  );

  //  /// This method is called during
  // /// [SlottedContainerRenderObjectMixin._setChild].  See also [dropChild].  It
  // /// is overridden in order to set [WidgetLayoutInfo.needFirstCalc] to true,
  // /// since the child is newly added.
  // ///
  // /// It is only during [performLayout] that all of these calculations are
  // /// handled. During that method, [listNeededFirstCalcs] is called to get a
  // /// list of [_TwoMemberObject] representing the children that need their
  // /// reCalc... methods called.  Then, after some other potential changes are
  // /// checked, it calls [updateIndependentVariable] on that full list.
  // @override
  // void adoptChild(RenderObject child) {
  //   super.adoptChild(child);
  //   // PlayerSlot? slot = findSlotForChild(child as RenderBox);
  //   // assert(slot != null,
  //   //     'This child should have been added but no slot was found');
  //   // _slotsLayoutInfo[slot]!.needFirstCalc = true;
  //   // if (slot != null && slot == PlayerSlot.epTitle1) {
  //   //   if (kDebugMode) {
  //   //     print(
  //   //         'Just adopted epTitle1, which sets its needFirstCalc to true.  That will cause the \'hash\' TMO to be added to the recalc list during performLayout');
  //   //   }
  //   // }
  // }

  // /// When a child is dropped, its [WidgetLayoutInfo] will remain in this
  // /// object.  Since it will never change unless it is re-added, I need to
  // /// manually set the [WidgetLayoutInfo] values to 0 so that any other
  // /// measurements relying on them are calulated correctly.  The offset values
  // /// of each widget child or TextPainter child should only be referenced by
  // /// that object for this very reason.
  // @override
  // void dropChild(RenderObject child) {
  //   super.dropChild(child);
  //   // PlayerSlot? slot = findSlotForChild(child as RenderBox);
  //   // assert(slot != null,
  //   //     'This child should have been added but no slot was found');
  //   // _slotsLayoutInfo[slot]!.needFirstCalc = true;
  // }

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

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    double maxYAxisLabelWidth = _yAxisLabels.map((e) => e?.getDryLayout(constraints).width ?? 0).toList().max.toDouble();
    double maxXAxisLabelHeight = _xAxisLabels.map((e) => e?.getDryLayout(constraints).height ?? 0).toList().max.toDouble();
    // fold(0, (previousValue, element) => max(previousValue, element),);
    Size chartSize = _chartArray?.getDryLayout(constraints) ?? Size(0,0);
    Size drySize = Size(
      maxYAxisLabelWidth + chartSize.width,
      maxXAxisLabelHeight + chartSize.height,
    );
    return constraints.constrain(drySize);
  }

  @override
  void performLayout() {
    // // Check for updated text in epTitle and podTitle values BEFORE rerunning
    // // needed recalcs
    // if (reCalcFindEpTitle1RendP()?.text.toString() != epTitleCachedText) {
    //   _slotsLayoutInfo[PlayerSlot.epTitle1]!.needFirstCalc = true;
    //   _slotsLayoutInfo[PlayerSlot.epTitle2]!.needFirstCalc = true;
    // }

    // List<_TwoMemberObject> tMOList = listNeededFirstCalcs();

    // // updateTextAlignment();

    // // Check if constraints have changed BEFORE rerunning needed recalcs
    // if (constraints.maxWidth != _maxWidthCached) {
    //   _maxWidthCached = constraints.maxWidth;
    //   tMOList.add(_TwoMemberObject(RenderParam.maxWidthCached, ''));
    // }

    // updateIndependentVariable(tMOList);

    // size = constraints.constrain(Size(constraints.maxWidth,
    //     lerpDouble(miniHeight, constraints.maxHeight, animationValue)!));

    // if (_epTitle1 != null) {
    //   _epTitle1!.layout(BoxConstraints.tight(Size.zero));
    // }

    // // Lerping and setting actual layouts and offsets
    // if (_epTitle2 != null) {
    //   _epTitle2!.layout(
    //       BoxConstraints(
    //           maxWidth: lerpDouble(
    //               _slotsLayoutInfo[PlayerSlot.epTitle2]!.widthMini,
    //               _slotsLayoutInfo[PlayerSlot.epTitle2]!.widthFull,
    //               animationValue)!),
    //       parentUsesSize: true);
    //   (_epTitle2!.parentData as BoxParentData).offset =
    //       getLerpedOffset(PlayerSlot.epTitle2);
    // }
    // if (_podTitle1 != null) {
    //   _podTitle1!.layout(
    //       BoxConstraints.tight(getLerpedSize(PlayerSlot.podTitle1)),
    //       parentUsesSize: true);
    //   (_podTitle1!.parentData as BoxParentData).offset =
    //       getLerpedOffset(PlayerSlot.podTitle1);
    // }
    // if (_podTitle2 != null) {
    //   _podTitle2!.layout(
    //       BoxConstraints.tight(getLerpedSize(PlayerSlot.podTitle2)),
    //       parentUsesSize: true);
    //   (_podTitle2!.parentData as BoxParentData).offset =
    //       getLerpedOffset(PlayerSlot.podTitle2);
    // }
    // if (_closeButton != null) {
    //   _closeButton!.layout(
    //       BoxConstraints.tight(Size(
    //           _slotsLayoutInfo[PlayerSlot.closeButton]!.widthFull,
    //           _slotsLayoutInfo[PlayerSlot.closeButton]!.heightFull)),
    //       parentUsesSize: true);
    //   (_closeButton!.parentData as BoxParentData).offset =
    //       getLerpedOffset(PlayerSlot.closeButton);
    // }
    // if (_epImage != null && _slotsLayoutInfo[PlayerSlot.epImage]!.visible) {
    //   _epImage!.layout(BoxConstraints.tight(getLerpedSize(PlayerSlot.epImage)),
    //       parentUsesSize: true);
    //   (_epImage!.parentData as BoxParentData).offset =
    //       getLerpedOffset(PlayerSlot.epImage);
    // }
    // if (_playPauseButton != null &&
    //     _slotsLayoutInfo[PlayerSlot.playPauseButton]!.visible) {
    //   _playPauseButton!.layout(
    //       BoxConstraints.tight(Size(
    //         _slotsLayoutInfo[PlayerSlot.playPauseButton]!.widthFull,
    //         _slotsLayoutInfo[PlayerSlot.playPauseButton]!.heightFull,
    //       )),
    //       parentUsesSize: true);
    //   (_playPauseButton!.parentData as BoxParentData).offset =
    //       getLerpedOffset(PlayerSlot.playPauseButton);
    // }
    // if (_progressBar != null &&
    //     _slotsLayoutInfo[PlayerSlot.progressBar]!.visible) {
    //   _progressBar!.layout(
    //       BoxConstraints.tight(Size(
    //           _slotsLayoutInfo[PlayerSlot.progressBar]!.widthFull,
    //           _slotsLayoutInfo[PlayerSlot.progressBar]!.heightFull)),
    //       parentUsesSize: true);
    //   (_progressBar!.parentData as BoxParentData).offset =
    //       getLerpedOffset(PlayerSlot.progressBar);
    // }
    // layoutFullOnly(_nextContainer, PlayerSlot.nextContainer);
    // layoutFullOnly(_jumpAheadButton, PlayerSlot.jumpAheadButton);
    // layoutFullOnly(_jumpBackButton, PlayerSlot.jumpBackButton);
    // layoutFullOnly(_nextButton, PlayerSlot.nextButton);
    // layoutFullOnly(_prevButton, PlayerSlot.prevButton);
    // layoutFullOnly(_minimizeButton, PlayerSlot.minimizeButton);
    // layoutFullOnly(_progressSlider, PlayerSlot.progressSlider);
    // layoutFullOnly(_sourceProblemLabel, PlayerSlot.sourceProblemLabel);
    // layoutFullOnly(_loadingIndicator, PlayerSlot.loadingIndicator);
    // layoutFullOnly(_positionLabel, PlayerSlot.positionLabel);
    // layoutFullOnly(_lowerButtonRow, PlayerSlot.lowerButtonRow);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // cachedDoNotPaintList = doNotPaintList;
    // cachedPaintList = paintList;
    // if (cachedPaintList != null) {
    //   cachedPaintListChildren = paintListChildren(cachedPaintList!);
    // }

    // final Color animatedColor =
    //     Color.lerp(miniBackgroundColor, fullBackgroundColor, animationValue)!;
    // context.canvas.drawRect(offset & size, Paint()..color = animatedColor);

    // if (cachedPaintList != null) {
    //   for (final PlayerSlot slot in cachedPaintList!) {
    //     final RenderBox? child = childForSlot(slot);
    //     if (child != null) {
    //       final BoxParentData childParentData =
    //           child.parentData as BoxParentData;
    //       context.paintChild(child, childParentData.offset + offset);
    //     }
    //   }
    // }
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

  static TimeLabelList? fromCount(int count) {
    for (var value in TimeLabelList.values) {
      if (value.count == count) return value;
    }
    return null; // Handle invalid numbers safely
  }
}






  //   final double deltaT = 24 / nYAxisTicks;
  //   final Iterable<tz.TZDateTime> tickValues = Iterable.generate(nYAxisTicks, (index) => tz.TZDateTime.utc(2000).add(Duration(microseconds: (deltaT * 3600 * 1000000).round())));
  //   final Iterable<String> tickLabels = tickValues.map((e) => '${(e.hour - 1) % 12 + 1}:${e.minute}:${e.second} ${e.hour > 11 ? 'PM' : 'AM'}');
  //   final Iterable<Widget> children = tickLabels.map((e) => Text(e));
  //   final Widget output = Column(
  //     crossAxisAlignment: CrossAxisAlignment.end,
  //     mainAxisSize: MainAxisSize.max,
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: children.toList());
  //   return output;
  // }