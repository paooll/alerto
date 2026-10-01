import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/instrument.dart';
import '../../services/backend_functions.dart';
import '../../theme.dart';

/// Animated close-price line chart. Theme-aware (works in light & dark),
/// animates in on data load, supports interval switching.
class PriceChart extends ConsumerStatefulWidget {
  const PriceChart({super.key, required this.instrument});

  final Instrument instrument;

  @override
  ConsumerState<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends ConsumerState<PriceChart>
    with SingleTickerProviderStateMixin {
  late Future<List<PricePoint>> _future;
  late final AnimationController _reveal;
  String _interval = '1h';
  List<PricePoint>? _lastPoints;

  static const _intervals = {
    '15min': '15M',
    '1h': '1H',
    '4h': '4H',
    '1day': '1D',
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Future<List<PricePoint>> _load() => BackendFunctions.fetchTimeSeries(
        widget.instrument.symbol,
        interval: _interval,
        outputsize: 96,
      );

  void _setInterval(String interval) {
    setState(() {
      _interval = interval;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.isDark
        ? (_CardColors.dark)
        : (_CardColors.light);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _intervals.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _interval == e.key,
                        onSelected: (_) => _setInterval(e.key),
                        visualDensity: VisualDensity.compact,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 190,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.border),
          ),
          child: FutureBuilder<List<PricePoint>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  _lastPoints == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final points =
                  snap.data ?? _lastPoints ?? const <PricePoint>[];
              if (points.length < 2) {
                return Center(
                  child: Text('No chart data available',
                      style: TextStyle(color: theme.textDim)),
                );
              }
              _lastPoints = points;
              if (!_reveal.isAnimating && _reveal.value < 1) {
                _reveal.forward();
              }
              return AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) => CustomPaint(
                  painter: _LineChartPainter(
                    points,
                    progress: Curves.easeOutCubic.transform(_reveal.value),
                    lineColor: points.last.close >= points.first.close
                        ? AppColors.green
                        : AppColors.red,
                    gridColor: scheme.border,
                    bg: scheme.card,
                    textColor: theme.textDim,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CardColors {
  const _CardColors(this.card, this.border);
  final Color card;
  final Color border;

  static final dark = _CardColors(AppColors.cardDark, AppColors.borderDark);
  static final light = _CardColors(AppColors.cardLight, AppColors.borderLight);
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(
    this.points, {
    required this.progress,
    required this.lineColor,
    required this.gridColor,
    required this.bg,
    required this.textColor,
  });

  final List<PricePoint> points;
  final double progress;
  final Color lineColor;
  final Color gridColor;
  final Color bg;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final closes = points.map((p) => p.close).toList();
    final minP = closes.reduce(min);
    final maxP = closes.reduce(max);
    final range = (maxP - minP).abs() < 1e-9 ? 1.0 : maxP - minP;

    // Horizontal gridlines (3)
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.35)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Min/max labels
    final tp = TextPainter(
      text: TextSpan(
        text: maxP.toStringAsFixed(2),
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(4, 4));
    final bp = TextPainter(
      text: TextSpan(
        text: minP.toStringAsFixed(2),
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bp.paint(canvas, Offset(4, size.height - bp.height - 4));

    // Reveal: clip the width to the progress fraction.
    final visibleWidth = size.width * progress;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, visibleWidth, size.height));

    final dx = size.width / (points.length - 1);
    Offset at(int i) => Offset(
          i * dx,
          size.height - 22 - ((closes[i] - minP) / range) * (size.height - 44),
        );

    final linePath = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(at(i).dx, at(i).dy);
    }

    // Soft gradient fill under the line.
    final fillPath = Path.from(linePath)
      ..lineTo(visibleWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.22),
          lineColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Last price dot (pulsing halo baked into the reveal).
    final last = at(points.length - 1);
    if (progress > 0.97) {
      canvas.drawCircle(last, 8, Paint()..color = lineColor.withOpacity(0.18));
      canvas.drawCircle(last, 4, Paint()..color = lineColor);
      canvas.drawCircle(last, 2, Paint()..color = bg);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.progress != progress ||
      oldDelegate.lineColor != lineColor;
}
