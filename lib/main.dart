import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_csv/flutter_csv.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const ECGViewer());


class ECGViewer extends StatelessWidget {
  const ECGViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<FlSpot>>? _futureSpots;

  @override
  void initState() {
    super.initState();
    _futureSpots = loadCsvData();
  }

  Future<List<FlSpot>> loadCsvData() async {
    try {
      final rawData = await rootBundle.loadString('assets/data.csv');
      
      final doc = FlutterCsv.parseDocument(
        rawData,
        firstRowIsHeader: true,
      );
      
      final data = doc.data;
      
      List<FlSpot> spots = [];
      
      for (var row in data) {
        if (row.length >= 2) {
          double x = double.parse(row[0].toString());
          double y = double.parse(row[1].toString());
          spots.add(FlSpot(x, y));
        }
      }
      return spots;
    } catch (e) {

      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(239, 239, 239, 1),
      appBar: AppBar(
        title: const Text('ECG Viewer', style: TextStyle(color: Colors.white),),
        backgroundColor: const Color.fromRGBO(52, 179, 171, 1),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: FutureBuilder<List<FlSpot>>(
            future: _futureSpots,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Ошибка: ${snapshot.error}');
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('Нет данных');
              }
              
              final spots = snapshot.data!;
              return InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                constrained: false,
                child: SizedBox(
                  height: 600,
                  width: spots.length * 25,
                  child: GraphiksWidget(spots: spots),
                ),
              );
            },
          ),
        ),
      ),
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
              sideTitles: SideTitles(showTitles: true,  reservedSize: 5),
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