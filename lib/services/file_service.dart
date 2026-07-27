import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'dart:async';

class FileService {
  static Map<String, List<String>>? _cachedRecordsByFolder;
  
  // Получение списка доступных папок (баз данных)
  Future<List<String>> getAvailableFolders() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      
      // Извлекаем уникальные имена папок из assets/ECG_DB/
      final folders = allAssets
          .where((asset) => asset.startsWith('assets/ECG_DB/'))
          .map((asset) {
            final parts = asset.split('/');
            if (parts.length >= 3) {
              return parts[2]; // Имя базы данных (AHADB, CUDB, и т.д.)
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
  
  // Получение записей для конкретной папки
  Future<List<String>> getAvailableRecordsForFolder(String folder, {bool forceRefresh = false}) async {
    final cacheKey = 'folder_$folder';
    
    if (_cachedRecordsByFolder != null && 
        _cachedRecordsByFolder!.containsKey(cacheKey) && 
        !forceRefresh) {
      return _cachedRecordsByFolder![cacheKey]!;
    }
    
    try {
      final records = await _scanRecordsInFolder(folder);
      
      if (_cachedRecordsByFolder == null) {
        _cachedRecordsByFolder = {};
      }
      _cachedRecordsByFolder![cacheKey] = records;
      return records;
    } catch (e) {
      print('Ошибка загрузки записей для папки $folder: $e');
      return [];
    }
  }
  
  Future<List<String>> _scanRecordsInFolder(String folder) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    
    // Фильтруем файлы из указанной папки
    final folderPath = 'assets/ECG_DB/$folder/';
    final assetsInFolder = allAssets
        .where((asset) => asset.startsWith(folderPath))
        .toList();
    
    // Извлекаем уникальные имена записей из файлов с расширением .hea (регистронезависимо)
    final Set<String> records = {};
    for (final asset in assetsInFolder) {
      final fileName = asset.split('/').last;
      
      // Проверяем, что файл имеет расширение .hea (регистронезависимо)
      final lowerFileName = fileName.toLowerCase();
      if (lowerFileName.endsWith('.hea')) {
        // Убираем расширение (все 4 символа, включая точку)
        final recordName = fileName.substring(0, fileName.length - 4);
        if (recordName.isNotEmpty) {
          records.add(recordName);
        }
      }
    }
    
    // Сортируем записи
    final sortedRecords = records.toList();
    sortedRecords.sort((a, b) {
      // Пробуем распарсить как числа
      final aIsNumber = int.tryParse(a) != null;
      final bIsNumber = int.tryParse(b) != null;
      
      if (aIsNumber && bIsNumber) {
        return int.parse(a).compareTo(int.parse(b));
      } else if (aIsNumber) {
        return -1;
      } else if (bIsNumber) {
        return 1;
      } else {
        return a.compareTo(b);
      }
    });
    
    return sortedRecords;
  }
  
  // Проверка существования файла (регистронезависимо)
  Future<bool> fileExists(String filePath) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      
      // Ищем файл регистронезависимо
      final fileName = filePath.split('/').last;
      final lowerFileName = fileName.toLowerCase();
      
      for (final asset in allAssets) {
        if (asset.endsWith('/$fileName') || 
            asset.toLowerCase().endsWith('/$lowerFileName')) {
          return true;
        }
      }
      
      // Если не нашли через манифест, пробуем загрузить напрямую
      try {
        await rootBundle.loadString(filePath);
        return true;
      } catch (_) {
        return false;
      }
    } catch (e) {
      try {
        await rootBundle.loadString(filePath);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
  
  // Получение списка всех файлов для записи
  Future<Map<String, bool>> getRecordFiles(String folder, String record) async {
    final basePath = 'assets/ECG_DB/$folder/$record';
    final extensions = ['aed', 'atr', 'hea', 'dat', 'gqrs'];
    final result = <String, bool>{};
    
    for (final ext in extensions) {
      // Проверяем с разными вариантами регистра
      final filePath = '$basePath.$ext';
      final exists = await fileExists(filePath);
      result[ext] = exists;
    }
    
    return result;
  }
  
  // Получение содержимого .hea файла (заголовка записи) - регистронезависимо
  Future<String?> getHeaderContent(String folder, String record) async {
    try {
      // Пробуем разные варианты расширения
      final extensions = ['hea', 'HEA', 'Hea', 'hEA'];
      for (final ext in extensions) {
        try {
          final filePath = 'assets/ECG_DB/$folder/$record.$ext';
          final content = await rootBundle.loadString(filePath);
          return content;
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (e) {
      print('Ошибка загрузки .hea файла для $folder/$record: $e');
      return null;
    }
  }
  
  // Очистка кэша
  void clearCache() {
    _cachedRecordsByFolder = null;
  }
}