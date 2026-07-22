import 'package:fl_chart/fl_chart.dart';

class ECGData {
  final List<FlSpot> spots;
  final List<int> truePeaks;
  final List<int> predPeaks;

  ECGData({
    required this.spots,
    required this.truePeaks,
    required this.predPeaks,
  });

  bool get isEmpty => spots.isEmpty;
}