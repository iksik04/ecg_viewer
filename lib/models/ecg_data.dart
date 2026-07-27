import 'package:fl_chart/fl_chart.dart';

class ECGData {
  final List<FlSpot> spots;
  final List<int> truePeaks;
  final List<int> predPeaks;
  final double sampleRate; // Частота дискретизации

  ECGData({
    required this.spots,
    required this.truePeaks,
    required this.predPeaks,
    this.sampleRate = 360.0, // Значение по умолчанию
  });

  bool get isEmpty => spots.isEmpty;
}