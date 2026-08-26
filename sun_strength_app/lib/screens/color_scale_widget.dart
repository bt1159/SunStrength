import 'dart:core';
import 'dart:ui' as ui;
// import 'dart:math';
// import 'package:collection/collection.dart';
import 'package:color_map/color_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
// import 'package:sun_strength_app/models/saved_settings_notifier.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';

class ColorScaleWidget extends StatelessWidget {
  const ColorScaleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return ColorScaleRenderObjectWidget(
          child: Selector<SavedSettingsNotifier, Colormap?>(
            selector: (_, savedAppSettingsNotifier) =>
                savedAppSettingsNotifier.value?.colorScheme.$2,
            builder: (context, colormap, child) =>
                FutureBuilderColorScale(colormap: colormap),
          ),
        );
      },
    );
  }
}

class FutureBuilderColorScale extends StatefulWidget {
  const FutureBuilderColorScale({super.key, required this.colormap});

  final Colormap? colormap;

  @override
  State<FutureBuilderColorScale> createState() =>
      _FutureBuilderColorScaleState();
}

class _FutureBuilderColorScaleState extends State<FutureBuilderColorScale> {
  late Future<ui.Image> futureChartImage;

  Future<ui.Image> createScaleImage() async {
    final int vertHeight = 40;
    final int horWidth = 100;
    Iterable<double> fullList = Iterable<double>.generate(
      vertHeight * horWidth,
      (index) {
        final int horIndex = (index / vertHeight).floor();
        return horIndex / (horWidth - 1);
      },
    );
    final (:image, :rawMatrixData) = await generateColorImage(
      valueIterable: fullList,
      pixelWidth: horWidth,
      colormap: widget.colormap,
    );
    return image;
  }

  @override
  void initState() {
    super.initState();
    futureChartImage = createScaleImage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: futureChartImage,
      builder: (context, AsyncSnapshot<ui.Image> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Snapshot Error: ${snapshot.error}'));
        }
        if (snapshot.hasData) {
          return CustomPaint(painter: ImagePainter(snapshot.data!));
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

class ColorScaleRenderObjectWidget extends SingleChildRenderObjectWidget {
  const ColorScaleRenderObjectWidget({
    super.key,
    super.child,
    this.labelStyle = const TextStyle(fontSize: 12, color: Colors.white),
  });

  final TextStyle labelStyle;

  @override
  ColorScaleRenderObject createRenderObject(BuildContext context) {
    return ColorScaleRenderObject(labelStyle: labelStyle);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    ColorScaleRenderObject renderObject,
  ) {
    renderObject.labelStyle = labelStyle;
  }
}

class ColorScaleRenderObject extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>, DebugOverflowIndicatorMixin {
  ColorScaleRenderObject({required TextStyle labelStyle})
    : _labelStyle = labelStyle;

  static const double _barHeight = 20;
  static const double _vertGap = 4;

  TextStyle _labelStyle;
  TextStyle get labelStyle => _labelStyle;
  set labelStyle(TextStyle value) {
    if (value == labelStyle) return;
    _labelStyle = value;
    markNeedsLayout();
  }

  static const List<String> _labelValues = [
    '0%',
    '10%',
    '20%',
    '30%',
    '40%',
    '50%',
    '60%',
    '70%',
    '80%',
    '90%',
    '100%',
  ];

  TextPainter labelTextPainter(int index) => TextPainter(
    text: TextSpan(
      text: _labelValues[index.clamp(0, _labelValues.length - 1)],
      style: labelStyle,
    ),
    textDirection: TextDirection.ltr,
  );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final farLeftTextPainter = labelTextPainter(0)..layout();
    final Size drySize = Size.fromHeight(
      _barHeight + _vertGap + farLeftTextPainter.height,
    );
    final actualSize = constraints.constrain(drySize);
    return actualSize;
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    if (child != null) {
      // Layout the two extremem labels so that I can use half of the widths to get the color bar's width
      final farLeftTextPainter = labelTextPainter(0)..layout();
      final farRightTextPainter = labelTextPainter(_labelValues.length - 1)
        ..layout();

      final BoxConstraints rectConstraints = BoxConstraints.tightFor(
        width:
            size.width -
            (farLeftTextPainter.width / 2 + farRightTextPainter.width / 2),
        height: _barHeight,
      );
      // 3. Force the child to layout with the new restricted constraints
      child!.layout(rectConstraints, parentUsesSize: true);
      (child!.parentData as BoxParentData).offset = Offset(
        farLeftTextPainter.width / 2,
        0,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;

    if (child != null) {
      final BoxParentData childParentData = child!.parentData as BoxParentData;
      context.paintChild(child!, offset + childParentData.offset);

      // // Layout the two extremem labels so that I can use half of the widths to get the color bar's width
      // final farLeftTextPainter = labelTextPainter(0)..layout();
      // final farRightTextPainter = labelTextPainter(_labelValues.length - 1)
      //   ..layout();

      // // Define size of colored bar
      // final Size rectSize = Size(
      //   size.width -
      //       (farLeftTextPainter.width / 2 + farRightTextPainter.width / 2),
      //   _barHeight,
      // );
      // final Offset rectOffset = offset + Offset(farLeftTextPainter.width / 2, 0);
      // final Rect rect = rectOffset & rectSize;

      // // Define painting (i.e, gradient) for colored bar
      // final Paint gradientPainter = Paint()
      //   ..shader = const LinearGradient(
      //     begin: Alignment.centerLeft,
      //     end: Alignment.centerRight,
      //     colors: <Color>[
      //       Color(0xFF000000),
      //       Color(0xFFFF0000),
      //       Color(0xFFFFFF00),
      //       Color(0xFFFFFFFF),
      //     ],
      //     stops: <double>[0.0, 1 / 3, 2 / 3, 1.0],
      //   ).createShader(rect);

      // // Draw the rectangle onto the canvas
      // canvas.drawRect(rect, gradientPainter);

      // Define style for vertical lines in bar
      final Paint gridPaint = Paint()
        // ..color = Colors.black.withValues(alpha: 0.25)
        ..color = Colors.blue.withValues(alpha: 0.25)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;

      final double labelSpacing =
          (child!.size.width / (_labelValues.length - 1));

      // Draw vertical lines in bar
      for (int i = 1; i < _labelValues.length - 1; i++) {
        context.canvas.drawLine(
          Offset(
            childParentData.offset.dx + labelSpacing * i + offset.dx,
            offset.dy,
          ),
          Offset(
            childParentData.offset.dx + labelSpacing * i + offset.dx,
            offset.dy + _barHeight,
          ),
          gridPaint,
        );
      }

      // Draw labels
      for (int i = 0; i < _labelValues.length; i++) {
        final TextPainter textPainter = labelTextPainter(i)..layout();
        final double xPos = offset.dx + labelSpacing * i;
        final double yPos =
            offset.dy + _barHeight + _vertGap; // 4px gap below bar

        final double clampedX = xPos.clamp(
          offset.dx,
          offset.dx + size.width - textPainter.width,
        );

        textPainter.paint(canvas, Offset(clampedX, yPos));
      }
    }
  }
}
