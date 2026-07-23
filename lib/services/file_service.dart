import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'dart:async';

class FileService {
  static Map<String, List<String>>? _cachedFilesByFolder;
  
  // Получение списка доступных папок
  Future<List<String>> getAvailableFolders() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      
      // Извлекаем уникальные имена папок из assets/data/
      final folders = allAssets
          .where((asset) => asset.startsWith('assets/data/'))
          .map((asset) {
            final parts = asset.split('/');
            if (parts.length >= 3) {
              return parts[2];
            }
            return '';
          })
          .where((folder) => folder.isNotEmpty)
          .toSet()
          .toList();
      
      folders.sort();
      return folders;
    } catch (e) {
      print('Ошибка загрузки папок: $e');
      return [];
    }
  }
  
  // Получение файлов для конкретной папки
  Future<List<String>> getAvailableFilesForFolder(String folder, {bool forceRefresh = false}) async {
    final cacheKey = 'folder_$folder';
    
    if (_cachedFilesByFolder != null && 
        _cachedFilesByFolder!.containsKey(cacheKey) && 
        !forceRefresh) {
      return _cachedFilesByFolder![cacheKey]!;
    }
    
    try {
      final files = await _scanAssetsInFolder(folder);
      
      if (_cachedFilesByFolder == null) {
        _cachedFilesByFolder = {};
      }
      _cachedFilesByFolder![cacheKey] = files;
      return files;
    } catch (e) {
      print('Ошибка загрузки файлов для папки $folder: $e');
      return [];
    }
  }
  
  Future<List<String>> _scanAssetsInFolder(String folder) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    
    // Фильтруем файлы из указанной папки
    final folderPath = 'assets/data/$folder/';
    final dataFiles = allAssets
        .where((asset) => 
            asset.startsWith(folderPath))
        .toList();
    
    // Извлекаем номера из имен файлов
    final numbers = dataFiles.map((filePath) {
      final fileName = filePath.split('/').last;
      // Удаляем '_channel1.csv' и получаем идентификатор
      return fileName.replaceFirst('.csv', '');
    }).toList();
    
    // Сортируем с учетом того, что имена могут быть не только числами
    numbers.sort((a, b) {
      // Пробуем распарсить как числа
      final aIsNumber = int.tryParse(a) != null;
      final bIsNumber = int.tryParse(b) != null;
      
      if (aIsNumber && bIsNumber) {
        // Оба числа - сортируем по числовому значению
        return int.parse(a).compareTo(int.parse(b));
      } else if (aIsNumber) {
        // Числа идут перед строками
        return -1;
      } else if (bIsNumber) {
        return 1;
      } else {
        // Оба не числа - сортируем как строки
        return a.compareTo(b);
      }
    });
    
    return numbers;
  }
  
  // Получение полного пути к файлу данных
  String getDataFilePath(String folder, String number) {
    return 'assets/data/$folder/${number}.csv';
  }
  
  // Получение полного пути к файлу пиков
  String getPeaksFilePath(String folder, String number, String type) {
    // type может быть 'true_peaks' или 'pred_peaks'
    return 'assets/$type/$folder/${number}_peaks.csv';
  }
  
  // Проверка существования peaks файла
  Future<bool> hasPeaksFile(String folder, String number, String type) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      final peaksPath = getPeaksFilePath(folder, number, type);
      return allAssets.contains(peaksPath);
    } catch (e) {
      try {
        await rootBundle.loadString(getPeaksFilePath(folder, number, type));
        return true;
      } catch (_) {
        return false;
      }
    }
  }
  
  Future<Map<String, dynamic>> getFileInfo(String folder, String number) async {
    final String filePath = getDataFilePath(folder, number);
    try {
      final String content = await rootBundle.loadString(filePath);
      final lines = content.split('\n');
      return {
        'exists': true,
        'size': content.length,
        'lines': lines.length,
        'hasTruePeaks': await hasPeaksFile(folder, number, 'true_peaks'),
        'hasPredPeaks': await hasPeaksFile(folder, number, 'pred_peaks'),
      };
    } catch (e) {
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
  
  // Очистка кэша
  void clearCache() {
    _cachedFilesByFolder = null;
  }
}