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
  Future<List<int>>? _futurePeaks;

  @override
  void initState() {
    super.initState();
    _futureSpots = loadCsvData();
    _futurePeaks = loadPeaksData();
  }

  Future<List<FlSpot>> loadCsvData() async {
    try {
      final rawData = await rootBundle.loadString('assets/100.csv');
      
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

  Future<List<int>> loadPeaksData() async {
    try {
      final rawData = await rootBundle.loadString('assets/100peaks.csv');
      
      final doc = FlutterCsv.parseDocument(
        rawData,
        firstRowIsHeader: true,
      );
      
      final data = doc.data;
      List<int> peaks = [];
      
      for (var row in data) {
        if (row.isNotEmpty) {
          // Предполагаем, что в файле один столбец с индексами пиков
          int peakIndex = int.parse(row[0].toString());
          peaks.add(peakIndex);
        }
      }
      return peaks;
    } catch (e) {
      // В случае ошибки возвращаем пустой список или тестовые данные
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(239, 239, 239, 1),
      appBar: AppBar(
        title: const Text('ECG Viewer', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(52, 179, 171, 1),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: FutureBuilder<List<FlSpot>>(
            future: _futureSpots, 
            builder: (context, spotsSnapshot) {
              if (spotsSnapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (spotsSnapshot.hasError) {
                return Text('Ошибка загрузки данных: ${spotsSnapshot.error}');
              } else if (!spotsSnapshot.hasData || spotsSnapshot.data!.isEmpty) {
                return const Text('Нет данных ECG');
              }
              
              final spots = spotsSnapshot.data!;
              
              return FutureBuilder<List<int>>(
                future: _futurePeaks,
                builder: (context, peaksSnapshot) {
                  List<int> peaks = [];
                  
                  if (peaksSnapshot.connectionState == ConnectionState.waiting) {
                    // Показываем график без пиков, пока они загружаются
                    peaks = [];
                  } else if (peaksSnapshot.hasError) {
                    // В случае ошибки показываем график без пиков
                    peaks = [];
                  } else if (peaksSnapshot.hasData) {
                    peaks = peaksSnapshot.data!;
                  }
                  
                  return InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    constrained: false,
                    child: SizedBox(
                      height: 600,
                      width: spots.length.toDouble(),
                      child: GraphiksWidget(
                        spots: spots, 
                        peaks: peaks,
                      ),
                    ),
                  );
                },
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
  final List<int> peaks;

  const GraphiksWidget({
    required this.spots, 
    required this.peaks,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        backgroundColor: Colors.white,
        lineBarsData: [
          LineChartBarData(
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
            sideTitles: SideTitles(showTitles: true, reservedSize: 5),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text(
              'Time, sec',
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
              getTitlesWidget: (value, meta) => customText(value, meta),
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text(
              'Voltage, mV',
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
              getTitlesWidget: (value, meta) => customText(value, meta),
            ),
          ),
        ),
        gridData: FlGridData(
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
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Colors.black,
            width: 1,
          )
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: _buildVerticalLines(),
        )
      )
    );
  }

  List<VerticalLine> _buildVerticalLines() {
    List<VerticalLine> lines = [];
    
    for (int index in peaks) {
      if (index >= 0 && index < spots.length) {
        final x = spots[index].x;
        lines.add(
          VerticalLine(
            x: x,
            color: Colors.red,
            strokeWidth: 2,
          ),
        );
      }
    }
    return lines;
  }

  Widget customText(double value, TitleMeta meta) {
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