import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_csv/flutter_csv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';
import '../services/file_service.dart';

class ECGService {
  final FileService _fileService = FileService();

  Future<ECGData> loadECGData(String folder, String number) async {
    try {
      final spots = await _loadSpots(folder, number);
      final peaks = await _loadPeaks(folder, number);
      return ECGData(spots: spots, peaks: peaks);
    } catch (e) {
      print('Ошибка загрузки данных для папки $folder, записи #$number: $e');
      return ECGData(spots: [], peaks: []);
    }
  }

  Future<List<FlSpot>> _loadSpots(String folder, String number) async {
    String path = _fileService.getDataFilePath(folder, number);
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

  Future<List<int>> _loadPeaks(String folder, String number) async {
    try {
      String path = _fileService.getPeaksFilePath(folder, number);
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
      print('Ошибка загрузки peaks для папки $folder, записи #$number: $e');
      return [];
    }
  }
}