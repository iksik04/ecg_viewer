import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';

class ECGChart extends StatelessWidget {
  final ECGData data;

  const ECGChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        backgroundColor: Colors.white,
        lineBarsData: [
          LineChartBarData(
            spots: data.spots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          )
        ],
        titlesData: _buildTitlesData(),
        gridData: _buildGridData(),
        borderData: _buildBorderData(),
        extraLinesData: ExtraLinesData(
          verticalLines: _buildVerticalLines(),
        ),
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 5),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text(
          'Время, сек',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        axisNameSize: 30,
        sideTitles: SideTitles(
          showTitles: true,
          interval: 0.5,
          reservedSize: 40,
          getTitlesWidget: _customTextWidget,
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text(
          'Напряжение, мВ',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        axisNameSize: 30,
        sideTitles: SideTitles(
          showTitles: true,
          interval: 0.5,
          reservedSize: 60,
          getTitlesWidget: _customTextWidget,
        ),
      ),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: 0.1,
      verticalInterval: 0.1,
      getDrawingHorizontalLine: (value) {
        return const FlLine(
          color: Colors.grey,
          strokeWidth: 0.5,
        );
      },
      getDrawingVerticalLine: (value) {
        return const FlLine(
          color: Colors.grey,
          strokeWidth: 0.5,
        );
      },
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(
        color: Colors.black,
        width: 1,
      ),
    );
  }

  List<VerticalLine> _buildVerticalLines() {
    return data.peaks
        .where((index) => index >= 0 && index < data.spots.length)
        .map((index) => VerticalLine(
              x: data.spots[index].x,
              color: Colors.red,
              strokeWidth: 2,
            ))
        .toList();
  }

  Widget _customTextWidget(double value, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        value.toStringAsFixed(2),
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}