import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';

class ECGService {
  final String _rdsampPath = 'rdsamp';
  final String _rdannPath = 'rdann';
  
  /// Загрузка данных ЭКГ с использованием rdsamp и rdann
  Future<ECGData> loadECGData(String folder, String number) async {
    try {
      // Путь к файлам записи (без расширения)
      final filePath = 'assets/ECG_DB/$folder/$number';
      
      // Загружаем данные через rdsamp
      final spots = await _loadSpotsWithRDSamp(filePath);
      
      // Загружаем истинные пики из .atr файла
      final truePeaks = await _loadPeaksWithRDAnn(filePath, 'atr');
      
      // Загружаем предсказанные пики из .gqrs файла
      final predPeaks = await _loadPeaksWithRDAnn(filePath, 'gqrs');
      
      return ECGData(
        spots: spots,
        truePeaks: truePeaks,
        predPeaks: predPeaks,
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
  
  /// Загрузка пиков через rdann
  Future<List<int>> _loadPeaksWithRDAnn(String filePath, String annotationType) async {
    try {
      // Проверяем существование файла аннотации
      final annFile = File('$filePath.$annotationType');
      if (!await annFile.exists()) {
        print('Файл $filePath.$annotationType не найден');
        return [];
      }
      print('Вызов rdann: rdann -r $filePath -a $annotationType -f 0 -t end');
      // Запускаем rdann для чтения аннотаций
      // -r: путь к файлу записи
      // -a: тип аннотации (atr, gqrs, и т.д.)
      // -p: вывод в формате с временными метками
      // -f: начальное время (0)
      // -t: конечное время (читаем весь файл)
      final process = await Process.start(
        _rdannPath,
        ['-r', filePath, '-a', annotationType, '-f', '0', '-t', 'end'],
        mode: ProcessStartMode.normal,
      );
      
      // Читаем вывод
      final output = await process.stdout.transform(utf8.decoder).join();
      final stderr = await process.stderr.transform(utf8.decoder).join();
      
      // Проверяем ошибки
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('Ошибка rdann для $annotationType (код $exitCode): $stderr');
        return [];
      }
      
      // Парсим вывод и возвращаем индексы пиков
      return _parseRDAnnOutput(output);
      
    } catch (e) {
      print('Ошибка выполнения rdann для $annotationType: $e');
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
  
   List<int> _parseRDAnnOutput(String output) {
    final lines = output.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    if (lines.isEmpty) {
      print('Вывод rdann пуст');
      return [];
    }
    
    final peakIndices = <int>[];
    
    for (final line in lines) {
      try {
        // Разбиваем строку по пробелам и табуляциям
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 3) continue;
        
        // Первая колонка - время в формате MM:SS.mmm
        final timeStr = parts[0];
        final timeInSeconds = _parseTimeString(timeStr);
        if (timeInSeconds == null) continue;
        
        // Вторая колонка - номер выборки (sample number)
        final sampleNumber = int.tryParse(parts[1]);
        if (sampleNumber == null) continue;
        
        // Третья колонка - тип аннотации
        final annotationType = parts[2];
        
        // Проверяем, является ли аннотация QRS-комплексом
        if (_isQRSAnnotation(annotationType)) {
          // Используем номер выборки как индекс
          // Номера выборок обычно начинаются с 0
          if (sampleNumber >= 0) {
            peakIndices.add(sampleNumber);
          }
        }
      } catch (e) {
        // Пропускаем некорректные строки
        continue;
      }
    }
    
    print('Загружено ${peakIndices.length} пиков из аннотаций');
    return peakIndices;
  }
  
  /// Парсинг времени из формата "MM:SS.mmm" в секунды
  double? _parseTimeString(String timeStr) {
    try {
      // Формат: MM:SS.mmm или MM:SS
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      
      final minutes = int.parse(parts[0]);
      final secondsPart = parts[1];
      
      // Разделяем секунды и миллисекунды
      final secParts = secondsPart.split('.');
      final seconds = int.parse(secParts[0]);
      final milliseconds = secParts.length > 1 
          ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
          : 0;
      
      return minutes * 60 + seconds + milliseconds / 1000.0;
    } catch (e) {
      return null;
    }
  }
  
  /// Определение, является ли аннотация QRS-комплексом
  bool _isQRSAnnotation(String annotationType) {
    // Стандартные типы аннотаций для MIT-BIH
    const qrsTypes = {'N', 'L', 'R', 'B', 'A', 'a', 'J', 'S', 'V', 'r', 'F', 'e', 'j', 'n', 'E', 'f', 'Q', '?'};
    return qrsTypes.contains(annotationType);
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
  
  /// Проверка доступности rdann
  Future<bool> isRDAnnAvailable() async {
    try {
      final result = await Process.run(_rdannPath, ['--help']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Получение частоты дискретизации из .hea файла
  Future<double> getSampleRate(String filePath) async {
    try {
      final heaFile = File(filePath + '.hea');
      if (!await heaFile.exists()) {
        return 360.0; // Значение по умолчанию для MIT-BIH
      }
      
      final content = await heaFile.readAsString();
      final lines = content.split('\n');
      
      for (final line in lines) {
        // Ищем строку с частотой дискретизации
        // Формат: "sample_rate: значение" или просто число после сигнатуры
        final match = RegExp(r'(\d+)\s+(\d+)\s+(\d+)\s+(\d+(?:\.\d+)?)').firstMatch(line);
        if (match != null && match.groupCount >= 4) {
          return double.parse(match.group(4)!);
        }
      }
      
      return 360.0; // Значение по умолчанию
    } catch (e) {
      print('Ошибка чтения .hea файла: $e');
      return 360.0;
    }
  }
}