import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

const List<FlSpot> spots = [
  FlSpot(0, 0),
  FlSpot(1, 1),
  FlSpot(2, 2),
  FlSpot(3, 3),
  FlSpot(4, 4),
  FlSpot(5, 5),
  FlSpot(6, 0),
  FlSpot(7, 1),
  FlSpot(8, 2),
  FlSpot(9, 3),
  FlSpot(10, 5),
  FlSpot(11, 0),
  FlSpot(12, 1),
  FlSpot(13, 2),
  FlSpot(14, 3),
  FlSpot(15, 4),
  FlSpot(16, 5),
  FlSpot(17, 0),
  FlSpot(18, 1),
  FlSpot(19, 2),
  FlSpot(20, 3),
  FlSpot(21, 4),
  FlSpot(22, 5),
  FlSpot(23, 5),
  FlSpot(24, 0),
  FlSpot(25, 1),
  FlSpot(26, 2),
  FlSpot(27, 3),
  FlSpot(28, 4),
  FlSpot(29, 5),
  FlSpot(30, 0),
  FlSpot(31, 1),
  FlSpot(32, 2),
  FlSpot(33, 3),
  FlSpot(34, 4),
  FlSpot(35, 5),
  FlSpot(36, 0),
  FlSpot(37, 1),
  FlSpot(38, 2),
  FlSpot(39, 3),
  FlSpot(40, 4),
  FlSpot(41, 5),
  FlSpot(42, 0),
  FlSpot(43, 1),
  FlSpot(44, 2),
  FlSpot(45, 3),
  FlSpot(46, 5),
  FlSpot(47, 0),
  FlSpot(48, 1),
  FlSpot(49, 2),
  FlSpot(50, 3),
  FlSpot(51, 4),
  FlSpot(52, 5),
  FlSpot(53, 0),
  FlSpot(54, 1),
  FlSpot(55, 2),
  FlSpot(56, 3),
  FlSpot(57, 4),
  FlSpot(58, 5),
  FlSpot(59, 5),
  FlSpot(60, 0),
  FlSpot(61, 1),
  FlSpot(62, 2),
  FlSpot(63, 3),
  FlSpot(64, 4),
  FlSpot(65, 5),
  FlSpot(66, 0),
  FlSpot(67, 1),
  FlSpot(68, 2),
  FlSpot(69, 3),
  FlSpot(70, 4),
  FlSpot(71, 5),
  FlSpot(72, 0),
  FlSpot(73, 1),
  FlSpot(74, 2),
  FlSpot(75, 3),
  FlSpot(76, 4),
  FlSpot(77, 5),
  FlSpot(78, 0),
  FlSpot(79, 1),
  FlSpot(80, 2),
  FlSpot(81, 3),
  FlSpot(82, 5),
  FlSpot(83, 0),
  FlSpot(84, 1),
  FlSpot(85, 2),
  FlSpot(86, 3),
  FlSpot(87, 4),
  FlSpot(88, 5),
  FlSpot(89, 0),
  FlSpot(90, 1),
  FlSpot(91, 2),
  FlSpot(92, 3),
  FlSpot(93, 4),
  FlSpot(94, 5),
  FlSpot(95, 5),
  FlSpot(96, 0),
  FlSpot(97, 1),
  FlSpot(98, 2),
  FlSpot(99, 3),
  FlSpot(100, 4)
];

void main() => runApp(const ECGViewer());

class ECGViewer extends StatelessWidget {
  const ECGViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage()
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(239, 239, 239, 1),
      appBar: AppBar(
        title: const Text('ECG Viewer', style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1))),
        backgroundColor: Color.fromRGBO(52, 179, 171, 1)
      ),
      body:  Center(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: GraphiksWidget(spots: spots)
        )
      )
    );
  }
}

class GraphiksWidget extends StatelessWidget {
  final List<FlSpot> spots;

  const GraphiksWidget({
    required this.spots,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
        LineChartData(
          backgroundColor: Colors.white,
          lineBarsData: [ LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: false),
            )
          ],
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'x',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
              axisNameSize: 30,
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => customText(value, meta),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'y(x)',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
              axisNameSize: 30,
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 45,
                getTitlesWidget: (value, meta) => customText(value, meta),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: 5,
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
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.black,
              width: 1,
            )
          )
        )
    );
  }
}

Widget customText(double value, TitleMeta meta) {
  return Padding(
    padding: const EdgeInsets.all(10),
    child: Text(
      '$value',
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 15,
        letterSpacing: 1.2,
      ),
    ),
  );
}