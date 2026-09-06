import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/constants/tunables.dart';
import '../../domain/model/glucose_chart_point.dart';
import '../theme/tokens.dart';

/// CGM-style line chart fed by glucose scans (`numericValue`).
///
/// The 70–180 mg/dL target band is drawn as two dashed guide lines (never red —
/// neutral tones per the Glucose Guild design language) with the data line
/// drawn in the current accent.
class CgmLineChart extends StatelessWidget {
  final List<GlucoseChartPoint> points;
  final double? minY;
  final double? maxY;

  const CgmLineChart({super.key, required this.points, this.minY, this.maxY});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (points.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.tonal,
          border: Border.all(color: tokens.lineRest, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          'No glucose scans yet.\nSettle your first scan to see your CGM line.',
          textAlign: TextAlign.center,
          style: tokens.body(fontSize: 12, color: tokens.textSecondary),
        ),
      );
    }

    final resolvedMinY = minY ?? 40.0;
    final resolvedMaxY = maxY ??
        points
                .map((p) => p.value)
                .reduce((a, b) => a > b ? a : b)
                .clamp(220.0, 400.0) +
            40.0;

    final spots = points
        .map((p) => FlSpot(_xOf(p.time, points), p.value))
        .toList();

    final firstTime = points.first.time;
    final lastTime = points.last.time;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 24, 20, 12),
      decoration: BoxDecoration(
        color: tokens.tonal,
        border: Border.all(color: tokens.lineRest, width: 1),
      ),
      child: LineChart(
        LineChartData(
          minX: _xOf(firstTime, points),
          maxX: _xOf(lastTime, points),
          minY: resolvedMinY,
          maxY: resolvedMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (value) => FlLine(
              color: tokens.lineRest,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 100,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: tokens.monoText(fontSize: 9, color: tokens.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: _xInterval(points),
                getTitlesWidget: (value, meta) {
                  final idx = (value - _xOf(firstTime, points)) ~/ 1;
                  if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _dayLabel(points[idx].time),
                      style: tokens.monoText(fontSize: 9, color: tokens.textSecondary),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touched) => tokens.bg,
              getTooltipItems: (touched) => touched.map((t) {
                final idx = t.spotIndex.clamp(0, points.length - 1);
                final p = points[idx];
                return LineTooltipItem(
                  '${_dayTimeLabel(p.time)}\n${p.value.round()} mg/dL',
                  TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: GlucoseTunables.targetLow.toDouble(),
                color: tokens.accent.withOpacity(0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
              HorizontalLine(
                y: GlucoseTunables.targetHigh.toDouble(),
                color: tokens.accent.withOpacity(0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.15,
              color: tokens.hero,
              barWidth: 2.5,
              dotData: FlDotData(
                show: points.length <= 24,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 2.5,
                  color: tokens.hero,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: tokens.hero.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _xOf(DateTime t, List<GlucoseChartPoint> points) {
    final anchor = points.first.time;
    return t.difference(anchor).inMinutes / 60.0;
  }

  static double _xInterval(List<GlucoseChartPoint> points) {
    final hours = points.last.time.difference(points.first.time).inHours;
    if (hours <= 24) return hours / 3.0;
    return hours / 4.0;
  }

  static String _dayLabel(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _dayTimeLabel(DateTime t) {
    final month = t.month.toString().padLeft(2, '0');
    final day = t.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$month/$day $h:$m';
  }
}