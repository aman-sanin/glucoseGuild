/// A single glucose reading for charting.
///
/// `time` is the actual logging timestamp (`loggedAt ?? createdAt`); `value`
/// is the raw `numericValue` in mg/dL.
class GlucoseChartPoint {
  final DateTime time;
  final double value;

  const GlucoseChartPoint({required this.time, required this.value});
}