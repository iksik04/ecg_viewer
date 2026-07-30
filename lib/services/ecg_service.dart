import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';
import '../constants/app_constants.dart';

class ECGService {
  final String _rdsampPath = AppStrings.rdsampPath;
  final String _rdannPath = AppStrings.rdannPath;
  static const String _basePath = AppStrings.basePath;
  
  /// Загрузка данных ЭКГ с использованием rdsamp и rdann
  Future<ECGData> loadECGData(String folder, String number) async {
    try {
      // Для WFDB утилит нужно передавать имя записи без расширения
      // и без полного пути, если мы не используем переменную WFDB
      final recordName = '$folder/$number';
      final fullPath = '$_basePath\\$folder\\$number';
      
      print('Загрузка данных: $recordName');
      print('Полный путь: $fullPath');
      
      // Проверяем существование файлов
      final heaFile = File(fullPath + '.hea');
      if (!await heaFile.exists()) {
        print('Файл $fullPath.hea не найден');
        return ECGData(spots: [], truePeaks: [], predPeaks: []);
      }
      
      final datFile = File(fullPath + '.dat');
      if (!await datFile.exists()) {
        print('Файл $fullPath.dat не найден');
        return ECGData(spots: [], truePeaks: [], predPeaks: []);
      }
      
      // Загружаем данные через rdsamp
      final spots = await _loadSpotsWithRDSamp(recordName, fullPath);
      
      // Загружаем истинные пики из .atr файла
      final truePeaks = await _loadPeaksWithRDAnn(recordName, fullPath, 'atr');
      
      // Загружаем предсказанные пики из .gqrs файла
      final predPeaks = await _loadPeaksWithRDAnn(recordName, fullPath, 'gqrs');
      
      // Получаем частоту дискретизации
      final sampleRate = await getSampleRate(fullPath);
      
      return ECGData(
        spots: spots,
        truePeaks: truePeaks,
        predPeaks: predPeaks,
        sampleRate: sampleRate,
      );
    } catch (e) {
      print('Ошибка загрузки данных для папки $folder, записи #$number: $e');
      return ECGData(spots: [], truePeaks: [], predPeaks: []);
    }
  }
  
  /// Загрузка данных через rdsamp
  Future<List<FlSpot>> _loadSpotsWithRDSamp(String recordName, String fullPath) async {
    try {
      // Проверяем существование .hea файла
      final heaFile = File(fullPath + '.hea');
      if (!await heaFile.exists()) {
        print('Файл $fullPath.hea не найден');
        return [];
      }
      
      // Используем путь с прямой косой чертой для совместимости с WFDB
      // Важно: передаем имя записи, а не полный путь
      final recordPath = recordName.replaceAll('\\', '/');
      
      print('Вызов rdsamp: $_rdsampPath -r $recordPath -f 0 -t end -p -v');
      
      // Запускаем rdsamp для чтения данных
      final process = await Process.start(
        _rdsampPath,
        ['-r', recordPath, '-f', '0', '-t', 'end', '-p', '-v'],
        mode: ProcessStartMode.normal,
        environment: {
          'WFDB': _basePath,
        },
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
  Future<List<int>> _loadPeaksWithRDAnn(String recordName, String fullPath, String annotationType) async {
    try {
      // Проверяем существование файла аннотации
      final annFile = File('$fullPath.$annotationType');
      if (!await annFile.exists()) {
        print('Файл $fullPath.$annotationType не найден');
        return [];
      }
      
      // Используем путь с прямой косой чертой для совместимости с WFDB
      final recordPath = recordName.replaceAll('\\', '/');
      
      print('Вызов rdann: $_rdannPath -r $recordPath -a $annotationType -f 0 -t end');
      
      // Запускаем rdann для чтения аннотаций
      final process = await Process.start(
        _rdannPath,
        ['-r', recordPath, '-a', annotationType, '-f', '0', '-t', 'end'],
        mode: ProcessStartMode.normal,
        environment: {
          'WFDB': _basePath,
        },
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
      final peaks = _parseRDAnnOutput(output);
      print('Загружено ${peaks.length} пиков из аннотаций $annotationType');
      return peaks;
      
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
        
        // Вторая колонка - номер выборки (sample number)
        final sampleNumber = int.tryParse(parts[1]);
        if (sampleNumber == null) continue;
        
        // Третья колонка - тип аннотации
        final annType = parts[2];
        
        // Проверяем, является ли аннотация QRS-комплексом
        if (_isQRSAnnotation(annType)) {
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
  Future<double> getSampleRate(String fullPath) async {
    try {
      final heaFile = File(fullPath + '.hea');
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