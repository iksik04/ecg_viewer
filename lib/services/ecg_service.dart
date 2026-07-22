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
      
      // Разбиваем на строки и фильтруем пустые
      final lines = rawData.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      
      if (lines.isEmpty) {
        print('Файл $path пуст');
        return [];
      }
      
      // Проверяем, есть ли заголовок
      int startIndex = 0;
      final firstLine = lines[0].trim();
      if (firstLine.contains(RegExp(r'[a-zA-Z]'))) {
        // Если первая строка содержит буквы, считаем её заголовком
        startIndex = 1;
      }
      
      final List<FlSpot> spots = [];
      
      for (int i = startIndex; i < lines.length; i++) {
        try {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          // Разделяем строку по запятой или точке с запятой
          final parts = line.contains(';') 
              ? line.split(';') 
              : line.split(',');
          
          if (parts.length < 2) {
            // Пропускаем строки с недостаточным количеством данных
            continue;
          }
          
          // Очищаем значения от пробелов и заменяем запятую на точку
          String xStr = parts[0].trim().replaceAll(',', '.');
          String yStr = parts[1].trim().replaceAll(',', '.');
          
          // Пропускаем пустые значения
          if (xStr.isEmpty || yStr.isEmpty) continue;
          
          // Парсим значения
          final double x = double.parse(xStr);
          final double y = double.parse(yStr);
          
          // Проверяем на допустимые значения
          if (x.isFinite && y.isFinite) {
            spots.add(FlSpot(x, y));
          } else {
            print('Пропущен некорректный фрейм: x=$x, y=$y');
          }
        } catch (e) {
          // Пропускаем некорректные строки
          print('Ошибка парсинга строки ${i + 1}: $e');
          continue;
        }
      }
      
      print('Загружено ${spots.length} точек из файла $path');
      return spots;
      
    } catch (e) {
      print('Ошибка загрузки файла $path: $e');
      return [];
    }
  }

  Future<List<int>> _loadPeaks(String folder, String number) async {
    try {
      String path = _fileService.getPeaksFilePath(folder, number);
      final rawData = await rootBundle.loadString(path);
      
      // Разбиваем на строки и фильтруем пустые
      final lines = rawData.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      
      if (lines.isEmpty) {
        print('Файл peaks $path пуст');
        return [];
      }
      
      // Проверяем, есть ли заголовок
      int startIndex = 0;
      final firstLine = lines[0].trim();
      if (firstLine.contains(RegExp(r'[a-zA-Z]'))) {
        startIndex = 1;
      }
      
      final List<int> peaks = [];
      
      for (int i = startIndex; i < lines.length; i++) {
        try {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          // Разделяем строку
          final parts = line.contains(';') 
              ? line.split(';') 
              : line.split(',');
          
          if (parts.isEmpty) continue;
          
          String valueStr = parts[0].trim();
          if (valueStr.isEmpty) continue;
          
          // Преобразуем в число с плавающей точкой, затем в целое
          final double value = double.parse(valueStr);
          final int intValue = value.round();
          
          peaks.add(intValue);
          
        } catch (e) {
          print('Ошибка парсинга peaks строки ${i + 1}: $e');
          continue;
        }
      }
      
      print('Загружено ${peaks.length} пиков из файла $path');
      return peaks;
      
    } catch (e) {
      print('Ошибка загрузки peaks для папки $folder, записи #$number: $e');
      return [];
    }
  }
}