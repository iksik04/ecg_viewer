import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';
import '../constants/app_constants.dart';

class ECGChart extends StatefulWidget {
  final ECGData data;
  final int startIndex;
  final int pointsPerScreen;
  final double targetSecondsPerScreen;
  final bool showTruePeaks;
  final bool showPredPeaks;

  const ECGChart({
    super.key,
    required this.data,
    required this.startIndex,
    required this.pointsPerScreen,
    required this.targetSecondsPerScreen,
    this.showTruePeaks = false,
    this.showPredPeaks = true,
  });

  @override
  State<ECGChart> createState() => _ECGChartState();
}

class _ECGChartState extends State<ECGChart> {

  @override
  Widget build(BuildContext context) {
    final visibleSpots = _getVisibleSpots();

    if (visibleSpots.isEmpty) {
      return const Center(
        child: Text('Нет данных для отображения'),
      );
    }

    final truePeaksLines = _getTruePeaks();
    final predPeaksLines = _getPredPeaks();

    // Объединяем все вертикальные линии
    final allVerticalLines = <VerticalLine>[];
    if (widget.showTruePeaks) {
      allVerticalLines.addAll(truePeaksLines);
    }
    if (widget.showPredPeaks) {
      allVerticalLines.addAll(predPeaksLines);
    }

    return LineChart(
      LineChartData(
        backgroundColor: AppColors.white,
        lineBarsData: [
          LineChartBarData(
            spots: visibleSpots,
            isCurved: false,
            color: AppColors.ecgLine,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: _buildTitlesData(),
        gridData: _buildGridData(),
        borderData: _buildBorderData(),
        extraLinesData: ExtraLinesData(
          verticalLines: allVerticalLines,
        ),
        minX: visibleSpots.first.x,
        maxX: visibleSpots.last.x,
        minY: _getMinY(visibleSpots),
        maxY: _getMaxY(visibleSpots),
      ),
      duration: const Duration(milliseconds: 150),
    );
  }

  List<FlSpot> _getVisibleSpots() {
    final start = widget.startIndex;
    final end = start + widget.pointsPerScreen;
    
    if (start >= widget.data.spots.length) return [];
    
    return widget.data.spots.sublist(
      start,
      end > widget.data.spots.length ? widget.data.spots.length : end,
    );
  }

  List<VerticalLine> _getTruePeaks() {
    final start = widget.startIndex;
    final end = start + widget.pointsPerScreen;
    
    return widget.data.truePeaks
        .where((index) => index >= start && index < end)
        .map((index) {
          final spot = widget.data.spots[index];
          return VerticalLine(
            x: spot.x,
            color: AppColors.truePeakLine,
            strokeWidth: 4,
            dashArray: const [4, 4],
          );
        })
        .toList();
  }

  List<VerticalLine> _getPredPeaks() {
    final start = widget.startIndex;
    final end = start + widget.pointsPerScreen;
    
    return widget.data.predPeaks
        .where((index) => index >= start && index < end)
        .map((index) {
          final spot = widget.data.spots[index];
          return VerticalLine(
            x: spot.x,
            color: AppColors.predPeakLine,
            strokeWidth: 4,
            dashArray: const [4, 4],
          );
        })
        .toList();
  }

  double _getMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return -1;
    return spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 0.05;
  }

  double _getMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    return spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 0.05;
  }

  FlTitlesData _buildTitlesData() {
    final interval = _calculateXInterval();
    
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: Text(
          AppStrings.axisTime,
          style: AppTextStyles.axisLabel,
        ),
        axisNameSize: 30,
        sideTitles: SideTitles(
          showTitles: true,
          interval: interval,
          reservedSize: 40,
          getTitlesWidget: _customBottomTextWidget,
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          AppStrings.axisVoltage,
          style: AppTextStyles.axisLabel,
        ),
        axisNameSize: 30,
        sideTitles: SideTitles(
          showTitles: true,
          interval: 0.5,
          reservedSize: 60,
          getTitlesWidget: _customLeftTextWidget,
        ),
      ),
    );
  }

  double _calculateXInterval() {
    final visibleSpots = _getVisibleSpots();
    if (visibleSpots.isEmpty) return 1.0;
    
    final timeRange = visibleSpots.last.x - visibleSpots.first.x;
    
    if (timeRange <= 2) {
      return 0.2;
    } else if (timeRange <= 5) {
      return 0.5;
    } else if (timeRange <= 10) {
      return 1.0;
    } else if (timeRange <= 20) {
      return 2.0;
    } else if (timeRange <= 50) {
      return 5.0;
    } else {
      return 10.0;
    }
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: 0.1,
      verticalInterval: _calculateXInterval() / 2,
      getDrawingHorizontalLine: (value) {
        return const FlLine(
          color: AppColors.grey,
          strokeWidth: 0.5,
        );
      },
      getDrawingVerticalLine: (value) {
        return const FlLine(
          color: AppColors.grey,
          strokeWidth: 0.5,
        );
      },
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(
        color: AppColors.black,
        width: 1,
      ),
    );
  }

  Widget _customLeftTextWidget(double value, TitleMeta meta) {
    final min = meta.min;
    final max = meta.max;
                   
    if (value == min || value == max) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        value.toStringAsFixed(1),
        textAlign: TextAlign.right,
        style: AppTextStyles.axisValue,
      ),
    );
  }

  Widget _customBottomTextWidget(double value, TitleMeta meta) {
    final min = meta.min;
    final max = meta.max;
                   
    if (value == min || value == max) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        value.toStringAsFixed(1),
        textAlign: TextAlign.right,
        style: AppTextStyles.axisValue,
      ),
    );
  }
}