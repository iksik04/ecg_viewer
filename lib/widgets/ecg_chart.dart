import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';
import '../constants/app_constants.dart';

class ECGChart extends StatefulWidget {
  final ECGData data;
  final int startIndex;
  final int pointsPerScreen;

  const ECGChart({
    super.key,
    required this.data,
    required this.startIndex,
    required this.pointsPerScreen,
  });

  @override
  State<ECGChart> createState() => _ECGChartState();
}

class _ECGChartState extends State<ECGChart> {
  @override
  Widget build(BuildContext context) {
    final visibleSpots = _getVisibleSpots();
    final visiblePeakSpots = _getVisiblePeakSpots();

    if (visibleSpots.isEmpty) {
      return const Center(
        child: Text('Нет данных для отображения'),
      );
    }

    return LineChart(
      LineChartData(
        backgroundColor: AppColors.white,
        lineBarsData: [
          // Основной сигнал ECG
          LineChartBarData(
            spots: visibleSpots,
            isCurved: false,
            color: AppColors.ecgLine,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          // Отображение пиков (как точки на графике поверх линии)
          if (visiblePeakSpots.isNotEmpty)
            LineChartBarData(
              spots: visiblePeakSpots,
              isCurved: false,
              color: AppColors.peakLine,
              barWidth: 4,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: AppColors.peakLine,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
            ),
        ],
        titlesData: _buildTitlesData(),
        gridData: _buildGridData(),
        borderData: _buildBorderData(),
        // ГРАНИЦЫ БЕРЕМ ИЗ РЕАЛЬНЫХ ДАННЫХ
        minX: visibleSpots.first.x,
        maxX: visibleSpots.last.x,
        // Границы Y рассчитываем с отступом
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

  // Получаем координаты только для пиков, попавших в текущий диапазон
  List<FlSpot> _getVisiblePeakSpots() {
    final start = widget.startIndex;
    final end = start + widget.pointsPerScreen;
    
    return widget.data.peaks
        .where((index) => index >= start && index < end)
        .map((index) => widget.data.spots[index])
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
          interval: 1,
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
          interval: 0.5, // Уменьшил интервал для большей точности
          reservedSize: 60,
          getTitlesWidget: _customRightTextWidget,
        ),
      ),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: 0.1,
      verticalInterval: 0.5,
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

  Widget _customBottomTextWidget(double value, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        value.toStringAsFixed(0),
        textAlign: TextAlign.right,
        style: AppTextStyles.axisValue,
      ),
    );
  }

    Widget _customRightTextWidget(double value, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        value.toStringAsFixed(2),
        textAlign: TextAlign.right,
        style: AppTextStyles.axisValue,
      ),
    );
  }
}