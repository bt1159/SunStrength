import 'dart:core';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sun_strength_app/models/main_notifiers.dart';
import 'package:sun_strength_app/models/errors.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/chart_notifiers.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:color_map/color_map.dart';

/// {@template PublicChartRenderObjectWidget}
/// Public Widget that constains the a [_ChartRenderObjectWidget] and also super-imposes the hover tooltip when showing.
/// {@endtemplate}
class ChartWidget extends StatefulWidget {
  /// {@macro PublicChartRenderObjectWidget}
  const ChartWidget({
    super.key,
    required this.nXAxisBuckets,
    required this.nYAxisBuckets,
  });

  final int nXAxisBuckets;
  final int nYAxisBuckets;

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  int ticks = DateTime.now().millisecondsSinceEpoch;
  late final ValueNotifier<TooltipInfo?> _tooltipNotifier;
  static const Offset toolTipFormattingOffset = Offset(0, 40);

  /// This method's purpose is two-fold: 1) update the value of [_tooltipNotifier] and return the single day's [OrbitAndSolarValues], which is then sent to azimuth chart if this chart is clicked.
  List<OrbitAndSolarValues> _handleChartHover(
    Offset chartTextLocalPosition,
    Size chartSize,
    List<OrbitAndSolarValues> orbitAndSolarValuesList,
    tz.Location timeZone,
    int year,
  ) {
    final double x = chartTextLocalPosition.dx;
    final double y = chartTextLocalPosition.dy;
    final int nDays = isLeapYear(year) ? 366 : 365;

    // Calculate grid cell dimensions dynamically based on current layout size
    final double pxWidth = chartSize.width / nDays;
    final double pxHeight = chartSize.height / 96;

    // Determine the exact row and column indices
    final int dayIndex = (x / pxWidth).floor().clamp(0, nDays - 1);
    final int timeIndex = (96 - 1) - (y / pxHeight).floor().clamp(0, 96 - 1);
    // Look up data parameters safely.  First index is day, then time
    final List<OrbitAndSolarValues> osSingleDay = orbitAndSolarValuesList
        .sublist(dayIndex * 96, (dayIndex + 1) * 96);
    final double value =
        osSingleDay[timeIndex].solarStrengthsLocalRelativeToGlobalMax;
    final int datetimeDelta =
        (((dayIndex * 24 * 60) + 15 * timeIndex) * 60 * 1000);
    final tz.TZDateTime hoverDateTimeRaw = tz.TZDateTime(
      timeZone,
      year,
    ).add(Duration(milliseconds: datetimeDelta));
    String timeZoneName = hoverDateTimeRaw.timeZoneName;
    if (timeZoneName.length > 3) {
      timeZoneName = '';
    }
    _tooltipNotifier.value = (
      hoverBoxPosition: chartTextLocalPosition + toolTipFormattingOffset,
      tooltipText12:
          '${DateFormat('d MMM yyyy h:mm a').format(hoverDateTimeRaw)} $timeZoneName\nStrength: ${(value * 100).toStringAsFixed(0)}%',
      tooltipText24:
          '${DateFormat('d MMM yyyy HH:mm').format(hoverDateTimeRaw)} $timeZoneName\nStrength: ${(value * 100).toStringAsFixed(0)}%',
    );
    return osSingleDay;
  }

  void _hideTooltip() {
    if (_tooltipNotifier.value != null) _tooltipNotifier.value = null;
  }

  @override
  void initState() {
    super.initState();
    _tooltipNotifier = ValueNotifier<TooltipInfo?>(null);
  }

  @override
  void dispose() {
    _tooltipNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
      'running _PublicChartRenderObjectWidgetState.build, ${_tooltipNotifier.value == null ? '_hoverBoxPosition is null' : '_hoverBoxPosition is not null'}',
    );
    return Column(
      children: [
        Align(
          alignment: AlignmentGeometry.centerLeft,
          child: Text(
            'Sun strength throughout the year',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 5),
        Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Selector<CurrentChartSettingsNotifier, (int, tz.Location)?>(
              selector: (_, currentChartSettingsNotifier) =>
                  currentChartSettingsNotifier.value == null
                  ? null
                  : (
                      currentChartSettingsNotifier.value!.year,
                      currentChartSettingsNotifier.value!.timeZone,
                    ),
              builder: (_, currentSettings, _) {
                if (currentSettings == null) return SizedBox.shrink();
                final (year, timeZone) = currentSettings;
                return Selector<SavedSettingsNotifier, bool>(
                  selector: (_, savedSettingsNotifier) =>
                      savedSettingsNotifier.value?.twelveHour ?? true,
                  builder: (context, twelveHour, child) =>
                      _ChartRenderObjectWidget(
                        nXAxisBuckets: widget.nXAxisBuckets,
                        nYAxisBuckets: widget.nYAxisBuckets,
                        twelveHour: twelveHour,
                        leapYear: isLeapYear(year),
                        chartArrayWidget: child!,
                      ),
                  child: Consumer<OrbitAndSolarValuesListNotifier>(
                    builder: (context, orbitAndSolarValuesListNotifier, _) {
                      List<OrbitAndSolarValues> orbitAndSolarValuesList =
                          orbitAndSolarValuesListNotifier.value;
                      List<OrbitAndSolarValues> osSingleDay =
                          <OrbitAndSolarValues>[];
                      return MouseRegion(
                        onHover: (event) {
                          final RenderBox box =
                              context.findRenderObject() as RenderBox;
                          osSingleDay = _handleChartHover(
                            event.localPosition,
                            box.size,
                            orbitAndSolarValuesList,
                            timeZone,
                            year,
                          );
                        },
                        onExit: (_) => _hideTooltip(),
                        child: GestureDetector(
                          onTap: () => context.read<DayDataNotifier>().value =
                              osSingleDay,
                          child:
                              Selector<SavedSettingsNotifier, MyColorScheme?>(
                                selector: (_, savedAppSettingsNotifier) =>
                                    savedAppSettingsNotifier.value?.colorScheme,
                                shouldRebuild: (previous, next) =>
                                    previous?.$1 != next?.$1,
                                builder: (context, colorScheme, child) {
                                  return FutureBuilderChartImage(
                                    orbitAndSolarValuesIterable:
                                        orbitAndSolarValuesListNotifier.value,
                                    colormap: colorScheme?.$2,
                                  );
                                },
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // 2. The Floating Tooltip Popup Layer
            ValueListenableBuilder<TooltipInfo?>(
              valueListenable: _tooltipNotifier,
              builder: (context, tooltipInfo, child) {
                if (tooltipInfo != null) {
                  return Positioned.fill(
                    child: CustomSingleChildLayout(
                      delegate: MouseFollowingTooltipDelegate(
                        hoverBoxPosition: tooltipInfo.hoverBoxPosition,
                      ),
                      child: IgnorePointer(
                        // Prevents the tooltip box from stealing mouse focus
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          // padding: const EdgeInsets.all(0),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Selector<SavedSettingsNotifier, bool>(
                            selector: (_, savedSettingsNotifier) =>
                                savedSettingsNotifier.value?.twelveHour ?? true,
                            builder: (_, twelveHour, _) => Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Opacity(
                                  opacity: 0,
                                  child: Text(
                                    twelveHour
                                        ? '88 888 8888 88:88 88 XXX\nStrength: 100%'
                                        : '88 888 8888 88:88 XXX\nStrength: 100%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  twelveHour
                                      ? tooltipInfo.tooltipText12
                                      : tooltipInfo.tooltipText24,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class MouseFollowingTooltipDelegate extends SingleChildLayoutDelegate {
  final Offset hoverBoxPosition;

  MouseFollowingTooltipDelegate({required this.hoverBoxPosition});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Converts tight constraints (forced size) into loose constraints (0 to max size),
    // allowing the tooltip Container to shrink to exactly the size of its text.
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Start with the ideal position next to the cursor
    double x = hoverBoxPosition.dx;
    double y = hoverBoxPosition.dy;
    print('inside getPositionForChild, x: $x, y: $y');

    // Clamp to the right edge (prevent overflowing the screen)
    // If the tooltip's right edge goes past the screen width, lock it to the max allowed X.
    if (x + childSize.width > size.width) {
      x = size.width - childSize.width;
    }

    // Clamp to the left edge (just in case)
    if (x < 0) {
      x = 0;
    }

    _ChartWidgetState.toolTipFormattingOffset.dy;
    // Clamp to the bottom edge
    if (y + childSize.height > size.height) {
      y =
          hoverBoxPosition.dy -
          _ChartWidgetState.toolTipFormattingOffset.dy -
          childSize.height;
    }

    print('inside getPositionForChild, x: $x, y: $y');

    print(
      'inside getPositionForChild, size.width: ${size.width}, size.height: ${size.height}',
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(MouseFollowingTooltipDelegate oldDelegate) {
    // Only recalculate layout if the mouse has actually moved
    return oldDelegate.hoverBoxPosition != hoverBoxPosition;
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
    print(
      'running createChartImage, colormap: ${widget.colormap == null ? 'null' : ColorMapPicker.getName(widget.colormap!)}}',
    );
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
      orbitAndSolarValuesList: widget.orbitAndSolarValuesIterable,
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

  /// This override is required because the only place where
  /// [widget.orbitAndSolarValuesIterable] and [widget.colormap] are
  /// referenced are in [createChartImage].  Since they are not referenced
  /// in the build method, changing those values (i.e., changing the
  /// configuration widget) will not run the build() method.
  @override
  void didUpdateWidget(covariant FutureBuilderChartImage oldWidget) {
    if (oldWidget.orbitAndSolarValuesIterable !=
        widget.orbitAndSolarValuesIterable) {
      futureChartImage = createChartImage();
    } else {
      String? oldColorMapString = oldWidget.colormap == null
          ? null
          : ColorMapPicker.getName(oldWidget.colormap!);
      String? newColorMapString = widget.colormap == null
          ? null
          : ColorMapPicker.getName(widget.colormap!);
      if (oldColorMapString != newColorMapString) {
        futureChartImage = createChartImage();
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    print('running _FutureBuilderChartImageState.build');
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
       _leapYear = leapYear,
       _nDays = leapYear ? 366 : 365;

  int _nXAxisBuckets;
  int _nYAxisBuckets;
  bool _leapYear;
  int _nDays;
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

  /// Horizontal gap between y axis labels and chart
  static const double hLabelGap = 10;

  /// Vertical gap between x axis labels and chart
  static const double vLabelGap = 10;

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
      _nDays = 366;
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
      _nDays = 365;
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
      maxYAxisLabelWidth + chartSize.width + hLabelGap,
      maxXAxisLabelHeight +
          chartSize.height +
          typicalYAxisLabelHeight / 2 +
          vLabelGap,
    );
    return constraints.constrain(drySize);
  }

  @override
  void performLayout() {
    constraints;
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
          width: constraints.maxWidth - maxYAxisLabelWidth - hLabelGap,
          height: heatMapHeight,
        ),
        parentUsesSize: true,
      );
      final BoxParentData childParentData =
          _chartArray!.parentData as BoxParentData;
      childParentData.offset = Offset(
        maxYAxisLabelWidth + hLabelGap,
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
      final double xPerDay = heatMapWidth / _nDays;
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
        maxYAxisLabelWidth + hLabelGap + idealHOffset,
        heatMapHeight + typicalYAxisLabelHeight / 2 + vLabelGap,
      );
      maxXAxisLabelHeight = max(maxXAxisLabelHeight, child.size.height);
    });
    size = Size(
      maxYAxisLabelWidth + heatMapWidth + hLabelGap,
      typicalYAxisLabelHeight / 2 +
          heatMapHeight +
          maxXAxisLabelHeight +
          vLabelGap,
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
      final double xPerDay = chartSize.width / _nDays;
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
