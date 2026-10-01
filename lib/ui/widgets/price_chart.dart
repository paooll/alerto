import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/instrument.dart';
import '../../services/backend_functions.dart';
import '../../theme.dart';

/// Basic close-price line chart for the instrument detail screen.
/// Custom-painted (no chart dependency) — replaced/upgraded in Step 8.
class PriceChart extends ConsumerStatefulWidget {
  const PriceChart({super.key, required this.instrument});

  final Instrument instrument;

  @override
  ConsumerState<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends ConsumerState<PriceChart> {
  late Future<List<PricePoint>> _future;
  String _interval = '1h';

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
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: FutureBuilder<List<PricePoint>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final points = snap.data ?? const <PricePoint>[];
              if (points.length < 2) {
                return const Center(
                  child: Text('No chart data available',
                      style: TextStyle(color: AppTheme.textSecondary)),
                );
              }
              return CustomPaint(
                painter: _LineChartPainter(points),
                size: Size.infinite,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.points);

  final List<PricePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final closes = points.map((p) => p.close).toList();
    final minP = closes.reduce(min);
    final maxP = closes.reduce(max);
    final range = (maxP - minP).abs() < 1e-9 ? 1.0 : maxP - minP;

    final up = closes.last >= closes.first;
    final lineColor = up ? AppTheme.green : AppTheme.red;

    final dx = size.width / (points.length - 1);
    Offset at(int i) => Offset(
          i * dx,
          size.height - 16 - ((closes[i] - minP) / range) * (size.height - 32),
        );

    final linePath = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(at(i).dx, at(i).dy);
    }

    // Soft gradient fill under the line.
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Last price dot
    final last = at(points.length - 1);
    canvas.drawCircle(last, 4, Paint()..color = lineColor);
    canvas.drawCircle(
      last,
      2,
      Paint()..color = AppTheme.bg,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
