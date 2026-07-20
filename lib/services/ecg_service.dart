import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_csv/flutter_csv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';
import '../constants/app_constants.dart';

class ECGService {
  Future<ECGData> loadECGData(String number) async {
    try {
      final spots = await _loadSpots(number);
      final peaks = await _loadPeaks(number);
      return ECGData(spots: spots, peaks: peaks);
    } catch (e) {
      print('Ошибка загрузки данных для записи #$number: $e');
      return ECGData(spots: [], peaks: []);
    }
  }

  Future<List<FlSpot>> _loadSpots(String number) async {
    String path = '${AppStrings.dataFilePath}${number}_channel1.csv';
    try {
      final rawData = await rootBundle.loadString(path);
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
    } catch (e) {
      print('Ошибка загрузки файла $path: $e');
      return [];
    }
  }

  Future<List<int>> _loadPeaks(String number) async {
    try {
      String path = '${AppStrings.peaksFilePath}${number}peaks.csv';
      final rawData = await rootBundle.loadString(path);
      final doc = FlutterCsv.parseDocument(
        rawData,
        firstRowIsHeader: true,
      );
      
      return doc.data
          .where((row) => row.isNotEmpty)
          .map((row) => int.parse(row[0].toString()))
          .toList();
    } catch (e) {
      print('Ошибка загрузки peaks для записи #$number: $e');
      return [];
    }
  }
}