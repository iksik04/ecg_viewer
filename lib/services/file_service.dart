import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path/path.dart' as path;
import 'dart:async';

class FileService {
  static List<String>? _cachedFiles;
  
  // Сканирование директории assets через AssetManifest
  Future<List<String>> getAvailableFiles({bool forceRefresh = false}) async {
    if (_cachedFiles != null && !forceRefresh) {
      return _cachedFiles!;
    }
    
    try {
      final files = await _scanAssets();
      _cachedFiles = files;
      return files;
    } catch (e) {
      return [];
    }
  }
  
  Future<List<String>> _scanAssets() async {
    // Загружаем манифест (работает в новых версиях Flutter)
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    
    // Получаем все ресурсы
    final allAssets = manifest.listAssets();
    
    // Фильтруем только файлы из assets/data/ с паттерном {number}_channel1.csv
    final dataFiles = allAssets.where((asset) => 
      asset.startsWith('assets/data/')
    ).toList();
    
    // Извлекаем номера из имен файлов
    final numbers = dataFiles.map((filePath) {
      // Пример: 'assets/data/100_channel1.csv' -> '100'
      final fileName = path.basename(filePath);
      return fileName.replaceFirst('_channel1.csv', '');
    }).toList();
    
    // Сортируем по числовому значению
    numbers.sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    return numbers;
  }
  
  Future<void> refreshCache() async {
    _cachedFiles = null;
    await getAvailableFiles(forceRefresh: true);
  }
  
  // Проверка существования peaks файла через AssetManifest
  Future<bool> hasPeaksFile(String number) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      final peaksPath = 'assets/peaks/${number}peaks.csv';
      return allAssets.contains(peaksPath);
    } catch (e) {
      // Если манифест не загрузился, пробуем старый способ (для обратной совместимости)
      try {
        await rootBundle.loadString('assets/peaks/${number}peaks.csv');
        return true;
      } catch (_) {
        return false;
      }
    }
  }
  
  Future<Map<String, dynamic>> getFileInfo(String number) async {
    final String filePath = 'assets/data/${number}_channel1.csv';
    try {
      final String content = await rootBundle.loadString(filePath);
      final lines = content.split('\n');
      return {
        'exists': true,
        'size': content.length,
        'lines': lines.length,
        'hasPeaks': await hasPeaksFile(number),
      };
    } catch (e) {
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
}