import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_csv/flutter_csv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';
import '../constants/app_constants.dart';

class ECGService {
  Future<ECGData> loadECGData() async {
    try {
      final spots = await _loadSpots();
      final peaks = await _loadPeaks();
      return ECGData(spots: spots, peaks: peaks);
    } catch (e) {
      return ECGData(spots: [], peaks: []);
    }
  }

  Future<List<FlSpot>> _loadSpots() async {
    final rawData = await rootBundle.loadString(AppStrings.dataFilePath);
    final doc = FlutterCsv.parseDocument(
      rawData,
      firstRowIsHeader: true,
    );
    
    return doc.data
        .where((row) => row.length >= 2)
        .map((row) => FlSpot(
              double.parse(row[0].toString()),
              double.parse(row[1].toString()),
            ))
        .toList();
  }

  Future<List<int>> _loadPeaks() async {
    try {
      final rawData = await rootBundle.loadString(AppStrings.peaksFilePath);
      final doc = FlutterCsv.parseDocument(
        rawData,
        firstRowIsHeader: true,
      );
      
      return doc.data
          .where((row) => row.isNotEmpty)
          .map((row) => int.parse(row[0].toString()))
          .toList();
    } catch (e) {
      return [];
    }
  }
}