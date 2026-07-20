import 'package:fl_chart/fl_chart.dart';

class ECGData {
  final List<FlSpot> spots;
  final List<int> peaks;

  ECGData({
    required this.spots,
    required this.peaks,
  });

  bool get isEmpty => spots.isEmpty;
}