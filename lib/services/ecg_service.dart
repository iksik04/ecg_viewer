import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';

class ECGService {
  final String _rdsampPath = 'rdsamp';
  
  /// Загрузка данных ЭКГ с использованием rdsamp
  Future<ECGData> loadECGData(String folder, String number) async {
    try {
      // Путь к файлам записи (без расширения)
      final filePath = 'assets/ECG_DB/$folder/$number';
      
      // Загружаем данные через rdsamp
      final spots = await _loadSpotsWithRDSamp(filePath);
      
      return ECGData(
        spots: spots,
        truePeaks: [],
        predPeaks: [],
      );
    } catch (e) {
      print('Ошибка загрузки данных для папки $folder, записи #$number: $e');
      return ECGData(spots: [], truePeaks: [], predPeaks: []);
    }
  }
  
  /// Загрузка данных через rdsamp
  Future<List<FlSpot>> _loadSpotsWithRDSamp(String filePath) async {
    try {
      // Проверяем существование .dat файла
      final datFile = File(filePath + '.dat');
      if (!await datFile.exists()) {
        print('Файл $filePath.dat не найден');
        return [];
      }
      
      // Запускаем rdsamp для чтения данных
      // -r: путь к файлу (без расширения)
      // -f: начальное время (0)
      // -t: конечное время (читаем весь файл)
      // -p: вывод в формате с временными метками
      // -v: вывод значений
      final process = await Process.start(
        _rdsampPath,
        ['-r', filePath, '-f', '0', '-t', 'end', '-p', '-v'],
        mode: ProcessStartMode.normal,
      );
      
      // Читаем вывод
      final output = await process.stdout.transform(utf8.decoder).join();
      final stderr = await process.stderr.transform(utf8.decoder).join();
      
      // Проверяем ошибки
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('Ошибка rdsamp (код $exitCode): $stderr');
        return [];
      }
      
      // Парсим вывод
      return _parseRDSampOutput(output);
      
    } catch (e) {
      print('Ошибка выполнения rdsamp: $e');
      return [];
    }
  }
  
  /// Парсинг вывода rdsamp
  List<FlSpot> _parseRDSampOutput(String output) {
    final lines = output.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    if (lines.isEmpty) {
      print('Вывод rdsamp пуст');
      return [];
    }
    
    final spots = <FlSpot>[];
    
    for (final line in lines) {
      try {
        // Формат с ключом -p: "время\tзначение1\tзначение2..."
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 2) continue;
        
        final time = double.parse(parts[0]);
        // Берем первый канал (индекс 1)
        final value = double.parse(parts[1]);
        
        if (time.isFinite && value.isFinite) {
          spots.add(FlSpot(time, value));
        }
      } catch (e) {
        // Пропускаем некорректные строки
        continue;
      }
    }
    
    print('Загружено ${spots.length} точек через rdsamp');
    return spots;
  }
  
  /// Проверка доступности rdsamp
  Future<bool> isRDSampAvailable() async {
    try {
      final result = await Process.run(_rdsampPath, ['--help']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}